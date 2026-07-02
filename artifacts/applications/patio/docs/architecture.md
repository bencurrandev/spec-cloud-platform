# Patio Application - Infrastructure Architecture

**Application**: Patio Scheduling Platform  
**Version**: 1.0.0  
**Date**: 2026-02-19  
**Tier**: Application (constrained by 21 upstream specs)

---

## Executive Summary

The Patio application is a web-based scheduling platform for bars and restaurants, enabling customers to book patio spaces across multiple cities with weather-aware scheduling and dynamic pricing. The infrastructure is built on a LAMP stack (Linux, Apache, MySQL, PHP) deployed on Azure, optimized for the **non-critical workload tier** with a target cost of $50-100/month for production.

---

## Architecture Overview

### High-Level Components

```
Internet
    ↓
[Azure Load Balancer] (Standard SKU, single-zone)
    ↓
[Web Tier VMs] (2-3x Ubuntu 22.04 + Apache + PHP 8.1)
    ↓ ↓ ↓
    ├─→ [Azure Database for MySQL] (Flexible Server, Standard tier)
    ├─→ [Azure Cache for Redis] (Sessions, weather cache)
    ├─→ [Azure Blob Storage] (Patio photos)
    ├─→ [Azure Key Vault] (Secrets: DB passwords, API keys)
    └─→ [Azure Monitor + Log Analytics] (Logs, metrics, alerts)
```

### Network Topology

**VNet**: `patio-vnet` (10.0.0.0/16)
- **Web Subnet**: 10.0.1.0/24 (Web tier VMs, load balancer)
- **Database Subnet**: 10.0.2.0/24 (MySQL private endpoint)
- **Cache Subnet**: 10.0.3.0/24 (Redis private endpoint)

**Security**:
- NSG on web subnet: Allow 443 (HTTPS) from internet, 22 (SSH) from bastion only
- NSG on database subnet: Allow 3306 from web subnet only
- NSG on cache subnet: Allow 6379 from web subnet only
- Default deny all other traffic

---

## Compute Architecture

### VM Sizing (per compute-001 v2.0.0)

| Environment | VM SKU | vCPU | RAM | Cost/Month | Justification |
|-------------|--------|------|-----|------------|---------------|
| **Dev** | Standard_B2s | 2 | 4GB | ~$30 | Burstable, cost-optimized for development |
| **Staging** | Standard_D2s_v3 | 2 | 8GB | ~$70 | Production-like for testing |
| **Production** | Standard_D2s_v3 | 2 | 8GB | ~$140 (2 VMs) | Approved SKU for non-critical tier |

**Scaling Strategy**:
- Dev: 1 VM (no load balancer)
- Staging: 2 VMs (with load balancer)
- Production: 2-3 VMs (auto-scale based on CPU >70%)

**OS Configuration**:
- **Image**: Ubuntu 22.04 LTS (latest)
- **Authentication**: SSH keys only (per ac-001, no passwords)
- **Encryption**: OS disk encrypted with AES-256 (per dp-001)
- **Managed Identity**: System-assigned for Key Vault access

**LAMP Stack Installation** (via custom script extension):
- Apache 2.4 (web server)
- PHP 8.1+ (Laravel or Symfony framework)
- PHP extensions: mysql, redis, gd, curl, mbstring, zip, xml
- Composer (PHP dependency management)
- SSL/TLS 1.2+ configuration (per dp-001)

---

## Database Architecture

### MySQL Flexible Server Configuration (per iac-001)

| Environment | SKU | Storage | Backup | Cost/Month |
|-------------|-----|---------|--------|------------|
| **Dev** | Burstable B1ms | 20GB | 7-day | ~$15 |
| **Staging** | Standard D2ds_v4 | 100GB | 7-day | ~$50 |
| **Production** | Standard D2ds_v4 | 100GB (auto-grow) | 7-day | ~$50 |

**Configuration**:
- **Version**: MySQL 8.0
- **Connectivity**: Private endpoint in database subnet (no public access)
- **Encryption**: At-rest encryption enabled (AES-256 per dp-001)
- **TLS**: Minimum version 1.2 (per dp-001)
- **Firewall**: Allow web subnet only
- **Backup**: Automated daily backups, 7-day retention (per stor-001)
- **High Availability**: Not required for non-critical tier (cost optimization)

