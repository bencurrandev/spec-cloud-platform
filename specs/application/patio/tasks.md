---
description: "Task list template for patio application implementation"
---

# Tasks: Patio Application

**Input**: Specification documents from `/specs/application/patio/`  
**Prerequisites**: plan.md (required), spec.md (required for user stories)  
**Tier**: application

---

## 🎯 IMPORTANT: Role Declaration Protocol (Per Constitution §II)

These tasks were created via:
- **Role Declared**: Application
- **Application Target**: NEW: patio
- **Source Tier Spec**: app-patio-001 (constrained by 21 upstream specs)

> Constitution §II requires ALL task generation to maintain role declaration context. These tasks implement the patio application spec from the Application tier, constrained by Platform, Business, Security, Infrastructure, and DevOps tiers.

---

**Tests**: Test & validation tasks are included to verify compliance with upstream tier specifications.

**Organization**: Tasks will be grouped by user story (once defined in spec.md) and by artifact type (IaC generation, pipeline creation, security validation, etc.) to enable independent testing of each story.

---

## Format: `[ID] [P?] [Story] [Type] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **[Type]**: artifact-gen (AI-assisted generation), review (human review), test (validation), deploy (deployment)
- Include exact file paths in descriptions

---

## Phase 0: Setup & Validation ✅ COMPLETE

**Purpose**: Create application directory structure and validate upstream spec alignment

- [x] T001 Create application directory structure: `/artifacts/applications/patio/`
  - ✅ Run: `./artifacts/.templates/scripts/create-app-directory.ps1 -AppName "patio"`
  - ✅ Verified subdirectories created: `iac/`, `modules/`, `scripts/`, `pipelines/`, `docs/`

- [x] T002 Validate upstream spec compliance
  - ✅ Loaded all 21 upstream specs (Platform: 6, Business: 3, Security: 3, Infrastructure: 5, DevOps: 4)
  - ✅ Documented constraints from each tier in spec.md
  - ✅ Validated cost-001 v2.0.0: Non-critical workload tier ($50-100/month)

- [x] T003 [P] Update spec.md with detailed user stories
  - ✅ Defined 5 prioritized user stories (P1-P5)
  - ✅ Documented acceptance scenarios and edge cases
  - ✅ Created functional requirements (REQ-001 through REQ-039)

- [x] T004 [P] Update plan.md with technical context
  - ✅ LAMP stack: PHP 8.1+, Apache 2.4, MySQL 8.0, Ubuntu 22.04 LTS
  - ✅ Performance goals: <200ms search, <500ms booking, 1000-10000 concurrent users
  - ✅ Scale: 50-200 businesses, 1000-10000 customers, 3+ cities

---

## Phase 1: IaC Infrastructure Design & Architecture

**Purpose**: Design LAMP stack infrastructure architecture and create parameter configurations

- [ ] T005 Document infrastructure architecture design
  - File: `/artifacts/applications/patio/docs/architecture.md`
  - Document: VNet topology, subnet structure, NSG rules
  - Document: VM sizing (Standard_B2s dev, Standard_D2s_v3 prod per compute-001)
  - Document: Load balancer configuration (Standard tier, single-zone per net-001)
  - Document: MySQL Flexible Server configuration (Standard tier, daily backups)
  - Document: Storage account tiers (Standard LRS for photos per stor-001)

- [ ] T006 [P] Create environment parameter files - Dev
  - File: `/artifacts/applications/patio/iac/parameters/dev.parameters.json`
  - Define: Dev environment specific values (1 VM, smaller MySQL, minimal storage)
  - Define: Resource naming (patio-dev-*, East US region per comp-001)
  - Define: Cost-optimized SKUs (B2s VM, Basic MySQL tier if available)

- [ ] T007 [P] Create environment parameter files - Staging
  - File: `/artifacts/applications/patio/iac/parameters/staging.parameters.json`
  - Define: Staging environment values (2 VMs, production-like MySQL)
  - Define: Resource naming (patio-staging-*, East US region per comp-001)

- [ ] T008 [P] Create environment parameter files - Production
  - File: `/artifacts/applications/patio/iac/parameters/prod.parameters.json`
  - Define: Production environment values (2-3 VMs, Standard MySQL with HA)
  - Define: Resource naming (patio-prod-*, East US region per comp-001)
  - Define: Production SKUs (D2s_v3 VMs, Standard MySQL per compute-001)

