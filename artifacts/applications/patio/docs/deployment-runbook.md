# Patio Application - Deployment Runbook

**Version**: 1.0.0  
**Last Updated**: February 19, 2026  
**Maintained By**: Platform Engineering Team

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Environment Deployment Procedures](#environment-deployment-procedures)
4. [Rollback Procedures](#rollback-procedures)
5. [Post-Deployment Validation](#post-deployment-validation)
6. [Common Issues and Resolutions](#common-issues-and-resolutions)
7. [Emergency Contacts](#emergency-contacts)

---

## Overview

This runbook provides step-by-step procedures for deploying the Patio application infrastructure and code across all environments (dev, staging, production).

### Deployment Architecture

- **Infrastructure**: Azure IaC using Bicep templates
- **Application**: PHP 8.1 LAMP stack (Laravel/Symfony)
- **CI/CD**: GitHub Actions pipelines
- **Environments**: Dev → Staging → Production promotion path

### Deployment Windows

| Environment | Window | Approval Required | Estimated Duration |
|------------|--------|-------------------|-------------------|
| Development | Anytime | No | 15-20 minutes |
| Staging | Business hours preferred | No | 20-25 minutes |
| Production | Tue-Thu 10pm-2am ET | Yes (2 approvers) | 30-40 minutes |

---

## Pre-Deployment Checklist

### All Environments

- [ ] Azure CLI authenticated (`az login` and `az account show`)
- [ ] Correct subscription selected
- [ ] GitHub Actions secrets configured:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - `MYSQL_ADMIN_PASSWORD_<ENV>`
  - `SSH_PUBLIC_KEY`
  - `SSH_PRIVATE_KEY` (for deployments)
- [ ] Bicep templates validated (`.\scripts\validate-bicep.ps1`)
- [ ] Security compliance verified (`.\scripts\validate-security.ps1`)
- [ ] Cost estimates within budget (`docs\cost-estimate.md`)

### Development Environment

- [ ] Resource group `rg-patio-dev` created or ready to create
- [ ] Key Vault secrets prepared (weather API key, payment gateway test key)
- [ ] SSH key pair generated for VM access

### Staging Environment

- [ ] Development deployment successful and validated
- [ ] Test data prepared (anonymized production-like data)
- [ ] Performance testing plan reviewed

### Production Environment

- [ ] Staging deployment successful and validated
- [ ] All security findings from pen-testing remediated
- [ ] Performance testing meets SLI/SLO targets (99% uptime, <200ms search)
- [ ] Change Management ticket approved
- [ ] Stakeholders notified (email sent 24h advance)
- [ ] Backup plan verified
- [ ] Rollback plan reviewed and understood
- [ ] On-call engineer identified and briefed
- [ ] DNS/Domain SSL certificate ready (if custom domain)

---

## Environment Deployment Procedures

### Step 1: Run What-If Analysis

**Purpose**: Preview infrastructure changes before deployment

```powershell
# Run What-If analysis
.\scripts\run-whatif-analysis.ps1 -Environment <dev|staging|prod>

# Review output carefully:
# - Check for unexpected resource deletions (RED flags)
# - Verify create/modify counts are reasonable
# - Confirm no high-impact changes (database deletes, VM restarts)
```

**Decision Point**: If What-If shows unexpected changes, STOP and investigate before proceeding.

---

### Step 2: Deploy Infrastructure

#### Option A: Via GitHub Actions (Recommended)

1. Navigate to GitHub repository → Actions tab
2. Select workflow: `Deploy Infrastructure`
3. Click "Run workflow"
4. Select environment: `dev` | `staging` | `prod`
5. Click "Run workflow" button
6. Monitor progress in real-time
7. Wait for completion (green checkmark)

#### Option B: Via Azure CLI (Manual)

```powershell
# Set environment
$env = "dev"  # or "staging", "prod"
$rg = "rg-patio-$env"
$location = "eastus"

# Create resource group
az group create --name $rg --location $location --tags Environment=$env Application=patio

# Run deployment
az deployment group create `
  --resource-group $rg `
  --template-file ./iac/main.bicep `
  --parameters ./iac/parameters/$env.parameters.json `
  --parameters mysqlAdminPassword='<SECURE-PASSWORD>' `
               sshPublicKey='<SSH-PUBLIC-KEY>' `
               tenantId='<TENANT-ID>'

# Verify deployment
.\scripts\validate-deployment.ps1 -Environment $env -ResourceGroup $rg
```

**Expected Duration**: 15-25 minutes depending on environment

**Success Criteria**:
- Deployment status: "Succeeded"
- All validation checks pass (✅)
- No critical errors in logs

---

### Step 3: Initialize Database

```powershell
# Get MySQL server FQDN
$mysqlServer = az mysql flexible-server show `
  --resource-group $rg `
  --name "mysql-patio-$env" `
  --query fullyQualifiedDomainName -o tsv

# Connect and initialize schema
mysql -h $mysqlServer -u patioAdmin -p patiodb < ./scripts/init-database.sql

# Verify tables created
mysql -h $mysqlServer -u patioAdmin -p -e "SHOW TABLES;" patiodb

# Expected output: 8 tables (users, cities, patios, bookings, etc.)
```

**Seed Data** (Dev/Staging only):

```powershell
# Seed cities (already in init-database.sql)
# Seed test users (dev/staging only)
mysql -h $mysqlServer -u patioAdmin -p patiodb < ./scripts/seed-test-data.sql
```

---

### Step 4: Deploy Application Code

#### Option A: Via GitHub Actions (Recommended)

1. Navigate to GitHub repository → Actions tab
2. Select workflow: `Deploy Application`
3. Click "Run workflow"
4. Select environment: `dev` | `staging` | `prod`
5. Click "Run workflow" button
6. Monitor deployment progress

#### Option B: Via SSH (Manual)

```powershell
# Get VM IP address
$vmIp = az vm list-ip-addresses `
  --resource-group $rg `
  --name "web-vm-patio-$env-001" `
  --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv

# Create deployment package
tar -czf patio-app.tar.gz vendor/ public/ src/ config/ database/ routes/

# Upload to VM
scp -i ~/.ssh/patio_deploy_key patio-app.tar.gz azureuser@${vmIp}:/tmp/

# SSH to VM and deploy
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp}

# On VM:
sudo mkdir -p /var/www/patio/releases/$(date +%Y%m%d%H%M%S)
cd /var/www/patio/releases/$(date +%Y%m%d%H%M%S)
sudo tar -xzf /tmp/patio-app.tar.gz

# Set permissions
sudo chown -R www-data:www-data /var/www/patio
sudo chmod -R 755 /var/www/patio

# Create symlink (atomic swap)
sudo ln -nfs $(pwd) /var/www/patio/current

# Run migrations
cd /var/www/patio/current
php artisan migrate --force

# Clear and cache config
php artisan config:clear
php artisan cache:clear
php artisan config:cache
php artisan route:cache

# Reload PHP-FPM
sudo systemctl reload php8.1-fpm

# Test application
curl http://localhost/health
# Expected: {"status":"ok","timestamp":"..."}
```

**Expected Duration**: 5-10 minutes

---

### Step 5: Configure Environment Variables

```powershell
# Retrieve secrets from Key Vault
$kvName = "kv-patio-$env"

# Set environment file on VM via Key Vault
az keyvault secret show --vault-name $kvName --name app-env-file --query value -o tsv | `
  ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp} 'cat > /var/www/patio/current/.env'

# Verify critical variables set
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp} 'cat /var/www/patio/current/.env | grep -E "APP_ENV|DB_HOST|REDIS_HOST"'
```

**Required Variables**:
- `APP_ENV` (dev/staging/prod)
- `APP_KEY` (from Key Vault)
- `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- `REDIS_HOST`, `REDIS_PASSWORD`
- `STORAGE_ACCOUNT_NAME`, `STORAGE_ACCOUNT_KEY`
- `WEATHER_API_KEY`
- `MAIL_HOST`, `MAIL_USERNAME`, `MAIL_PASSWORD`

---

### Step 6: Post-Deployment Validation

Run automated validation:

```powershell
.\scripts\validate-deployment.ps1 -Environment $env -ResourceGroup $rg -ValidateApplication
```

**Manual Smoke Tests**:

1. **Homepage Load**: `curl https://<load-balancer-ip>/`
   - Expected: HTTP 200, HTML content returned
   
2. **Health Check**: `curl https://<load-balancer-ip>/health`
   - Expected: `{"status":"ok"}`
   
3. **API Status**: `curl https://<load-balancer-ip>/api/status`
   - Expected: `{"app":"patio","environment":"<env>","database":"connected","cache":"connected"}`

4. **User Registration** (browser):
   - Navigate to `/register`
   - Create test account
   - Verify email sent (check logs)
   - Verify user in database: `SELECT * FROM users ORDER BY created_at DESC LIMIT 1;`

5. **Patio Search** (browser):
   - Navigate to `/search`
   - Search for "New York"
   - Verify results display with photos from blob storage

**Expected Duration**: 10 minutes

---

### Step 7: Enable Monitoring

```powershell
# Run observability setup (first deployment only)
# Via GitHub Actions: "Setup Observability" workflow
# Or manually:
az monitor log-analytics workspace create `
  --resource-group $rg `
  --workspace-name "log-patio-$env" `
  --location $location

# Create Application Insights
az monitor app-insights component create `
  --app "appi-patio-$env" `
  --location $location `
  --resource-group $rg `
  --workspace "/subscriptions/.../log-patio-$env"

# Configure alerts (see setup-observability.yml pipeline)
```

---

### Step 8: Production-Only Steps

#### DNS Configuration

```powershell
# Update DNS A record to point to load balancer public IP
$publicIp = az network public-ip show `
  --resource-group $rg `
  --name "pip-patio-prod" `
  --query ipAddress -o tsv

# Configure DNS (via DNS provider):
# A record: patio.example.com → $publicIp
```

#### SSL Certificate

```bash
# SSH to VM
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp}

# Install Certbot
sudo apt install -y certbot python3-certbot-apache

# Obtain Let's Encrypt certificate
sudo certbot --apache -d patio.example.com -d www.patio.example.com

# Verify auto-renewal
sudo certbot renew --dry-run
```

#### Final Production Checks

- [ ] SSL certificate valid and auto-renewal configured
- [ ] HTTPS redirect working (HTTP → HTTPS)
- [ ] Custom domain resolving correctly
- [ ] Payment gateway in LIVE mode (not test mode)
- [ ] Email SMTP configured for production (not dev/staging SMTP)
- [ ] Google Analytics / tracking code installed (if applicable)
- [ ] Privacy policy and terms of service pages published
- [ ] GDPR cookie consent banner active

---

## Rollback Procedures

### When to Rollback

Initiate rollback if:
- ❌ Health check fails after deployment
- ❌ Error rate >5% within 15 minutes of deployment
- ❌ Critical functionality broken (search, booking, login)
- ❌ Database migration fails

### Rollback: Infrastructure

```powershell
# Option 1: Redeploy previous Bicep templates
git checkout <previous-commit-hash>

az deployment group create `
  --resource-group $rg `
  --template-file ./iac/main.bicep `
  --parameters ./iac/parameters/$env.parameters.json

# Option 2: Restore from backup (if database corrupted)
# See "Disaster Recovery" section in infrastructure.md
```

**Expected Duration**: 15-20 minutes

### Rollback: Application

```bash
# SSH to VM
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp}

# List releases
ls -lt /var/www/patio/releases/

# Identify previous release (second most recent)
PREVIOUS_RELEASE=$(ls -t /var/www/patio/releases/ | sed -n 2p)

# Atomic symlink swap to previous release
sudo ln -nfs /var/www/patio/releases/$PREVIOUS_RELEASE /var/www/patio/current

# Reload PHP-FPM
sudo systemctl reload php8.1-fpm

# Verify health
curl http://localhost/health
```

**Expected Duration**: 2 minutes (instant rollback)

### Rollback: Database Migrations

```bash
# SSH to VM
cd /var/www/patio/current

# Rollback last migration
php artisan migrate:rollback --step=1

# Or rollback to specific version
php artisan migrate:rollback --to=2026_02_01_000000
```

**⚠️ WARNING**: Database rollbacks may cause data loss. Only rollback if migration corrupted schema.

---

## Post-Deployment Validation

### Automated Validation

Run comprehensive validation script:

```powershell
.\scripts\validate-deployment.ps1 `
  -Environment $env `
  -ResourceGroup $rg `
  -ValidateApplication
```

**Expected Results**:
- ✅ Passed: 25+
- ❌ Failed: 0
- ⚠️ Warnings: 0-2 (acceptable)

### Manual Validation Checklist

#### Infrastructure Validation

- [ ] All resources created (VMs, MySQL, Redis, Storage, Key Vault, VNet, NSG, LB)
- [ ] VMs running and accessible via SSH
- [ ] MySQL database accessible from web VMs
- [ ] Redis cache accessible from web VMs
- [ ] Blob storage read/write working
- [ ] Key Vault secrets retrievable by VM managed identity
- [ ] Load balancer health probe passing
- [ ] Public IP resolving correctly

#### Application Validation

- [ ] Homepage loads (HTTP 200)
- [ ] User registration working
- [ ] User login working (sessions persist via Redis)
- [ ] Patio search returns results
- [ ] Weather forecast displays for booking dates
- [ ] Photo upload to blob storage working
- [ ] Dynamic pricing calculation correct
- [ ] Email notifications sending

#### Security Validation

- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] SSH requires key (password auth disabled)
- [ ] Passwords hashed with bcrypt (verify in database)
- [ ] SQL injection prevented (test with `' OR '1'='1`)
- [ ] XSS prevented (test with `<script>alert('xss')</script>`)
- [ ] CSRF tokens on all forms

#### Observability Validation

- [ ] Apache access logs flowing to Log Analytics
- [ ] PHP error logs flowing to Log Analytics
- [ ] Application Insights tracking page views
- [ ] Custom metrics collected (booking count, search queries)
- [ ] Alerts configured and testable
- [ ] Dashboard shows key metrics

---

## Common Issues and Resolutions

### Issue 1: Bicep Deployment Fails with "Resource Already Exists"

**Symptoms**: Error during `az deployment group create`

**Resolution**:
```powershell
# Delete resource group and redeploy
az group delete --name $rg --yes --no-wait

# Wait for deletion to complete
az group wait --name $rg --deleted --timeout 600

# Redeploy
az deployment group create ...
```

### Issue 2: MySQL Connection Refused

**Symptoms**: Application cannot connect to MySQL database

**Diagnosis**:
```powershell
# Check MySQL server status
az mysql flexible-server show --resource-group $rg --name "mysql-patio-$env"

# Check NSG rules allow traffic from web subnet
az network nsg rule show --resource-group $rg --nsg-name "nsg-patio-$env-database" --name "AllowWebToMySQL"

# Test connectivity from VM
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp} 'nc -zv <mysql-fqdn> 3306'
```

**Resolution**:
- Verify NSG rule allows web subnet to database subnet on port 3306
- Verify MySQL server not paused (dev environments auto-pause after inactivity)
- Check connection string in `.env` file

### Issue 3: Health Check Returns HTTP 500

**Symptoms**: `/health` endpoint returns 500 error

**Diagnosis**:
```bash
# SSH to VM and check PHP error logs
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp}
sudo tail -f /var/log/apache2/error.log

# Check application logs
tail -f /var/www/patio/current/storage/logs/laravel.log
```

**Common Causes**:
1. Missing environment variables (.env file not configured)
2. Database connection failed (check DB_* variables)
3. Redis connection failed (check REDIS_* variables)
4. File permissions incorrect (should be www-data:www-data)

**Resolution**:
```bash
# Fix permissions
sudo chown -R www-data:www-data /var/www/patio
sudo chmod -R 755 /var/www/patio

# Clear cache
cd /var/www/patio/current
php artisan config:clear
php artisan cache:clear

# Restart PHP-FPM
sudo systemctl restart php8.1-fpm
```

### Issue 4: Load Balancer Health Probe Failing

**Symptoms**: VMs not receiving traffic, load balancer backend pool shows "Unhealthy"

**Diagnosis**:
```powershell
# Check health probe configuration
az network lb probe show `
  --resource-group $rg `
  --lb-name "lb-patio-$env" `
  --name "healthProbe"

# Test health endpoint directly on VM
ssh -i ~/.ssh/patio_deploy_key azureuser@${vmIp} 'curl -I http://localhost/health'
```

**Resolution**:
- Ensure `/health` endpoint returns HTTP 200
- Verify Apache is running: `sudo systemctl status apache2`
- Check firewall allows traffic on port 80: `sudo ufw status`

### Issue 5: Application Slow or Timing Out

**Symptoms**: Page load times >5 seconds, requests timing out

**Diagnosis**:
```powershell
# Check VM CPU/memory usage
az vm get-instance-view `
  --resource-group $rg `
  --name "web-vm-patio-$env-001" `
  --query "instanceView.extensions[?name=='AzureMonitorLinuxAgent'].statuses"

# Check MySQL slow query log
mysql -h $mysqlServer -u patioAdmin -p -e "SHOW VARIABLES LIKE 'slow_query_log';"

# Check Redis memory usage
redis-cli -h <redis-host> -a <redis-password> INFO memory
```

**Resolution**:
1. **Scale up VM**: Increase to next SKU tier (B2s → D2s_v3)
2. **Optimize database queries**: Add indexes, review slow query log
3. **Increase Redis memory**: Upgrade to next tier (C0 → C1)
4. **Enable caching**: Add application-level caching for frequently accessed data

---

## Emergency Contacts

| Role | Name | Email | Phone | Escalation Level |
|------|------|-------|-------|------------------|
| Platform Lead | TBD | platform@example.com | - | L1 (Primary) |
| DevOps Engineer | TBD | devops@example.com | - | L2 |
| Security Lead | TBD | security@example.com | - | L3 (Security incidents) |
| On-Call (24/7) | Rotation | oncall@example.com | - | Emergency |

**Escalation Path**:
1. L1 (Platform Lead): All deployment issues
2. L2 (DevOps Engineer): Escalate after 30 minutes if unresolved
3. L3 (Security Lead): Escalate immediately for security incidents
4. On-Call: Escalate for production outages affecting users

**Communication Channels**:
- Slack: `#patio-deployments`
- Email: `platform@example.com`
- Incident Management: PagerDuty / Opsgenie (if configured)

---

## Appendix

### Useful Commands

```powershell
# List all resources in resource group
az resource list --resource-group $rg --output table

# Get deployment logs
az deployment group show --resource-group $rg --name <deployment-name>

# Get VM serial console (troubleshooting boot issues)
az vm boot-diagnostics get-boot-log --resource-group $rg --name "web-vm-patio-$env-001"

# Export deployment template (for documentation)
az deployment group export --resource-group $rg --name <deployment-name>
```

### Related Documentation

- [Infrastructure Documentation](infrastructure.md)
- [Operational Runbook](operational-runbook.md)
- [Security Documentation](security.md)
- [Developer Guide](developer-guide.md)

---

**Document Version**: 1.0.0  
**Last Reviewed**: February 19, 2026  
**Next Review**: March 19, 2026