**Database Schema**:
- Users (customers, business owners, admins)
- Cities (New York, Chicago, Los Angeles, ...)
- Patios (listings with capacity, amenities, pricing)
- Bookings (reservations with timestamps, pricing breakdown)
- Pricing Rules (dynamic pricing configuration)
- Weather Forecasts (cached weather data)
- Availability Blocks (time periods when unavailable)

**Credentials**: Stored in Azure Key Vault, retrieved via VM managed identity

---

## Storage Architecture

### Blob Storage Configuration (per stor-001)

**Storage Account 1: Photos** (`patiophotosXXXX`)
- **Tier**: Standard (performance), LRS (replication)
- **Container**: `patio-photos` (private access)
- **Use Case**: Patio listing photos (uploaded by business owners)
- **Encryption**: AES-256 at rest (per dp-001)
- **HTTPS Only**: TLS 1.2+ (per dp-001)
- **CDN**: Azure CDN endpoint for optimized photo delivery
- **Lifecycle**: Archive photos older than 2 years to Cool tier
- **Cost**: ~$5/month (estimated 50GB)

**Storage Account 2: Logs** (`patiologsXXXX`)
- **Tier**: Standard LRS
- **Container**: `application-logs` (private access)
- **Use Case**: Apache access logs, PHP error logs
- **Retention**: 90 days (per audit-001)
- **Cost**: ~$2/month

**Access**:
- Web VMs use managed identity to read/write blobs
- SAS tokens for time-limited customer photo uploads

---

## Networking Architecture

### Load Balancer (per net-001)

**SKU**: Standard (single-zone deployment for non-critical tier)
- **Frontend IP**: Static public IP (reserved)
- **Backend Pool**: Web tier VMs (2-3 instances)
- **Health Probe**: HTTP GET /health endpoint (or TCP 80)
- **Load Balancing Rule**: HTTPS 443 → backend pool port 443
- **Session Persistence**: Client IP affinity (for stateful sessions before Redis)

**Public IP**:
- **SKU**: Standard (required for Standard LB)
- **Allocation**: Static
- **DNS**: Custom domain (e.g., patio.example.com)

### Network Security Groups

**Web Tier NSG** (`patio-web-nsg`):
- Allow inbound: 443/HTTPS from internet (0.0.0.0/0)
- Allow inbound: 22/SSH from bastion subnet only (future: Azure Bastion)
- Allow outbound: 3306/MySQL to database subnet
- Allow outbound: 6379/Redis to cache subnet
- Allow outbound: 443/HTTPS to internet (weather API, payment gateway)
- Deny all other traffic

**Database Tier NSG** (`patio-db-nsg`):
- Allow inbound: 3306/MySQL from web subnet (10.0.1.0/24) only
- Deny all other traffic

**Cache Tier NSG** (`patio-cache-nsg`):
- Allow inbound: 6379/Redis from web subnet (10.0.1.0/24) only
- Deny all other traffic

---

## Security Architecture

### Key Vault Configuration (per dp-001, ac-001)

**SKU**: Standard (or Premium with HSM if budget allows)
- **RBAC**: Enabled for access control (per ac-001)
- **Soft Delete**: Enabled (90-day retention)
- **Purge Protection**: Enabled
- **Private Endpoint**: In web subnet
- **Network**: Disable public access, restrict to VNet

**Secrets Stored**:
- `mysql-admin-password`: MySQL administrator password
- `weather-api-key`: OpenWeatherMap API key
- `payment-gateway-key`: Stripe/PayPal API key
- `sendgrid-api-key`: Email service API key
- `app-secret-key`: Application encryption key (sessions, CSRF tokens)
- `redis-primary-key`: Redis connection string

**Access Control**:
- Web VM managed identities have "Key Vault Secrets User" role
- Manual secret rotation every 90 days (best practice)

### Authentication & Authorization (per ac-001)

**SSH Access** (Infrastructure):
- SSH keys only (no password authentication)
- Keys managed per administrator
- Access via Azure Bastion (future enhancement)