- [ ] T009 Create shared variables file
  - File: `/artifacts/applications/patio/iac/shared-variables.bicep`
  - Define: Common tags (environment, application, cost-center, compliance: NIST-800-171)
  - Define: Naming conventions per artifact-001
  - Define: Location constraints (East US or West US 2 only per comp-001)
  - Define: Encryption standards (AES-256 per dp-001)

- [ ] T010 [P] Create security baseline configuration
  - File: `/artifacts/applications/patio/iac/security-baseline.bicep`
  - Define: NSG rules (allow 443/HTTPS, 22/SSH from bastion only, deny all else)
  - Define: SSH key requirements (no password auth per ac-001)
  - Define: TLS 1.2 minimum version (per dp-001)
  - Define: RBAC role assignments (Customer, Business Owner, Admin per ac-001)
  - Define: Key Vault access policies (restrict to app identity)

---

## Phase 2: IaC Module Implementation (Bicep)

**Purpose**: Implement Bicep IaC modules using AVM wrappers per iac-001

### Networking Infrastructure

- [ ] T011 Implement Virtual Network module
  - File: `/artifacts/applications/patio/iac/modules/network-vnet.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-vnet/main.bicep`
  - Configure: VNet address space (10.0.0.0/16)
  - Configure: Subnets (web: 10.0.1.0/24, db: 10.0.2.0/24, cache: 10.0.3.0/24)
  - Enforce: Single-zone deployment (non-critical tier per net-001)
  - Output: VNet ID, subnet IDs for reference

- [ ] T012 [P] Implement Network Security Group module
  - File: `/artifacts/applications/patio/iac/modules/network-nsg.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-nsg/main.bicep`
  - Configure: Web tier NSG rules (allow 443 inbound from internet, 22 from bastion)
  - Configure: DB tier NSG rules (allow 3306 from web subnet only)
  - Configure: Cache tier NSG rules (allow 6379 from web subnet only)
  - Enforce: Deny all other traffic per ac-001

- [ ] T013 [P] Implement Public IP module
  - File: `/artifacts/applications/patio/iac/modules/network-publicip.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-public-ip/main.bicep`
  - Configure: Static public IP for load balancer
  - Configure: Standard SKU (required for Standard LB)
  - Output: Public IP address, IP ID

- [ ] T014 Implement Load Balancer module
  - File: `/artifacts/applications/patio/iac/modules/network-loadbalancer.bicep`
  - Configure: Standard SKU load balancer (per net-001)
  - Configure: Frontend IP (use public IP from T013)
  - Configure: Backend pool for web VMs
  - Configure: Health probe (HTTP /health or TCP 80)
  - Configure: Load balancing rule (HTTPS 443 to backend pool)
  - Output: Load balancer ID, backend pool ID

### Compute Infrastructure

- [ ] T015 Implement Linux VM module for web tier
  - File: `/artifacts/applications/patio/iac/modules/compute-webvm.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-linux-vm/main.bicep`
  - Configure: Ubuntu 22.04 LTS image
  - Configure: VM SKU (parameterized: B2s for dev, D2s_v3 for prod per compute-001)
  - Configure: SSH key authentication only (no password per ac-001)
  - Configure: Managed identity for Key Vault access
  - Configure: OS disk encryption (AES-256 per dp-001)
  - Configure: Custom script extension for LAMP stack setup (Apache, PHP, extensions)
  - Configure: Attach to load balancer backend pool
  - Output: VM ID, private IP, managed identity principal ID

