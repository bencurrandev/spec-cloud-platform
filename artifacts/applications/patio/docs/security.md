# Patio Application - Security Documentation

**Version**: 1.0.0  
**Last Updated**: February 19, 2026  
**Classification**: Internal Use Only

---

## Table of Contents

1. [Security Overview](#security-overview)
2. [Security Controls](#security-controls)
3. [Compliance Checklist](#compliance-checklist)
4. [Secret Management](#secret-management)
5. [Security Incident Response](#security-incident-response)
6. [Audit & Compliance](#audit--compliance)

---

## Security Overview

The Patio application implements defense-in-depth security controls across all layers (network, application, data) to protect customer data and maintain compliance with 21 upstream specifications.

### Security Architecture

```
Internet → [WAF/DDoS] → [Load Balancer] → [NSG: Web Tier] → [VMs: Apache + PHP]
                                                                      ↓
                                              [NSG: Database Tier] → [MySQL (TLS 1.2+)]
                                              [NSG: Cache Tier] → [Redis (TLS 1.2+)]
                                              [Private Endpoint] → [Blob Storage (HTTPS)]
                                              [RBAC] → [Key Vault (Secrets)]
```

### Security Principles

1. **Least Privilege**: Users and services have minimum required permissions
2. **Defense in Depth**: Multiple layers of security controls
3. **Encryption Everywhere**: Data encrypted at rest and in transit
4. **Zero Trust**: Verify explicitly, use least privilege, assume breach
5. **Auditability**: All security events logged and retained 90 days

---

## Security Controls

### Network Security (Compliance: net-001, ac-001)

#### Network Segmentation

| Tier | Subnet | CIDR | Inbound Rules | Outbound Rules |
|------|--------|------|---------------|----------------|
| **Web** | 10.0.1.0/24 | 256 IPs | Internet: 443<br>Bastion: 22 | Database: 3306<br>Cache: 6379<br>Internet: 443 |
| **Database** | 10.0.2.0/24 | 256 IPs | Web subnet: 3306 only | None (private) |
| **Cache** | 10.0.3.0/24 | 256 IPs | Web subnet: 6379 only | None (private) |

#### NSG Rules (Implemented)

**Web Tier NSG**:
```bicep
- Allow HTTPS (443) from Internet → Priority 100
- Allow SSH (22) from Bastion/Jump Box only → Priority 110
- Allow HTTP (80) from Internet (redirects to HTTPS) → Priority 120
- Deny All Other Inbound → Priority 4096 (default)
```

**Database Tier NSG**:
```bicep
- Allow MySQL (3306) from Web Subnet only → Priority 100
- Deny All Other Inbound → Priority 4096
```

**Cache Tier NSG**:
```bicep
- Allow Redis (6379) from Web Subnet only → Priority 100
- Deny All Other Inbound → Priority 4096
```

#### DDoS Protection

- **Azure DDoS Protection Basic**: Enabled by default (free tier)
- **Rate Limiting**: Apache mod_evasive configured (100 requests/10 seconds per IP)
- **WAF**: Not implemented (cost constraint), consider for future

---

### Access Control (Compliance: ac-001 v1.0.0)

#### Authentication & Authorization

**SSH Access** (VMs):
- ✅ SSH key-based authentication ONLY
- ❌ Password authentication DISABLED (enforced in Bicep templates)
- ✅ Private key stored in GitHub Secrets (encrypted)
- ✅ Public key deployed via Bicep

**Application Authentication**:
- ✅ bcrypt password hashing (cost factor: 12)
- ✅ Session management via Redis (secure, httpOnly cookies)
- ✅ CSRF protection enabled on all forms
- ✅ MFA required for Business Owner and Admin roles (TOTP)

**Azure RBAC Roles**:

| Role | Permissions | Assignment |
|------|------------|------------|
| **Reader** | View resources only | Auditors, read-only access |
| **Contributor** | Manage resources (no RBAC changes) | DevOps team |
| **Owner** | Full control | Platform lead only |
| **Key Vault Secrets User** | Read secrets | Web VM managed identity |
| **Storage Blob Data Contributor** | Read/write blobs | Web VM managed identity |

**Application Roles (Database)**:

```sql
-- Customer: Default role for end users
permissions: search_patios, create_booking, view_own_bookings

-- Business Owner: Patio listing owners
permissions: manage_own_patios, view_bookings_for_own_patios, set_pricing
MFA: REQUIRED

-- Admin: Platform administrators
permissions: manage_all_users, manage_all_patios, view_all_bookings, moderate_content
MFA: REQUIRED
```

#### Managed Identity

Web VMs use **System-Assigned Managed Identity** to access Azure resources without storing credentials:

- Key Vault: Retrieve secrets (DB password, API keys)
- Blob Storage: Upload/download patio photos
- Log Analytics: Ship logs and metrics

---

### Data Protection (Compliance: dp-001 v1.0.0)

#### Encryption at Rest (AES-256)

| Resource | Encryption Method | Key Management |
|----------|------------------|----------------|
| **VM OS Disks** | Azure SSE | Microsoft-managed keys |
| **MySQL Database** | Transparent Data Encryption | Microsoft-managed keys |
| **Blob Storage** | Azure SSE | Microsoft-managed keys |
| **Redis Cache** | Azure SSE | Microsoft-managed keys |
| **Backup Vaults** | Azure SSE | Microsoft-managed keys |

**Note**: Customer-managed keys (CMK) via Key Vault not implemented (cost constraint). Consider for regulated workloads.

#### Encryption in Transit (TLS 1.2+)

| Connection | Encryption | Enforcement |
|-----------|-----------|-------------|
| **Internet → Load Balancer** | TLS 1.3 | HTTPS enforced, HTTP redirects |
| **Load Balancer → VMs** | TLS 1.2 | Apache configured |
| **VMs → MySQL** | TLS 1.2 | `sslEnforcement: Enabled` |
| **VMs → Redis** | TLS 1.2 |`minimumTlsVersion: 1.2` |
| **VMs → Blob Storage** | HTTPS | `supportsHttpsTrafficOnly: true` |
| **VMs → Key Vault** | HTTPS | Azure enforced |

**Apache TLS Configuration** (in install-lamp-stack.sh):
```apache
SSLEngine on
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCipherSuite HIGH:!aNULL:!MD5
SSLHonorCipherOrder on
```

#### Data Classification

| Data Type | Classification | Storage | Retention |
|-----------|---------------|---------|-----------|
| **Passwords** | Secret | MySQL (bcrypt hash only) | Indefinite |
| **Personal Info** (name, email, phone) | PII | MySQL | Until account deleted |
| **Payment Data** | PCI DSS | NOT STORED (processed by gateway) | N/A |
| **Patio Photos** | Public | Blob Storage | 1 year (lifecycle policy) |
| **Booking Data** | Business Data | MySQL | 7 years (legal requirement) |
| **Audit Logs** | Compliance | Blob Storage (immutable) | 90 days |

---

### Application Security

#### Input Validation & Sanitization

**SQL Injection Prevention**:
```php
// ✅ Good: Parameterized queries (Laravel Eloquent ORM)
$patios = Patio::where('city_id', $cityId)->get();

// ❌ Bad: String concatenation (NEVER do this)
// $patios = DB::select("SELECT * FROM patios WHERE city_id = $cityId");
```

**XSS Prevention**:
```php
// ✅ Good: Blade templating auto-escapes output
{{ $patio->description }}  // Auto-escaped

// Only use when HTML intentionally allowed (rare)
{!! $trustedContent !!}  // Not escaped
```

**CSRF Prevention**:
```html
<!-- All forms include CSRF token -->
<form method="POST" action="/booking">
    @csrf
    <!-- form fields -->
</form>
```

**File Upload Security**:
```php
// Validate file upload (patio photos)
$request->validate([
    'photo' => 'required|image|mimes:jpg,png|max:2048',  // Max 2MB
]);

// Generate random filename (prevent path traversal)
$filename = Str::uuid() . '.' . $request->file('photo')->extension();

// Upload to blob storage (not web-accessible directory)
Storage::disk('azure')->put("patios/$filename", file_get_contents($request->file('photo')));
```

#### Security Headers

```apache
# Added to Apache configuration (install-lamp-stack.sh)
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "DENY"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
```

---

## Compliance Checklist

### Upstream Specification Compliance

| Spec ID | Specification | Status | Evidence |
|---------|--------------|--------|----------|
| **ac-001** | Access Control v1.0.0 | ✅ Compliant | SSH keys only, RBAC, MFA for admins |
| **dp-001** | Data Protection v1.0.0 | ✅ Compliant | AES-256 at rest, TLS 1.2+ in transit |
| **audit-001** | Audit Logging v1.0.0 | ✅ Compliant | 90-day retention, immutable storage |
| **sec-001** | Security Baseline v1.0.0 | ✅ Compliant | No hardcoded secrets, Key Vault used |
| **comp-001** | Compliance Framework v2.0.0 | ✅ Compliant | US East region, data residency |
| **cost-001** | Cost Management v2.0.0 | ✅ Compliant | <$100/month for prod |
| **iac-001** | IaC Standards v1.0.0 | ✅ Compliant | AVM wrappers used |
| **net-001** | Networking v1.0.0 | ✅ Compliant | Single-zone, NSGs configured |
| **stor-001** | Storage v1.0.0 | ✅ Compliant | 7-day backups, Standard LRS |
| **compute-001** | Compute v2.0.0 | ✅ Compliant | B2s/D2s_v3 SKUs approved |
| **pac-001** | Policy as Code v1.0.0 | ✅ Compliant | Azure Policy enabled |
| **cicd-001** | CI/CD Standards v1.0.0 | ✅ Compliant | GitHub Actions pipelines |
| **deploy-001** | Deployment Automation v1.0.0 | ✅ Compliant | Automated deployments |
| **env-001** | Environment Management v1.0.0 | ✅ Compliant | Dev/Staging/Prod separation |
| **obs-001** | Observability v1.0.0 | ✅ Compliant | Logs, metrics, alerts configured |
| **gov-001** | Governance v1.0.0 | ✅ Compliant | Prod deployment approvals |
| **artifact-001** | Artifact Organization v1.0.0 | ✅ Compliant | Directory structure followed |
| **spec-001** | Specification System v1.0.0 | ✅ Compliant | Spec.md + plan.md created |
| **cicd-orch-001** | CI/CD Orchestration v1.0.0 | ✅ Compliant | Multi-environment pipelines |
| **lint-001** | IaC Linting v1.0.0 | ✅ Compliant | Bicep linting in pipeline |
| **mysql-001** | MySQL Best Practices v1.0.0 | ✅ Compliant | Flexible Server, TLS enforced |

**Compliance Score**: 21/21 (100%)

---

## Secret Management

### Azure Key Vault Configuration (Compliance: sec-001)

**Key Vault**: `kv-patio-<env>`

| Secret Name | Purpose | Rotation Policy | Access |
|-------------|---------|-----------------|--------|
| `mysql-admin-password` | MySQL admin password | 90 days | VM managed identity |
| `app-key` | Laravel APP_KEY encryption | 180 days | VM managed identity |
| `redis-connection-string` | Redis password | Auto (Azure-managed) | VM managed identity |
| `weather-api-key` | OpenWeatherMap API | Annual | VM managed identity |
| `payment-gateway-api-key` | Stripe/PayPal API | Annual | VM managed identity |
| `smtp-password` | Email SMTP password | 90 days | VM managed identity |
| `jwt-signing-key` | API authentication | 90 days | VM managed identity |

**Key Vault Features Enabled**:
- ✅ Soft Delete (90-day retention)
- ✅ Purge Protection (production only)
- ✅ RBAC Authorization (preferred over access policies)
- ✅ Audit Logging (all secret access logged)
- ✅ Private Endpoint (production only)

### Secret Rotation Procedures

**Automated Rotation** (not yet implemented):
- Integrate with Azure Key Vault Secret Rotation (future enhancement)

**Manual Rotation** (current):

```powershell
# Generate new secure password
$newPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})

# Update MySQL password
az mysql flexible-server update \
  --resource-group rg-patio-prod \
  --name mysql-patio-prod \
  --admin-password $newPassword

# Update Key Vault secret
az keyvault secret set \
  --vault-name kv-patio-prod \
  --name mysql-admin-password \
  --value $newPassword

# Restart application to pick up new secret
ssh azureuser@<vm-ip> 'sudo systemctl reload php8.1-fpm'
```

**Rotation Schedule**:
- Every 90 days for all secrets
- Immediate rotation if compromised

---

## Security Incident Response

### Incident Types

| Type | Severity | Examples |
|------|----------|----------|
| **Data Breach** | P1 | Unauthorized access to customer data |
| **Malware/Ransomware** | P1 | VM infected with malware |
| **DDoS Attack** | P1 | Service unavailable due to traffic flood |
| **Unauthorized Access** | P2 | Failed login attempts >100 in 5 min |
| **Vulnerability** | P3 | CVE found in dependency |

### Response Workflow

**1. Detection** (Automated + Manual)
- Azure Security Center alerts
- Failed login monitoring (>10 failures in 5 min)
- Unusual data access patterns
- Vulnerability scanners (Dependabot, OWASP)

**2. Containment** (Within 30 minutes)
```powershell
# Isolate compromised VM (update NSG to block all traffic)
az network nsg rule create \
  --resource-group rg-patio-prod \
  --nsg-name nsg-patio-prod-web \
  --name EMERGENCY-BLOCK-ALL \
  --priority 50 \
  --access Deny \
  --direction Inbound \
  --source-address-prefixes '*' \
  --destination-port-ranges '*'

# Rotate all secrets immediately
# (See secret rotation procedures above)

# Enable maintenance mode
ssh azureuser@<vm-ip>
cd /var/www/patio/current
php artisan down --message="Security maintenance"
```

**3. Investigation**
```powershell
# Review audit logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AuditLogs | where TimeGenerated > ago(24h) | where ResultType != 'Success'"

# Review authentication logs
mysql -h mysql-patio-prod -u patioAdmin -p \
  -e "SELECT * FROM audit_logs WHERE event_type = 'login' AND created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR) ORDER BY created_at DESC;"

# Check for compromised secrets
az keyvault secret list --vault-name kv-patio-prod --query "[].{name:name,updated:attributes.updated}"
```

**4. Eradication**
- Patch vulnerabilities
- Remove malware/backdoors
- Rebuild compromised VMs from clean images

**5. Recovery**
- Restore from backups if needed
- Verify system integrity
- Re-enable services

**6. Post-Incident Review** (Within 72 hours)
- Root cause analysis
- Document lessons learned
- Update runbooks/procedures
- Implement preventive controls

### Security Contacts

| Role | Email | Phone | Escalation |
|------|-------|-------|-----------|
| **Security Lead** | security@example.com | - | Primary |
| **Platform Lead** | platform-lead@example.com | - | Secondary |
| **Microsoft Security** | Azure Security Center | - | Critical incidents |
| **Legal** | legal@example.com | - | Data breach incidents |

**Mandatory Notifications**:
- Data Breach: Legal + customers (GDPR: within 72 hours)
- Malware: IT Security team immediately
- Vulnerability: Security team within 24 hours

---

## Audit & Compliance

### Audit Log Requirements (Compliance: audit-001)

**Logged Events**:
- ✅ User authentication (login, logout, failed logins)
- ✅ User account changes (create, update, delete)
- ✅ Booking transactions (create, update, cancel)
- ✅ Patio listing changes (create, update, delete)
- ✅ Payment transactions (via payment gateway logs)
- ✅ Administrative actions (user role changes, content moderation)
- ✅ Key Vault secret access (all get/set/delete operations)
- ✅ Azure resource modifications (via Azure Activity Log)

**Audit Log Storage**:
- **Location**: Azure Blob Storage (storage account: `patiologstor<env>`)
- **Container**: `audit-logs`
- **Retention**: 90 days (per audit-001 v1.0.0)
- **Immutability**: Enabled for production (cannot be deleted/modified)
- **Encryption**: AES-256 at rest, HTTPS in transit

**Audit Log Format** (JSON):
```json
{
  "timestamp": "2026-02-19T10:30:00Z",
  "user_id": 12345,
  "event_type": "booking.created",
  "event_data": {
    "booking_id": 67890,
    "patio_id": 123,
    "amount": 50.00
  },
  "ip_address": "203.0.113.45",
  "user_agent": "Mozilla/5.0..."
}
```

### Audit Log Review

**Monthly Review** (First Friday of month):
```powershell
# Download last month's audit logs
az storage blob download-batch \
  --account-name patiologsstorprod \
  --source audit-logs \
  --destination ./audit-review/ \
  --pattern "*/202602*"  # February 2026

# Analyze for anomalies
# Look for: excessive failed logins, unusual admin actions, large data exports
```

**Automated Alerts**:
- 10+ failed login attempts → Security team notification
- Admin role granted → Security lead notification
- Bulk data export (>1000 records) → Security review
- Key Vault secret deletion → Security lead notification

### Compliance Audit Support

**Evidence Collection** (for annual audits):

1. **Infrastructure Documentation**: `docs/architecture.md`, `docs/infrastructure.md`
2. **Security Controls**: This document (`docs/security.md`)
3. **Audit Logs**: Export from Blob Storage (90-day retention)
4. **Backup Verification**: Monthly restore test reports
5. **Vulnerability Scans**: OWASP ZAP reports, Dependabot alerts
6. **Compliance Checklist**: 21/21 specs compliant (see above)
7. **Incident Reports**: `docs/incident-reports/*.md`

---

## Security Hardening Checklist

### Infrastructure Hardening

- [x] SSH key authentication only (passwords disabled)
- [x] NSGs configured with least privilege
- [x] Private endpoints for MySQL and Redis
- [x] Disk encryption enabled (AES-256)
- [x] TLS 1.2+ enforced on all connections
- [x] Unnecessary ports/services disabled
- [x] OS regularly patched (monthly maintenance)
- [ ] Web Application Firewall (WAF) - Future enhancement
- [ ] Azure DDoS Protection Standard - Future enhancement

### Application Hardening

- [x] Password hashing with bcrypt (cost 12)
- [x] Session management via Redis (secure cookies)
- [x] CSRF protection enabled
- [x] XSS protection (auto-escaping templates)
- [x] SQL injection prevention (parameterized queries)
- [x] File upload validation and sanitization
- [x] Security headers configured (HSTS, CSP, X-Frame-Options)
- [x] Rate limiting enabled (mod_evasive)
- [ ] Content Security Policy (CSP) - Strict mode
- [ ] API rate limiting per user - Future enhancement

### Monitoring & Detection

- [x] Azure Security Center enabled
- [x] Audit logging configured (90-day retention)
- [x] Failed login monitoring
- [x] Alert on unauthorized access attempts
- [x] Key Vault access logging
- [x] Resource modification logging
- [ ] SIEM integration - Future enhancement
- [ ] Anomaly detection (Azure Sentinel) - Future enhancement

---

## Related Documentation

- [Infrastructure Architecture](architecture.md)
- [Deployment Runbook](deployment-runbook.md)
- [Operational Runbook](operational-runbook.md)
- [Developer Guide](developer-guide.md)

---

**Document Version**: 1.0.0  
**Classification**: Internal Use Only  
**Last Reviewed**: February 19, 2026  
**Next Review**: March 19, 2026  
**Security Owner**: Security Lead