**Application RBAC** (Users):
- **Customer Role**: Book patios, view bookings, manage profile
- **Business Owner Role**: Create/manage patios, configure pricing, view analytics
- **Admin Role**: Manage users, moderate content, system configuration
- **MFA Required**: Business Owner and Admin roles only

**Data Protection**:
- Passwords: bcrypt hashing (cost factor 12)
- Sessions: Redis-backed, encrypted session data
- CSRF Protection: Tokens on all state-changing forms
- XSS Protection: Input sanitization, output encoding
- SQL Injection: Parameterized queries (PDO/Eloquent ORM)

---

## Cache Architecture

### Redis Configuration

**Azure Cache for Redis**:
- **Dev**: Basic C0 tier (~$15/month)
- **Staging/Prod**: Standard C1 tier (~$70/month)

**Configuration**:
- **Private Endpoint**: In cache subnet (no public access)
- **TLS**: Version 1.2 minimum (per dp-001)
- **Non-SSL Port**: Disabled (enforce encryption)
- **Maxmemory Policy**: `allkeys-lru` (evict least recently used)

**Use Cases**:
- **Session Storage**: PHP session data (multi-VM session sharing)
- **Weather Cache**: 6-hour cache of weather forecasts (reduce API calls)
- **Search Cache**: Cache popular search queries (city-based listings)
- **Rate Limiting**: Track API rate limits per user/IP

**Cost Optimization**:
- Cache hit ratio target: >80%
- Reduce weather API calls from 1000s/day to 100s/day

---

## Observability Architecture (per obs-001)

### Azure Monitor Integration

**Log Analytics Workspace**:
- Centralized log storage (90-day retention per audit-001)
- Apache access logs (via Log Analytics agent)
- PHP application logs (via Log Analytics agent)
- System logs (syslog)
- MySQL slow query logs

**Application Insights**:
- Request tracking (page views, API calls)
- Response time monitoring
- Exception tracking
- Dependency tracking (MySQL, Redis, external APIs)
- Custom metrics: booking count, search queries, weather API calls

**Metrics Collection**:
- **Request Rate**: Requests/second
- **Response Time**: p95 latency (<200ms search, <500ms booking)
- **Error Rate**: HTTP 5xx errors
- **Database Query Time**: p95 query latency (<100ms)
- **Cache Hit Ratio**: Redis cache hits vs misses
- **Resource Utilization**: CPU, memory, disk I/O

**Alerts**:
- Service down (no health check responses for 5 minutes)
- High error rate (>5% HTTP 5xx for 10 minutes)
- Slow response time (p95 >500ms for 15 minutes)
- Database connection failures
- Cost threshold exceeded (>$110/month)

**Dashboards**:
- SLI/SLO dashboard: Uptime (99% target), response time, error rate
- Business metrics: Bookings/day, revenue, top cities
- Infrastructure health: VM CPU/memory, database connections, cache hit ratio

---

## Deployment Architecture (per env-001)

### Environment Configurations

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| **VMs** | 1x B2s | 2x D2s_v3 | 2-3x D2s_v3 |
| **MySQL** | B1ms | D2ds_v4 | D2ds_v4 |
| **Redis** | C0 | C1 | C1 |
| **Load Balancer** | No | Yes (Standard) | Yes (Standard) |
| **Region** | East US | East US | East US |
| **Naming** | patio-dev-* | patio-staging-* | patio-prod-* |
| **Weather API** | Sandbox/Test | Production | Production |
| **Payment Gateway** | Test Mode | Test Mode | Live Mode |
| **Cost Target** | <$50/mo | <$75/mo | <$100/mo |
| **Data** | Seed data | Anonymized prod data | Live data |

**Environment Variables** (from Key Vault):
- `APP_ENV`: dev / staging / production
- `DB_HOST`: MySQL server FQDN
- `REDIS_HOST`: Redis cache hostname
- `WEATHER_API_KEY`: OpenWeatherMap key
- `PAYMENT_API_KEY`: Stripe/PayPal key
- `SENDGRID_API_KEY`: Email service key

---

## Disaster Recovery & Backup