- [ ] T016 [P] Create VM custom script extension for LAMP setup
  - File: `/artifacts/applications/patio/scripts/install-lamp-stack.sh`
  - Install: Apache 2.4, PHP 8.1, PHP extensions (mysql, redis, gd, curl, mbstring)
  - Install: Composer for PHP dependency management
  - Configure: Apache virtual host for patio application
  - Configure: PHP-FPM settings (memory_limit, upload_max_filesize for photos)
  - Configure: SSL certificate placeholder (Let's Encrypt or Azure managed cert)
  - Harden: Disable directory listing, set proper file permissions

### Database Infrastructure

- [ ] T017 Implement MySQL Flexible Server module
  - File: `/artifacts/applications/patio/iac/modules/database-mysql.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-mysql-flexibleserver/main.bicep`
  - Configure: MySQL 8.0 version
  - Configure: SKU (parameterized: Burstable B1ms for dev, Standard D2ds_v4 for prod)
  - Configure: Storage (20GB dev, 100GB prod with auto-grow)
  - Configure: Backup retention (7 days per stor-001)
  - Configure: Private endpoint in database subnet (no public access)
  - Configure: Encryption at rest enabled (AES-256 per dp-001)
  - Configure: TLS 1.2 minimum version (per dp-001)
  - Configure: Firewall rules (allow web subnet only)
  - Output: MySQL server FQDN, database name, admin username (secret in Key Vault)

- [ ] T018 [P] Create MySQL database schema initialization script
  - File: `/artifacts/applications/patio/scripts/init-database.sql`
  - Create: Database schema (users, patios, cities, bookings, pricing_rules, etc.)
  - Create: Indexes for performance (city_id, patio_id, booking dates)
  - Create: Initial data (seed cities: New York, Chicago, Los Angeles)
  - Configure: Character set UTF8MB4, collation utf8mb4_unicode_ci

### Storage Infrastructure

- [ ] T019 Implement Storage Account for photos
  - File: `/artifacts/applications/patio/iac/modules/storage-photos.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-storage-account/main.bicep`
  - Configure: Standard LRS tier (per stor-001 for non-critical)
  - Configure: Blob container for patio photos (private access)
  - Configure: Encryption at rest enabled (AES-256 per dp-001)
  - Configure: HTTPS only (TLS 1.2+ per dp-001)
  - Configure: Lifecycle management (archive old photos after 2 years)
  - Configure: CDN endpoint for photo delivery
  - Output: Storage account name, blob endpoint, CDN endpoint

- [ ] T020 [P] Implement Storage Account for application logs
  - File: `/artifacts/applications/patio/iac/modules/storage-logs.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-storage-account/main.bicep`
  - Configure: Standard LRS tier for log storage
  - Configure: Blob container for Apache/PHP logs
  - Configure: Retention policy (90 days per audit-001)
  - Output: Storage account name for log shipping

### Security Infrastructure

- [ ] T021 Implement Key Vault module
  - File: `/artifacts/applications/patio/iac/modules/security-keyvault.bicep`
  - Use AVM: `/artifacts/infrastructure/iac-modules/avm-wrapper-key-vault/main.bicep`
  - Configure: Standard tier (or Premium for HSM per dp-001 if budget allows)
  - Configure: RBAC for access control (per ac-001)
  - Configure: Enable soft delete and purge protection
  - Configure: Private endpoint in web subnet
  - Configure: Secrets to store:
    * MySQL admin password
    * Weather API key (OpenWeatherMap)
    * Payment gateway API keys (Stripe/PayPal)
    * SendGrid API key for emails
    * Application secret key for session encryption
  - Output: Key Vault URI, Key Vault name

- [ ] T022 [P] Create Key Vault secrets deployment module
  - File: `/artifacts/applications/patio/iac/modules/security-secrets.bicep`
  - Deploy: Placeholder secrets (actual values set manually post-deployment)
  - Configure: Access policies for web VM managed identity
  - Configure: Expiration policies for rotation reminder
  - Note: Actual secret values NOT in source control (manual/pipeline injection)

### Cache Infrastructure

- [ ] T023 Implement Redis Cache module
  - File: `/artifacts/applications/patio/iac/modules/cache-redis.bicep`
  - Configure: Azure Cache for Redis (Basic C0 tier for dev, Standard C1 for prod)
  - Configure: Private endpoint in cache subnet
  - Configure: TLS 1.2 minimum version (per dp-001)
  - Configure: Non-SSL port disabled
  - Configure: Maxmemory policy: allkeys-lru (session eviction)
  - Output: Redis hostname, Redis primary key (store in Key Vault)

### Main Orchestration

- [ ] T024 Implement main orchestration module
  - File: `/artifacts/applications/patio/iac/main.bicep`
  - Purpose: Orchestrate all infrastructure modules in correct dependency order
  - Order: 1) VNet → 2) NSG → 3) Public IP → 4) Load Balancer → 5) Key Vault → 6) Storage → 7) MySQL → 8) Redis → 9) Web VMs
  - Configure: Parameter inputs from environment-specific parameter files
  - Configure: Module outputs for cross-module dependencies
  - Configure: Resource naming using shared variables
  - Configure: Tagging for all resources (environment, app, cost-center, compliance)
  - Output: Summary of deployed resources, endpoints, connection strings

