# Patio Application - Operational Runbook

**Version**: 1.0.0  
**Last Updated**: February 19, 2026  
**Maintained By**: Platform Operations Team

---

## Table of Contents

1. [Overview](#overview)
2. [Monitoring & Alerting](#monitoring--alerting)
3. [Incident Response](#incident-response)
4. [Backup & Restore](#backup--restore)
5. [Performance Tuning](#performance-tuning)
6. [Scaling Procedures](#scaling-procedures)
7. [Routine Maintenance](#routine-maintenance)
8. [On-Call Procedures](#on-call-procedures)

---

## Overview

This runbook provides standard operating procedures for the Patio application operational team to maintain system health, respond to incidents, and perform routine maintenance.

### Service Level Objectives (SLOs)

| Metric | Target | Measurement Window |
|--------|--------|-------------------|
| Availability | 99% uptime | Monthly |
| Search Response Time | <200ms (p95) | Daily |
| Booking Response Time | <500ms (p95) | Daily |
| Error Rate | <1% of requests | Hourly |

### Operational Hours

- **Production Support**: 24/7 on-call rotation
- **Maintenance Windows**: Tuesday-Thursday, 10pm-2am ET
- **Emergency Changes**: Anytime with approval

---

## Monitoring & Alerting

### Monitoring Stack

- **Azure Monitor**: Infrastructure metrics (CPU, memory, disk, network)
- **Log Analytics**: Centralized logging from all resources
- **Application Insights**: Application performance monitoring
- **Azure Alerts**: Automated alerting for threshold breaches

### Key Dashboards

1. **Application Health Dashboard**
   - URL: `https://portal.azure.com/#@<tenant>/dashboard/patio-health`
   - Metrics: Request rate, response time, error rate, availability
   - Refresh: Real-time (30s interval)

2. **Infrastructure Dashboard**
   - URL: `https://portal.azure.com/#@<tenant>/dashboard/patio-infra`
   - Metrics: VM CPU/memory, MySQL connections, Redis hit ratio
   - Refresh: 1 minute

3. **Cost Dashboard**
   - URL: `https://portal.azure.com/#@<tenant>/resource/subscriptions/<sub-id>/costManagement`
   - Metrics: Daily spend, monthly projection, budget alerts
   - Refresh: Daily

### Alert Rules

| Alert | Threshold | Severity | Action |
|-------|-----------|----------|--------|
| **Service Down** | Health check fails 2/3 checks | Critical | Page on-call immediately |
| **High Error Rate** | >5% errors in 5 min | High | Page on-call within 15 min |
| **Slow Response** | p95 >2000ms for 5 min | Medium | Notify team channel |
| **High CPU** | >80% for 10 min | Medium | Auto-scale + notify |
| **Database Connections** | >90% max connections | High | Investigate connection leaks |
| **Disk Space** | >85% used | Medium | Clean logs or expand disk |
| **Budget Exceeded** | >100% monthly budget | High | Notify finance + platform lead |
| **Failed Logins** | >10 failures in 5 min | Medium | Security review |

### Alert Channels

- **Critical**: PagerDuty → SMS + Phone call
- **High**: Slack #patio-alerts + Email
- **Medium**: Slack #patio-ops
- **Low**: Email digest (daily)

### Daily Health Checks

Run automated health check every morning:

```powershell
# Run comprehensive validation
.\scripts\validate-deployment.ps1 -Environment prod -ResourceGroup rg-patio-prod

# Check service availability
curl -s https://patio.example.com/health | jq .

# Review overnight alerts
az monitor metrics alert list --resource-group rg-patio-prod --query "[?enabled==true]"
```

---

## Incident Response

### Severity Levels

| Severity | Definition | Response Time | Examples |
|----------|-----------|---------------|----------|
| **P1** | Service down, critical functionality broken | 15 minutes | Site down, payment processing failed |
| **P2** | Degraded service, workaround available | 1 hour | Slow search, intermittent errors |
| **P3** | Minor issue, no user impact | 1 business day | Non-critical feature bug |
| **P4** | Enhancement request | 1 week | UI improvement |

### Incident Response Process

#### 1. Detection

- Alert fires in monitoring system OR
- User reports issue via support channel

#### 2. Triage (within 5 minutes)

```powershell
# Quick triage checklist
1. Verify issue in production
2. Assess user impact (how many users affected?)
3. Assign severity level
4. Create incident ticket
5. Notify stakeholders

# Triage commands
# Check service status
curl -I https://patio.example.com/health

# Check error rate
az monitor metrics list \
  --resource (az webapp show -g rg-patio-prod -n patio-prod --query id) \
  --metric failedRequests \
  --start-time (Get-Date).AddHours(-1)

# Check recent deployments
az deployment group list --resource-group rg-patio-prod --query "[0]"
```

#### 3. Investigation

**Common Investigation Steps**:

```powershell
# 1. Check recent changes
git log --oneline --since="24 hours ago"

# 2. Review error logs
az monitor log-analytics query \
  --workspace (az monitor log-analytics workspace show -g rg-patio-prod -n log-patio-prod --query customerId -o tsv) \
  --analytics-query "AppExceptions | where TimeGenerated > ago(1h) | summarize count() by ExceptionType"

# 3. Check VM health
az vm get-instance-view --resource-group rg-patio-prod --name web-vm-patio-prod-001

# 4. Check MySQL health
az mysql flexible-server show --resource-group rg-patio-prod --name mysql-patio-prod

# 5. Check Redis health
az redis show --resource-group rg-patio-prod --name redis-patio-prod
```

#### 4. Mitigation

**Immediate Actions (Pick appropriate)**:

1. **Rollback deployment**: See deployment-runbook.md
2. **Restart services**:
   ```bash
   ssh azureuser@<vm-ip>
   sudo systemctl restart apache2
   sudo systemctl restart php8.1-fpm
   ```
3. **Scale resources**: See scaling procedures below
4. **Enable maintenance mode**:
   ```bash
   ssh azureuser@<vm-ip>
   cd /var/www/patio/current
   php artisan down --message="Under maintenance" --retry=60
   ```

####5. Resolution

1. Apply permanent fix
2. Test fix in staging environment
3. Deploy fix to production
4. Verify resolution
5. Monitor for 30 minutes

#### 6. Post-Mortem (within 48 hours)

**Template**: `docs/incident-reports/YYYY-MM-DD-incident.md`

```markdown
# Incident Post-Mortem: [Brief Title]

**Date**: YYYY-MM-DD
**Duration**: X hours Y minutes
**Severity**: P1/P2/P3
**Impact**: X users affected, Y% error rate

## Timeline
- HH:MM - Incident detected
- HH:MM - Mitigation started
- HH:MM - Resolution confirmed

## Root Cause
[Detailed analysis of what went wrong]

## Resolution
[What fixed the issue]

## Action Items
- [ ] Fix deployed [Owner] [ETA]
- [ ] Monitoring improved [Owner] [ETA]
- [ ] Documentation updated [Owner] [ETA]
```

---

## Backup & Restore

### Backup Strategy

| Resource | Backup Method | Frequency | Retention | Location |
|----------|--------------|-----------|-----------|----------|
| **MySQL Database** | Azure Automated Backups | Daily | 7 days | Azure Backup Vault |
| **Blob Storage (Photos)** | Blob Versioning + Lifecycle | Continuous | 30 days | Same account |
| **Blob Storage (Logs)** | Lifecycle Management | N/A | 90 days | Same account (immutable) |
| **VM Disks** | Azure Backup (optional) | Weekly | 30 days | Recovery Services Vault |
| **Key Vault Secrets** | Soft Delete enabled | N/A | 90 days | Azure Key Vault |
| **IaC Templates** | Git Repository | Every commit | Forever | GitHub |

### Backup Validation

Monthly backup validation (first Tuesday of month):

```powershell
# Test MySQL restore to separate server
az mysql flexible-server restore \
  --resource-group rg-patio-test \  --name mysql-patio-restore-test \
  --source-server mysql-patio-prod \
  --restore-time (Get-Date).AddDays(-1)

# Verify data integrity
mysql -h mysql-patio-restore-test.mysql.database.azure.com -u patioAdmin -p \
  -e "SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM bookings;" patiodb

# Delete test restore
az mysql flexible-server delete --resource-group rg-patio-test --name mysql-patio-restore-test --yes
```

### Restore Procedures

#### Restore MySQL Database

```powershell
# Option 1: Point-in-time restore (within 7 days)
az mysql flexible-server restore \
  --resource-group rg-patio-prod \
  --name mysql-patio-prod-restored \
  --source-server mysql-patio-prod \
  --restore-time "2026-02-18T10:30:00Z"

# Option 2: Restore from backup (manual export)
mysql -h mysql-patio-prod.mysql.database.azure.com -u patioAdmin -p patiodb < backup-2026-02-18.sql
```

#### Restore Blob Storage

```powershell
# Restore deleted blob (within soft-delete retention)
az storage blob undelete \
  --account-name patiophotosstorprod \
  --container-name patio-photos \
  --name "patios/photo123.jpg"

# Restore blob version
az storage blob copy start \
  --account-name patiophotosstorprod \
  --destination-container patio-photos \
  --destination-blob "patios/photo123.jpg" \
  --source-uri "https://patiophotosstorprod.blob.core.windows.net/patio-photos/patios/photo123.jpg?versionId=2026-02-18T10:30:00.0000000Z"
```

#### Restore Key Vault Secrets

```powershell
# List deleted secrets (soft-delete enabled)
az keyvault secret list-deleted --vault-name kv-patio-prod

# Recover deleted secret
az keyvault secret recover --vault-name kv-patio-prod --name mysql-admin-password
```

### Disaster Recovery Plan

**RTO (Recovery Time Objective)**: 4 hours  
**RPO (Recovery Point Objective)**: 24 hours

**DR Scenario: Complete region outage**

1. **Failover to secondary region** (if configured):
   - Not applicable for non-critical tier (single region deployment)
   
2. **Rebuild in same region**:
   ```powershell
   # Restore infrastructure
   az deployment group create \
     --resource-group rg-patio-prod-dr \
     --template-file ./iac/main.bicep \
     --parameters ./iac/parameters/prod.parameters.json
   
   # Restore database (latest backup)
   az mysql flexible-server restore \
     --resource-group rg-patio-prod-dr \
     --name mysql-patio-prod-dr \
     --source-server mysql-patio-prod \
     --restore-time (Get-Date).AddHours(-1)
   
   # Deploy application
   # See deployment-runbook.md
   
   # Update DNS to point to new load balancer
   # (Manual DNS change)
   ```

**Expected Recovery Time**: 2-4 hours

---

## Performance Tuning

### Performance Baselines

| Metric | Baseline | Target | Concerning |
|--------|----------|--------|-----------|
| Homepage Load | 500ms | <1s | >2s |
| Search API (p95) | 150ms | <200ms | >500ms |
| Booking API (p95) | 300ms | <500ms | >1000ms |
| MySQL Query (avg) | 50ms | <100ms | >200ms |
| Redis GET (avg) | 5ms | <10ms | >50ms |

### Performance Monitoring

```powershell
# Check slow query log
mysql -h mysql-patio-prod.mysql.database.azure.com -u patioAdmin -p \
  -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"

# Check Redis performance
redis-cli -h redis-patio-prod.redis.cache.windows.net -a <password> --latency

# Check Apache performance
ssh azureuser@<vm-ip>
sudo apachectl status
sudo tail -f /var/log/apache2/access.log | awk '{print $NF}' | grep -v "-"
```

### Optimization Strategies

#### 1. Database Optimization

```sql
-- Add missing indexes
CREATE INDEX idx_bookings_patio_date ON bookings(patio_id, start_datetime);
CREATE INDEX idx_patios_city_active ON patios(city_id, is_active);

-- Analyze slow queries
EXPLAIN SELECT * FROM patios WHERE city_id = 1 AND is_active = true;

-- Update statistics
ANALYZE TABLE patios;
ANALYZE TABLE bookings;
```

#### 2. Caching Strategy

```php
// Cache patio search results (15 minutes)
Cache::remember("patios:{$cityId}", 900, function() use ($cityId) {
    return Patio::where('city_id', $cityId)
        ->where('is_active', true)
        ->with('photos')
        ->get();
});

// Cache weather forecasts (6 hours)
Cache::remember("weather:{$cityId}:{$date}", 21600, function() use ($cityId, $date) {
    return WeatherService::getForecast($cityId, $date);
});
```

#### 3. Application Optimization

- Enable OPcache for PHP (already in install script)
- Minimize database queries (use eager loading)
- Compress responses (gzip enabled in Apache)
- Optimize images (resize before upload, compress)
- Use CDN for static assets (future enhancement)

---

## Scaling Procedures

### Vertical Scaling (Increase VM Size)

**When**: CPU >80% sustained for >1 hour OR Memory >90%

```powershell
# Stop VM
az vm deallocate --resource-group rg-patio-prod --name web-vm-patio-prod-001

# Resize VM
az vm resize \
  --resource-group rg-patio-prod \
  --name web-vm-patio-prod-001 \
  --size Standard_D4s_v3  # 4 vCPU, 16GB RAM

# Start VM
az vm start --resource-group rg-patio-prod --name web-vm-patio-prod-001

# Validate
.\scripts\validate-deployment.ps1 -Environment prod -ResourceGroup rg-patio-prod
```

**Downtime**: 5-10 minutes per VM (do one at a time for zero downtime)

### Horizontal Scaling (Add VMs)

**When**: Request rate >1000 req/min sustained OR forecasted traffic spike

```powershell
# Create new VM (adjust count in parameters)
# Update parameters/prod.parameters.json: "vmCount": 3

# Deploy updated infrastructure
az deployment group create \
  --resource-group rg-patio-prod \
  --template-file ./iac/main.bicep \
  --parameters ./iac/parameters/prod.parameters.json \
  --parameters mysqlAdminPassword='<password>' sshPublicKey='<ssh-key>'

# Verify new VM added to load balancer backend pool
az network lb address-pool show \
  --resource-group rg-patio-prod \
  --lb-name lb-patio-prod \
  --name backendPool
```

**Downtime**: None (new VM added to pool)

### Database Scaling

**When**: Database CPU >70% sustained OR query latency >500ms

```powershell
# Scale up MySQL tier
az mysql flexible-server update \
  --resource-group rg-patio-prod \
  --name mysql-patio-prod \
  --sku-name Standard_D4ds_v4  # 4 vCPU, 16GB RAM

# Scale storage
az mysql flexible-server update \
  --resource-group rg-patio-prod \
  --name mysql-patio-prod \
  --storage-size 256  # GB
```

**Downtime**: 2-5 minutes for scaling operation

### Redis Scaling

**When**: Redis memory >80% OR evictions detected

```powershell
# Scale up Redis tier
az redis update \
  --resource-group rg-patio-prod \
  --name redis-patio-prod \
  --sku Standard \
  --vm-size C2  # 2.5GB memory
```

**Downtime**: Brief connection interruption during scaling

---

## Routine Maintenance

### Daily Tasks

- [ ] Review overnight alerts (check Slack #patio-alerts)
- [ ] Check service health dashboard
- [ ] Review error logs for anomalies
- [ ] Verify backup completion

### Weekly Tasks (Monday mornings)

- [ ] Review weekly metrics (availability, performance, errors)
- [ ] Check cost dashboard (any unexpected spikes?)
- [ ] Review security audit logs
- [ ] Update team on status

### Monthly Tasks (First Tuesday)

- [ ] Validate backups (test restore)
- [ ] Review and update runbooks
- [ ] Patch OS and dependencies (schedule maintenance window)
- [ ] Cost optimization review
- [ ] Security vulnerability scan

### Quarterly Tasks

- [ ] Disaster recovery drill
- [ ] Performance load testing
- [ ] Capacity planning review
- [ ] Architecture review
- [ ] Renew SSL certificates (if not auto-renewed)

### Patching Strategy

```bash
# SSH to each VM (one at a time for zero downtime)
ssh azureuser@<vm-ip>

# Update packages
sudo apt update
sudo apt upgrade -y

# Reboot if kernel updated
sudo systemctl reboot

# Validate after reboot
curl http://localhost/health
```

**Schedule**: Monthly, during maintenance window (Tue-Thu 10pm-2am ET)

---

## On-Call Procedures

### On-Call Schedule

- **Rotation**: Weekly rotation among ops team
- **Handoff**: Friday 5pm ET
- **Coverage**: 24/7

### On-Call Responsibilities

1. Respond to PagerDuty alerts within SLA (15 min for P1, 1 hour for P2)
2. Triage and resolve incidents
3. Escalate to platform lead if unable to resolve within 1 hour
4. Document incidents in incident tracker
5. Conduct post-mortem for P1/P2 incidents

### On-Call Playbook

**Alert: Service Down**
1. Check health endpoint: `curl https://patio.example.com/health`
2. Check VM status: `az vm get-instance-view ...`
3. If VM down: start VM
4. If application error: review logs, consider rollback
5. Escalate if not resolved in 30 minutes

**Alert: High CPU/Memory**
1. Check VM metrics in Azure Portal
2. Identify resource-intensive processes: `ssh + top`
3. Consider horizontal scaling (add VM)
4. If sustained, schedule vertical scaling

**Alert: Database Connection Errors**
1. Check MySQL server status
2. Check NSG rules allow traffic
3. Check connection pool exhaustion in application logs
4. Restart application if needed

**Alert: Failed Backups**
1. Check Azure Backup status
2. Re-trigger backup manually if transient failure
3. Escalate to platform lead if persistent

### Escalation Contacts

- PlatformLead: platform-lead@example.com (Slack: @platform-lead)
- Security Lead: security@example.com (for security incidents)
- Microsoft Support: Azure Support Portal (P1 incidents only)

---

## Appendix

### Useful One-Liners

```powershell
# Quick health check
curl -s https://patio.example.com/health | jq .

# Recent errors
az monitor log-analytics query --workspace <workspace-id> --analytics-query "AppExceptions | where TimeGenerated > ago(1h) | summarize count() by ExceptionType"

# Current cost (month-to-date)
az consumption usage list --start-date (Get-Date -Day 1 -Format yyyy-MM-dd) --query "[].{service:meterCategory,cost:pretaxCost}" | ConvertFrom-Json | Group-Object service

# VM CPU usage (last hour)
az monitor metrics list --resource <vm-id> --metric "Percentage CPU" --start-time (Get-Date).AddHours(-1)

# Check load balancer backend health
az network lb show --resource-group rg-patio-prod --name lb-patio-prod --query "backendAddressPools[].backendIPConfigurations[].name"
```

### Related Documentation

- [Deployment Runbook](deployment-runbook.md)
- [Infrastructure Documentation](infrastructure.md)
- [Security Documentation](security.md)

---

**Document Version**: 1.0.0  
**Last Reviewed**: February 19, 2026  
**Next Review**: March 19, 2026