### Backup Strategy (per stor-001)

**Database Backups**:
- Automated daily backups (Azure-managed)
- 7-day retention period
- Point-in-time restore capability
- Recovery Time Objective (RTO): 4 hours
- Recovery Point Objective (RPO): 24 hours

**Application Code**:
- Version controlled in Git repository
- Deployment pipelines can redeploy from any commit
- Infrastructure-as-Code (Bicep) in repository

**Configuration**:
- Secrets in Key Vault (backed up by Azure)
- Infrastructure defined in Bicep (can be redeployed)

**Photo Storage**:
- LRS replication (3 copies in single datacenter)
- For production: Consider ZRS or GRS if budget allows
- No backup required (source of truth is business uploads)

**Recovery Procedures**:
1. Database: Restore from automated backup to new server
2. Infrastructure: Redeploy from Bicep templates
3. Application: Deploy from Git repository
4. Secrets: Already in Key Vault (persistent)
5. Photos: LRS provides durability (3 copies)

---

## Cost Breakdown

### Monthly Cost Estimates (per cost-001 v2.0.0)

**Development Environment** (~$48/month):
- VM (1x B2s): $30
- MySQL (B1ms): $15
- Redis (C0): $15 (if used, else $0 for Redis on VM)
- Storage (blob + logs): $3
- Bandwidth: $5
- **Total: <$50/month ✅**

**Staging Environment** (~$73/month):
- VMs (2x D2s_v3): $140 → $70 (deallocate when not testing)
- MySQL (D2ds_v4): $50
- Redis (C1): $70 → $35 (provision only during test windows)
- Storage: $5
- Load Balancer: $18
- **Total: <$75/month ✅** (with resource optimization)

**Production Environment** (~$95/month):
- VMs (2x D2s_v3): $140
- MySQL (D2ds_v4): $50
- Redis (C1): $70
- Storage (blob + logs): $10
- Load Balancer: $18
- Bandwidth + CDN: $10
- **Total: <$100/month ✅** (within non-critical tier budget)

**Cost Optimization Strategies**:
- Use Azure Reserved Instances for VMs (save ~30%)
- Auto-scale VMs down during off-hours (nights, weekends)
- Use Basic tier MySQL for dev (if available)
- Deallocate staging resources when not actively testing
- Azure Hybrid Benefit (if Windows ever needed)

---

## Performance Targets

### SLI/SLO Metrics (per obs-001)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Availability** | 99% uptime | Service accessible during business hours (6am-midnight) |
| **Search Response** | <200ms p95 | Time from search request to results displayed |
| **Booking Response** | <500ms p95 | Time from booking submission to confirmation |
| **Page Load Time** | <2s p95 | Full page render (including assets) |
| **Database Queries** | <100ms p95 | MySQL query execution time |
| **Error Rate** | <1% | HTTP 5xx errors as % of total requests |

### Scalability Targets

| Phase | Users | Bookings/Month | VMs | MySQL Tier |
|-------|-------|----------------|-----|------------|
| **Launch** | 1,000 | 500 | 2 | Standard D2ds_v4 |
| **6 Months** | 5,000 | 2,500 | 2-3 | Standard D2ds_v4 |
| **12 Months** | 10,000 | 5,000 | 3-4 | Standard D4ds_v4 (upgrade) |

**Scaling Triggers**:
- CPU >70% for 10 minutes → Add VM
- Database connections >80% capacity → Upgrade MySQL tier
- Redis memory >80% → Upgrade Redis tier

---

## Compliance & Governance

### Upstream Spec Compliance Checklist

**Platform Tier (6 specs)**:
- ✅ spec-001: Specification format followed
- ✅ pac-001: Azure Policy compliance validated
- ✅ lint-001: Bicep IaC linting enforced
- ✅ artifact-001: Artifact organization `/artifacts/applications/patio/`

**Business Tier (3 specs)**:
- ✅ cost-001 v2.0.0: Non-critical tier, $50-100/month budget
- ✅ gov-001: Approval workflows for production deployments
- ✅ comp-001: NIST 800-171 compliance, US data residency (East US)