- [ ] T025 [P] Create bicepconfig.json for linting
  - File: `/artifacts/applications/patio/iac/bicepconfig.json`
  - Configure: Linting rules per lint-001
  - Configure: Analyzer settings (use-stable-vm-images, secure-params-in-nested, etc.)
  - Configure: Module path aliases for AVM wrappers

---

## Phase 3: Deployment Pipelines & Automation

**Purpose**: Create GitHub Actions CI/CD pipelines per cicd-001, cicd-orch-001, deploy-001

- [ ] T026 Implement infrastructure deployment pipeline
  - File: `/artifacts/applications/patio/pipelines/deploy-infrastructure.yml`
  - Configure: GitHub Actions workflow with environment-specific jobs
  - Configure: Bicep linting step (az bicep build per lint-001)
  - Configure: What-If analysis for change preview
  - Configure: Cost estimation step (Azure Cost Estimator or manual calculation)
  - Configure: Cost validation gate (fail if >$100/month for non-critical per cost-001)
  - Configure: Azure Policy compliance check (per pac-001)
  - Configure: Manual approval gate for production deployments (per gov-001)
  - Configure: Deploy to dev → staging → prod with parameter file selection
  - Configure: Rollback capability on deployment failure

- [ ] T027 [P] Implement application deployment pipeline
  - File: `/artifacts/applications/patio/pipelines/deploy-application.yml`
  - Configure: Build step (Composer install, asset compilation if needed)
  - Configure: Security scanning (OWASP dependency check, Snyk)
  - Configure: Unit test execution (PHPUnit)
  - Configure: Code quality checks (PHP_CodeSniffer, PHPStan)
  - Configure: Deploy PHP application to web VMs via SSH
  - Configure: Database migration execution (run init-database.sql, schema updates)
  - Configure: Zero-downtime deployment (deploy to inactive VMs, swap in LB)
  - Configure: Health check validation post-deployment
  - Configure: Rollback to previous version on health check failure

- [ ] T028 [P] Implement observability setup pipeline
  - File: `/artifacts/applications/patio/pipelines/setup-observability.yml`
  - Configure: Deploy Azure Monitor workspace
  - Configure: Deploy Log Analytics workspace
  - Configure: Deploy Application Insights instance
  - Configure: Configure log shipping from VMs (Apache logs, PHP logs, system logs)
  - Configure: Configure metrics collection (per obs-001: request rate, response time, error rate)
  - Configure: Configure alerts (high error rate, slow response, service down)
  - Configure: Create dashboards for SLI/SLO monitoring

- [ ] T029 Create deployment validation script
  - File: `/artifacts/applications/patio/scripts/validate-deployment.ps1`
  - Check: All infrastructure resources deployed successfully
  - Check: VMs accessible via SSH (using key-based auth per ac-001)
  - Check: MySQL database accessible from web VMs
  - Check: Redis cache accessible from web VMs
  - Check: Storage account accessible, blob containers created
  - Check: Key Vault secrets retrievable by VM managed identity
  - Check: Load balancer health probe passing
  - Check: HTTPS endpoint responding (via public IP)
  - Check: Application logs flowing to Log Analytics
  - Output: Validation report with pass/fail per check

- [ ] T030 [P] Create infrastructure teardown script (for dev/staging cleanup)
  - File: `/artifacts/applications/patio/scripts/teardown-environment.ps1`
  - Purpose: Clean up dev/staging environments to save costs
  - Configure: Delete resource group with all resources
  - Configure: Confirmation prompt before deletion
  - Configure: Exclude production environment (safety check)

---

## Phase 4: Testing & Validation

**Purpose**: Validate IaC modules and deployment pipelines (BLOCKING GATE before deployment)

- [ ] T031 [review] Review IaC modules for spec compliance
  - Review: `/artifacts/applications/patio/iac/modules/*.bicep`
  - Verify: All modules use AVM wrappers from `/artifacts/infrastructure/iac-modules/`
  - Verify: VM SKUs match approved list (B2s dev, D2s_v3 prod per compute-001)
  - Verify: Networking follows single-zone pattern (non-critical per net-001)
  - Verify: Storage uses Standard LRS (per stor-001)
  - Verify: MySQL configured with encryption, TLS 1.2+, daily backups
  - Verify: All resources tagged with environment, app, cost-center, compliance
  - Verify: NSG rules enforce SSH keys only, HTTPS only
  - Verify: Data residency in East US or West US 2 (per comp-001)

- [ ] T032 [review] Review security configuration
  - Review: Security baseline, Key Vault, NSG rules
  - Verify: AES-256 encryption at rest for all storage (per dp-001)
  - Verify: TLS 1.2+ minimum for all connections (per dp-001)
  - Verify: SSH key authentication only, no passwords (per ac-001)
  - Verify: RBAC roles defined and assigned (per ac-001)
  - Verify: Key Vault soft delete and purge protection enabled
  - Verify: Audit logging configured for 90-day retention (per audit-001)
  - Verify: No secrets hardcoded in Bicep files or scripts

- [ ] T033 [test] Validate Bicep linting
  - Run: `az bicep build --file /artifacts/applications/patio/iac/main.bicep`
  - Run: Bicep linter with rules from lint-001
  - Verify: No linting errors or warnings
  - Verify: Best practices followed (stable VM images, secure parameters)

- [ ] T034 [test] Cost estimation calculation
  - Calculate: VM costs (B2s ~$30/mo, D2s_v3 ~$70/mo)
  - Calculate: MySQL costs (Burstable B1ms ~$15/mo, Standard D2ds ~$50/mo)
  - Calculate: Storage costs (blob ~$5/mo, logs ~$2/mo)
  - Calculate: Redis costs (Basic C0 ~$15/mo, Standard C1 ~$70/mo)
  - Calculate: Bandwidth and other costs (~$5-10/mo)
  - Verify: Dev total <$50/mo, Staging <$75/mo, Prod <$100/mo (per cost-001)
  - Document: Expected costs in `/artifacts/applications/patio/docs/cost-estimate.md`

- [ ] T035 [test] What-If deployment analysis
  - Run: `az deployment sub what-if` for dev environment
  - Review: Resources to be created, modified, deleted
  - Verify: No unexpected changes or resource deletions
  - Document: What-If output for review

---

## Phase 5: Dev Environment Deployment

**Purpose**: Deploy to dev environment and validate functionality

- [ ] T036 [deploy] Deploy infrastructure to dev
  - Run: `/artifacts/applications/patio/pipelines/deploy-infrastructure.yml` (dev environment)
  - Monitor: Deployment progress, check for errors
  - Validate: All resources created successfully (VNet, NSG, VMs, MySQL, Redis, Storage, Key Vault)

- [ ] T027 [deploy] Deploy application to dev
  - Run: `/artifacts/applications/patio/pipelines/deploy-application.yml` (dev)
  - Validate: Application running, health checks passing

- [ ] T028 [test] Validate dev environment
  - Test: Security controls (encryption, RBAC, SSH keys, audit logs)
  - Test: Observability (logs, metrics, tracing)
  - Test: Performance (meet SLI/SLO targets)

### Staging Environment

- [ ] T029 [deploy] Deploy infrastructure to staging
  - Run: `/artifacts/applications/patio/pipelines/deploy-infrastructure.yml` (staging)
  - Validate: Infrastructure deployed successfully  - Validate: All resources created successfully (VNet, NSG, VMs, MySQL, Redis, Storage, Key Vault)
  - Validate: Resource naming follows conventions (patio-dev-*)
  - Validate: Tags applied correctly (environment: dev, app: patio)

- [ ] T037 [test] Run Azure Policy compliance scan on dev
  - Run: Azure Policy evaluation on resource group
  - Verify: 100% compliance with configured policies (per pac-001)
  - Document: Any policy violations and remediation steps