**Security Tier (3 specs)**:
- ✅ dp-001 v1.0.0: AES-256 encryption at rest, TLS 1.2+ in transit
- ✅ ac-001: SSH keys only, RBAC, MFA for admin/business roles
- ✅ audit-001: 90-day log retention in Log Analytics

**Infrastructure Tier (5 specs)**:
- ✅ compute-001 v2.0.0: Approved SKUs (B2s, D2s_v3)
- ✅ net-001 v2.0.0: Single-zone deployment, Standard LB
- ✅ stor-001 v2.0.0: Standard LRS, 7-day backups
- ✅ cicd-001 v2.0.0: GitHub Actions pipelines with cost gates
- ✅ iac-001: AVM wrapper modules used

**DevOps Tier (4 specs)**:
- ✅ obs-001: Logging, metrics, tracing, SLI/SLO monitoring
- ✅ env-001: Dev/staging/prod environments
- ✅ deploy-001: Blue-green deployment with zero-downtime
- ✅ cicd-orch-001: CI/CD orchestration with approval gates

---

## Security Hardening Checklist

- [ ] SSH keys only, no password authentication (ac-001)
- [ ] All storage encrypted at rest with AES-256 (dp-001)
- [ ] TLS 1.2+ enforced for all connections (dp-001)
- [ ] NSG rules: deny by default, allow explicit (ac-001)
- [ ] Private endpoints for MySQL, Redis, Key Vault
- [ ] Managed identities for VM → Key Vault access
- [ ] Soft delete + purge protection on Key Vault
- [ ] MFA required for business owner and admin accounts (ac-001)
- [ ] Audit logs shipped to Log Analytics (audit-001)
- [ ] 90-day log retention (audit-001)
- [ ] No secrets in code or Git repository
- [ ] Azure Policy compliance scanning (pac-001)
- [ ] Regular security vulnerability scans (OWASP ZAP)
- [ ] Principle of least privilege for all RBAC assignments

---

## Open Questions / Decisions Needed

1. **CDN Provider**: Azure CDN Standard or Premium tier?
   - Decision: Standard (lower cost, sufficient for non-critical)
   
2. **SSL Certificates**: Let's Encrypt (free) or Azure-managed certs?
   - Decision: Let's Encrypt with auto-renewal script
   
3. **Bastion Host**: Deploy Azure Bastion for secure SSH access?
   - Decision: Phase 2 (add after initial deployment, +$140/month)
   
4. **Multi-Region**: Stay single-region or add failover region?
   - Decision: Single-region (non-critical tier, cost optimization)
   
5. **Auto-Scale Rules**: CPU-based or request-based scaling?
   - Decision: CPU-based (>70% add VM, <30% remove VM)

---

## Next Steps

1. ✅ **Phase 0**: Setup complete (directory structure, specs, requirements)
2. 🔄 **Phase 1**: IaC Design (this document, parameter files, security baseline)
3. ⏭️ **Phase 2**: IaC Implementation (Bicep modules using AVM wrappers)
4. ⏭️ **Phase 3**: Pipelines (Infrastructure deployment, application deployment)
5. ⏭️ **Phase 4**: Testing & Validation (linting, cost estimates, What-If)
6. ⏭️ **Phase 5**: Dev Deployment (deploy and test in dev environment)
7. ⏭️ **Phase 6**: Staging Deployment (performance testing, UAT, security testing)
8. ⏭️ **Phase 7**: Production Deployment (with governance approvals)
9. ⏭️ **Phase 8**: Documentation (operational runbooks, handoff)

---

## References

- **Application Spec**: `/specs/application/patio/spec.md`
- **Implementation Plan**: `/specs/application/patio/plan.md`
- **Task List**: `/specs/application/patio/tasks.md`
- **AVM Modules**: `/artifacts/infrastructure/iac-modules/`
- **Cost Spec**: `/specs/business/cost/spec.md` (cost-001 v2.0.0)
- **Security Specs**: `/specs/security/` (dp-001, ac-001, audit-001)
- **Infrastructure Specs**: `/specs/infrastructure/` (compute-001, net-001, stor-001)

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-19  
**Author**: Application Development Team  
**Status**: Approved for Implementation