- [ ] T038 [test] Validate dev infrastructure connectivity
  - Run: `/artifacts/applications/patio/scripts/validate-deployment.ps1` (dev)
  - Test: SSH access to web VM using key (per ac-001)
  - Test: MySQL connection from web VM (port 3306)
  - Test: Redis connection from web VM (port 6379)
  - Test: Blob storage write/read from web VM
  - Test: Key Vault secret retrieval using VM managed identity
  - Test: Load balancer health probe responding
  - Test: Public IP resolving and HTTPS endpoint accessible

- [ ] T039 [deploy] Deploy LAMP application to dev
  - Run: `/artifacts/applications/patio/pipelines/deploy-application.yml` (dev)
  - Deploy: PHP application code to web VM
  - Deploy: Database schema using init-database.sql
  - Configure: Environment variables from Key Vault
  - Configure: Apache virtual host and PHP settings
  - Restart: Apache service
  - Validate: Application health check endpoint responding

- [ ] T040 [test] Functional testing on dev
  - Test: Homepage loads (HTTP 200 response)
  - Test: User registration and login works
  - Test: Patio search and filtering works
  - Test: Weather forecast displays for booking dates
  - Test: Dynamic pricing calculation works
  - Test: Photo upload to blob storage works
  - Test: Session persistence via Redis works
  - Document: Any issues or bugs found

- [ ] T041 [test] Security testing on dev
  - Test: HTTPS enforced (HTTP redirects to HTTPS)
  - Test: SQL injection prevention (parameterized queries)
  - Test: XSS protection (input sanitization)
  - Test: CSRF tokens on forms
  - Test: Password hashing (bcrypt) working
  - Test: SSH access requires key (password auth disabled)
  - Document: Security test results

- [ ] T042 [test] Observability validation on dev
  - Verify: Apache access logs flowing to Log Analytics
  - Verify: PHP error logs flowing to Log Analytics
  - Verify: Application Insights tracking page views
  - Verify: Custom metrics being collected (booking count, search queries)
  - Verify: Alerts configured and testable
  - Create: Sample dashboard showing key metrics

---

## Phase 6: Staging Environment Deployment

**Purpose**: Deploy to staging for production-like testing

- [ ] T043 [deploy] Deploy infrastructure to staging
  - Run: `/artifacts/applications/patio/pipelines/deploy-infrastructure.yml` (staging)
  - Use: `/artifacts/applications/patio/iac/parameters/staging.parameters.json`
  - Validate: All resources deployed successfully
  - Validate: Cost within budget (<$75/mo for staging)

- [ ] T044 [deploy] Deploy application to staging
  - Run: `/artifacts/applications/patio/pipelines/deploy-application.yml` (staging)
  - Deploy: Latest application code
  - Deploy: Database with production-like data volume (anonymized production data)
  - Validate: Application running and accessible

- [ ] T045 [test] Performance testing on staging
  - Run: Load test simulating 500 concurrent users (Apache JMeter or k6)
  - Measure: API response times (target <200ms p95 for search)
  - Measure: Page load times (target <2s p95)
  - Measure: Database query performance (<100ms p95)
  - Identify: Performance bottlenecks and optimization opportunities
  - Document: Performance test results

- [ ] T046 [test] User acceptance testing on staging
  - Test: Complete user journey (registration → search → book → payment → confirmation)
  - Test: Business owner journey (create patio → set pricing → view bookings)
  - Test: Admin functions (manage users, moderate content)
  - Test: Multi-city support (switch cities, view city-specific listings)
  - Test: Weather integration accuracy and responsiveness
  - Document: UAT results and any issues

- [ ] T047 [test] Security penetration testing on staging
  - Run: OWASP ZAP automated security scan
  - Test: Authentication bypass attempts
  - Test: Authorization escalation attempts
  - Test: Input validation on all forms
  - Test: File upload vulnerabilities
  - Test: API endpoint security
  - Document: Security findings and remediation

---

## Phase 7: Production Environment Deployment

**Purpose**: Deploy to production with approval gates (per gov-001)

- [ ] T048 [review] Pre-production deployment review
  - Review: All dev and staging test results passed
  - Review: Security findings remediated
  - Review: Performance meets SLI/SLO targets
  - Review: Cost estimates within budget ($50-100/mo per cost-001)
  - Review: All 21 upstream spec compliance verified
  - Obtain: Platform team approval for production deployment

- [ ] T049 [deploy] Deploy infrastructure to production
  - Obtain: Governance approval (per gov-001)
  - Run: `/artifacts/applications/patio/pipelines/deploy-infrastructure.yml` (prod)
  - Use: `/artifacts/applications/patio/iac/parameters/prod.parameters.json`
  - Validate: All resources deployed successfully
  - Validate: Resource naming follows conventions (patio-prod-*)

- [ ] T050 [deploy] Deploy application to production
  - Obtain: Governance approval (per gov-001)
  - Run: `/artifacts/applications/patio/pipelines/deploy-application.yml` (prod)
  - Deploy: Verified application code (from staging)
  - Deploy: Database schema and initial data (seed cities)
  - Configure: Production environment variables and secrets
  - Validate: Health check endpoint responding
  - Validate: Zero downtime during deployment

- [ ] T051 [test] Production smoke testing
  - Test: Homepage accessible via public IP/domain
  - Test: User registration and login
  - Test: Patio search displays results
  - Test: Weather API integration working
  - Test: Payment gateway (test mode) working
  - Test: Email notifications sending
  - Monitor: No errors in logs during smoke test

- [ ] T052 [deploy] Configure production monitoring and alerting
  - Configure: Alert rules for critical issues (service down, high error rate, slow response)
  - Configure: On-call notification channels (email, SMS, Slack)
  - Configure: SLI/SLO dashboards (99% uptime, <200ms search, <500ms booking)
  - Configure: Cost monitoring alerts (>$100/mo threshold)
  - Configure: Security audit log monitoring
  - Test: Alert triggers and notifications

- [ ] T053 [test] Production validation (first 24 hours)
  - Monitor: Application availability and uptime
  - Monitor: Response times and performance metrics
  - Monitor: Error rates and exception logs
  - Monitor: Cost accumulation vs estimates
  - Monitor: Security audit logs for anomalies
  - Document: First 24 hours operational report

---

## Phase 8: Documentation & Handoff

**Purpose**: Complete documentation and hand off to operations team

- [ ] T054 Create infrastructure documentation
  - File: `/artifacts/applications/patio/docs/infrastructure.md`
  - Document: Architecture diagram (network topology, components)
  - Document: Resource list with names, SKUs, regions
  - Document: Cost breakdown per resource
  - Document: Disaster recovery plan (backup/restore procedures)
  - Document: Scaling procedures (add VMs, increase MySQL tier)

- [ ] T055 [P] Create deployment runbook
  - File: `/artifacts/applications/patio/docs/deployment-runbook.md`
  - Document: Pre-deployment checklist
  - Document: Step-by-step deployment procedures per environment
  - Document: Rollback procedures
  - Document: Post-deployment validation steps
  - Document: Common deployment issues and resolutions

- [ ] T056 [P] Create operational runbook
  - File: `/artifacts/applications/patio/docs/operational-runbook.md`
  - Document: Monitoring and alerting procedures
  - Document: Incident response procedures
  - Document: Backup and restore procedures
  - Document: Performance tuning guidelines
  - Document: Scaling procedures
  - Document: On-call escalation procedures

- [ ] T057 [P] Create security documentation
  - File: `/artifacts/applications/patio/docs/security.md`
  - Document: Security controls implemented (encryption, RBAC, SSH keys, etc.)
  - Document: Compliance checklist (21 upstream specs)
  - Document: Secret rotation procedures
  - Document: Security incident response procedures
  - Document: Audit log review procedures

- [ ] T058 Create developer onboarding guide
  - File: `/artifacts/applications/patio/docs/developer-guide.md`
  - Document: Local development setup (LAMP stack, dependencies)
  - Document: Code structure and conventions
  - Document: Database schema and ERD
  - Document: API endpoints and contracts
  - Document: Testing procedures (unit, integration, E2E)
  - Document: Contribution guidelines

- [ ] T059 Update application registry
  - File: `/specs/application/_index.yaml`
  - Update: Patio application status from "draft" to "deployed"
  - Document: Production deployment date and version
  - Document: Production endpoints and URLs

---

## Summary & Success Metrics

### Task Completion Summary
- **Phase 0 (Setup)**: 4 tasks ✅ COMPLETE
- **Phase 1 (IaC Design)**: 6 tasks (T005-T010)
- **Phase 2 (IaC Implementation)**: 15 tasks (T011-T025)
- **Phase 3 (Pipelines)**: 5 tasks (T026-T030)
- **Phase 4 (Testing/Validation)**: 5 tasks (T031-T035)
- **Phase 5 (Dev Deployment)**: 7 tasks (T036-T042)
- **Phase 6 (Staging Deployment)**: 5 tasks (T043-T047)
- **Phase 7 (Production Deployment)**: 6 tasks (T048-T053)
- **Phase 8 (Documentation)**: 6 tasks (T054-T059)
- **Total**: 59 tasks

### Parallelization Opportunities
- **Phase 1**: T006-T008 (parameter files) can run in parallel
- **Phase 2**: T012-T013 (NSG, Public IP), T019-T020 (storage accounts), T022 (secrets) can run in parallel
- **Phase 3**: T027-T028 (pipelines) can run in parallel
- **Phase 8**: T055-T058 (documentation) can run in parallel after T054

### Dependencies
1. Phase 0 must complete before Phase 1
2. Phase 1 (design) must complete before Phase 2 (implementation)
3. Phase 2 (IaC modules) must complete before Phase 3 (pipelines)
4. Phase 3 (pipelines) must complete before Phase 4 (testing)
5. Phase 4 (validation) must pass before Phase 5 (dev deployment)
6. Phase 5 (dev) must pass before Phase 6 (staging)
7. Phase 6 (staging) must pass before Phase 7 (production)
8. Phase 8 (documentation) can start after Phase 7 deployment

### Key Success Criteria
✅ Infrastructure costs <$50 dev, <$75 staging, <$100 prod (per cost-001 v2.0.0)
✅ All IaC modules use AVM wrappers (per iac-001)
✅ 100% Azure Policy compliance (per pac-001)
✅ All data encrypted AES-256 at rest, TLS 1.2+ in transit (per dp-001)
✅ SSH key auth only, RBAC configured, audit logging enabled (per ac-001, audit-001)
✅ Response times <200ms search, <500ms booking (per plan.md)
✅ 99% uptime SLI/SLO target (per obs-001)
✅ Multi-environment deployment (dev/staging/prod per env-001)

---

## Next Steps

1. **Start Phase 1**: Begin with T005 (architecture documentation)
2. **Create parameter files**: Complete T006-T008 in parallel
3. **Design security baseline**: Complete T009-T010
4. **Begin Phase 2**: Implement networking modules (T011-T014)
5. **Continue implementation**: Complete remaining IaC modules (T015-T025)

---

## Reference Documentation

- **Application Spec**: [/specs/application/patio/spec.md](../spec.md)
- **Implementation Plan**: [/specs/application/patio/plan.md](../plan.md)
- **Constitution**: [/.specify/memory/constitution.md](../../.specify/memory/constitution.md)
- **AVM Wrapper Modules**: [/artifacts/infrastructure/iac-modules/](../../infrastructure/iac-modules/)
- **Cost Spec**: [/specs/business/cost/spec.md](../../business/cost/spec.md)
- **Security Specs**: [/specs/security/](../../security/)
- **Infrastructure Specs**: [/specs/infrastructure/](../../infrastructure/)
- **DevOps Specs**: [/specs/devops/](../../devops/)

---

## Notes

- This is a **NEW APPLICATION** - all IaC artifacts created from scratch using AVM wrappers
- All tasks implement LAMP stack (Linux, Apache, MySQL 8.0, PHP 8.1+) on Azure
- Infrastructure must comply with **21 upstream specifications** (Platform: 6, Business: 3, Security: 3, Infrastructure: 5, DevOps: 4)
- Cost target: **$50-100/month** for production (non-critical tier per cost-001 v2.0.0)
- Security baseline: **AES-256 encryption, SSH keys only, RBAC, TLS 1.2+, audit logging**
- All production deployments require **governance approval** (per gov-001)
- Tasks marked **[P]** can be executed in parallel
- Tasks marked **[review]** are **BLOCKING GATES** requiring human approval
- Tasks marked **[test]** must pass before proceeding to next phase

