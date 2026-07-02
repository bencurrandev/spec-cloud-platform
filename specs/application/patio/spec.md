---
# YAML Frontmatter - Category-Based Spec System
tier: application
category: patio
spec-id: app-patio-001
version: 1.0.0
status: draft
created: 2026-02-19
description: "Patio application specification"

# Dependencies (AUTO-INJECTED from upstream tiers)
depends-on:
  # Platform Tier (6 specs - FOUNDATIONAL)
  - tier: platform
    category: spec-system
    spec-id: spec-001
    version: 1.0.0-draft
    reason: "Application spec follows specification system structure and versioning"
  
  - tier: platform
    category: policy-as-code
    spec-id: pac-001
    version: 1.0.0-draft
    reason: "Application deployments must comply with Azure Policy enforcement"
  
  - tier: platform
    category: iac-linting
    spec-id: lint-001
    version: 1.0.0-draft
    reason: "Application IaC artifacts must follow linting standards"
  
  - tier: platform
    category: artifact-org
    spec-id: artifact-001
    version: 1.0.0
    reason: "Application artifacts must follow standardized directory structure"
  
  - tier: platform
    category: category-based-spec-system
    spec-id: 002-category-based-spec-system
    version: draft
    reason: "Application spec follows category-based hierarchy"
  
  - tier: platform
    category: application-artifact-organization
    spec-id: platform-001-application-artifact-organization
    version: approved
    reason: "Application artifacts must use /artifacts/applications/patio/ structure"
  
  # Business Tier (3 specs)
  - tier: business
    category: cost
    spec-id: cost-001
    version: 2.0.0
    reason: "Application infrastructure must align with cost baselines per workload tier"
  
  - tier: business
    category: governance
    spec-id: gov-001
    version: 1.0.0-draft
    reason: "Application deployments must comply with approval workflows and SLAs"
  
  - tier: business
    category: compliance-framework
    spec-id: comp-001
    version: 1.0.0-draft
    reason: "Application must comply with NIST 800-171 and data residency requirements"
  
  # Security Tier (3 specs)
  - tier: security
    category: data-protection
    spec-id: dp-001
    version: 1.0.0
    reason: "Application must implement AES-256 encryption, HSM, and TLS 1.2+"
  
  - tier: security
    category: access-control
    spec-id: ac-001
    version: 1.0.0-draft
    reason: "Application must use RBAC, SSH keys only, and MFA"
  
  - tier: security
    category: audit-logging
    spec-id: audit-001
    version: 1.0.0-draft
    reason: "Application must maintain audit trails via Azure Monitor"
  
  # Infrastructure Tier (5 specs)
  - tier: infrastructure
    category: compute
    spec-id: compute-001
    version: 2.0.0
    reason: "Application must use approved VM SKUs per workload tier"
  
  - tier: infrastructure
    category: networking
    spec-id: net-001
    version: 2.0.0
    reason: "Application networking must follow multi-zone patterns and load balancer standards"
  
  - tier: infrastructure
    category: storage
    spec-id: stor-001
    version: 2.0.0
    reason: "Application storage must use approved storage tiers and backup retention"
  
  - tier: infrastructure
    category: cicd-pipeline
    spec-id: cicd-001
    version: 2.0.0
    reason: "Application deployments must follow CI/CD pipeline standards with cost gates"
  
  - tier: infrastructure
    category: iac-modules
    spec-id: iac-001
    version: 1.0.0-draft
    reason: "Application IaC must use centralized reusable wrapper modules (AVM)"
  
  # DevOps Tier (4 specs)
  - tier: devops
    category: observability
    spec-id: obs-001
    version: 1.0.0-placeholder
    reason: "Application must implement logging, metrics, tracing, and SLI/SLO monitoring"
  
  - tier: devops
    category: environment-management
    spec-id: env-001
    version: 1.0.0-placeholder
    reason: "Application must support dev/staging/prod environments with proper configuration"
  
  - tier: devops
    category: deployment-automation
    spec-id: deploy-001
    version: 1.0.0-placeholder
    reason: "Application deployments must follow deployment patterns (blue-green, canary)"
  
  - tier: devops
    category: ci-cd-orchestration
    spec-id: cicd-orch-001
    version: 1.0.0-placeholder
    reason: "Application CI/CD must integrate with orchestration workflows"

# Precedence rules
precedence:
  note: "Application tier is lowest priority; constrained by all upstream tiers"
  loses-to:
    - tier: platform
      category: "*"
      spec-id: "*"
      reason: "Platform tier is foundational and cannot be overridden"
    - tier: business
      category: "*"
      spec-id: "*"
      reason: "Business requirements constrain application features"
    - tier: security
      category: "*"
      spec-id: "*"
      reason: "Security requirements are non-negotiable"
    - tier: infrastructure
      category: "*"
      spec-id: "*"
      reason: "Infrastructure capabilities constrain application deployment"
    - tier: devops
      category: "*"
      spec-id: "*"
      reason: "DevOps practices constrain application operational model"
---

# Specification: Patio Application

**Tier**: application  
**Category**: patio  
**Spec ID**: app-patio-001  
**Created**: 2026-02-19  
**Status**: Draft  
**Input**: Patio scheduling webapp for bars and restaurants - customers can schedule patio reservations across various cities with weather integration and dynamic pricing

---

## 🎯 IMPORTANT: Role Declaration Protocol (Per Constitution §II)

This spec was created via:
- **Role Declared**: Application
- **Application Target**: NEW: patio

> Constitution §II requires ALL spec updates to begin with explicit role declaration. This Application spec is constrained by 21 upstream specifications across Platform, Business, Security, Infrastructure, and DevOps tiers.

---

## Spec Source & Hierarchy

**Parent Tier Specs** (constraints that apply to this spec):
- **Platform Tier (6 specs)**: Foundational standards for spec format, IaC linting, policy enforcement, artifact organization
- **Business Tier (3 specs)**: Cost baselines, governance workflows, compliance frameworks (NIST 800-171)
- **Security Tier (3 specs)**: Data protection (AES-256, HSM), access control (RBAC, SSH, MFA), audit logging
- **Infrastructure Tier (5 specs)**: Compute SKUs, networking patterns, storage tiers, CI/CD pipelines, IaC modules
- **DevOps Tier (4 specs)**: Observability, environment management, deployment automation, CI/CD orchestration

**Derived Downstream Specs** (specs that will depend on this one):
- None (Application tier is the lowest tier; no downstream dependencies)

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - User Account Management (Priority: P1)

Customers and business owners need to create accounts, log in securely, and manage their profiles to access the patio scheduling system.

**Why this priority**: Foundation for all other features - authentication/authorization is required before users can book patios or businesses can list them.

**Independent Test**: User can register, log in, update profile, and log out. Each action can be tested independently with test credentials.

**Acceptance Scenarios**:

1. **Given** new customer visits site, **When** they complete registration form with email/password, **Then** account is created and confirmation email sent
2. **Given** registered user enters valid credentials, **When** they click login, **Then** they are authenticated and redirected to dashboard
3. **Given** authenticated user, **When** they update profile information, **Then** changes are saved and reflected in their account
4. **Given** business owner registers, **When** they provide business verification details, **Then** they receive business account with patio management capabilities
5. **Given** user forgets password, **When** they request password reset, **Then** secure reset link is emailed

---

### User Story 2 - Patio Discovery and Booking (Priority: P2)

Customers need to browse available patios in their city, view details (capacity, amenities, photos), check availability, and make reservations.

**Why this priority**: Core value proposition - enables customers to discover and book patio spaces, delivering immediate business value.

**Independent Test**: Customer can search for patios, filter by criteria, view details, select date/time, and complete booking.

**Acceptance Scenarios**:

1. **Given** customer is logged in, **When** they select their city, **Then** list of available patios is displayed with photos and basic info
2. **Given** customer views patio listings, **When** they apply filters (capacity, amenities, price range), **Then** results update to match criteria
3. **Given** customer selects a patio, **When** they view details page, **Then** they see photos, description, capacity, amenities, pricing, and availability calendar
4. **Given** customer selects date/time, **When** patio is available, **Then** booking form is displayed with current pricing
5. **Given** customer completes booking form, **When** they confirm reservation, **Then** booking is created, payment processed, and confirmation email sent
6. **Given** customer has active booking, **When** they view their bookings, **Then** they can see upcoming reservations and cancel if needed

---

### User Story 3 - Weather-Aware Scheduling (Priority: P3)

Customers can view weather forecasts for potential booking dates to ensure optimal patio experience on sunny days.

**Why this priority**: Key differentiator - helps customers make informed decisions and increases booking satisfaction.

**Independent Test**: Customer can view weather forecast for any available date and receive weather-based recommendations.

**Acceptance Scenarios**:

1. **Given** customer views availability calendar, **When** they hover over a date, **Then** weather forecast preview is displayed (temperature, conditions, precipitation)
2. **Given** customer is booking a patio, **When** they select a date, **Then** detailed weather forecast for that date/time is shown
3. **Given** customer browses dates, **When** system detects optimal weather, **Then** those dates are highlighted as "Great Weather" recommendations
4. **Given** rain is forecasted, **When** customer views that date, **Then** system shows weather warning and suggests covered patio alternatives
5. **Given** customer has upcoming booking, **When** weather forecast changes significantly, **Then** they receive notification with updated forecast

---

### User Story 4 - Business Patio Management and Dynamic Pricing (Priority: P4)

Business owners can list their patios, manage availability, and set dynamic pricing based on demand, weather, and time of day/week.

**Why this priority**: Revenue optimization - enables businesses to maximize revenue through intelligent pricing strategies.

**Independent Test**: Business owner can create patio listing, configure pricing rules, and view booking analytics.

**Acceptance Scenarios**:

1. **Given** business owner is logged in, **When** they create patio listing with details/photos, **Then** patio becomes searchable to customers
2. **Given** business manages patio, **When** they set availability calendar, **Then** customers can only book available time slots
3. **Given** business configures pricing, **When** they set base price and dynamic rules (weekend premium, weather bonus, peak hours), **Then** pricing automatically adjusts
4. **Given** sunny weather forecasted, **When** dynamic pricing enabled, **Then** prices increase by configured percentage for high-demand sunny days
5. **Given** low booking volume, **When** business enables demand-based pricing, **Then** system automatically reduces prices to encourage bookings
6. **Given** business has active bookings, **When** they view analytics dashboard, **Then** they see revenue, occupancy rates, and pricing performance

---

### User Story 5 - Multi-City Expansion (Priority: P5)

System supports multiple cities with city-specific patio listings, allowing customers to switch between cities and businesses to operate in multiple locations.

**Why this priority**: Scalability - enables platform growth, but not critical for initial MVP.

**Independent Test**: User can select different cities and see city-specific listings; one business can manage patios across cities.

**Acceptance Scenarios**:

1. **Given** customer accesses site, **When** they select city from dropdown, **Then** patio listings filtered to selected city only
2. **Given** customer searches for patios, **When** they enter location/address, **Then** system detects city and shows nearby patios
3. **Given** business operates in multiple cities, **When** they create listings, **Then** each patio is associated with specific city
4. **Given** system admin adds new city, **When** configuration is complete, **Then** city appears in selection and accepts new patio listings
5. **Given** customer has bookings in multiple cities, **When** they view booking history, **Then** bookings are grouped by city for clarity

---

### Edge Cases

- What happens when customer books a patio and weather changes dramatically (e.g., sunny to thunderstorm)?
  - System sends notification to customer with updated forecast
  - Option to reschedule or cancel with flexible cancellation policy
  
- How does system handle double-booking scenarios?
  - Optimistic locking on booking table
  - Real-time availability checks before payment processing
  - If conflict detected, show error and refresh availability
  
- What if weather API is unavailable?
  - Graceful degradation: show bookings without weather data
  - Cache last known forecast for 24 hours
  - Display notice that weather data is temporarily unavailable
  
- How does dynamic pricing handle extreme scenarios (e.g., 500% price increase)?
  - Configure maximum price multiplier limits per business (e.g., max 3x base price)
  - Business owner approval required for pricing above threshold
  
- What happens when patio reaches capacity for a time slot?
  - Mark as "Fully Booked" in availability calendar
  - Offer waitlist option with notification if cancellation occurs
  
- How does system handle different timezones across cities?
  - Store all times in UTC in database
  - Display times in city-specific timezone to users
  - Clearly indicate timezone in booking confirmations

---

## Requirements *(mandatory)*

### Functional Requirements

**Authentication & Authorization**
- **REQ-001**: System MUST support user registration with email/password authentication
- **REQ-002**: System MUST enforce SSH key-based access for server administration (per ac-001)
- **REQ-003**: System MUST implement RBAC with three roles: Customer, Business Owner, Admin
- **REQ-004**: System MUST require MFA for business owner and admin accounts (per ac-001)
- **REQ-005**: System MUST support password reset via secure email token

**Patio Management**
- **REQ-006**: System MUST allow business owners to create patio listings with details (name, description, capacity, amenities, photos, location)
- **REQ-007**: System MUST support availability calendar management per patio (block dates, set hours)
- **REQ-008**: System MUST validate patio capacity limits during booking process
- **REQ-009**: System MUST support multiple photos per patio (minimum 3, maximum 20)
- **REQ-010**: System MUST geocode patio addresses for map display and proximity search

**Booking System**
- **REQ-011**: System MUST prevent double-booking through optimistic locking
- **REQ-012**: System MUST support booking time slots (minimum 1 hour, maximum 8 hours)
- **REQ-013**: System MUST calculate total price based on duration, dynamic pricing rules, and taxes
- **REQ-014**: System MUST send booking confirmation email with details and calendar invite
- **REQ-015**: System MUST allow customers to cancel bookings within cancellation policy window
- **REQ-016**: System MUST support booking modifications (date/time changes) subject to availability

**Weather Integration**
- **REQ-017**: System MUST integrate with weather API (OpenWeatherMap or similar) for 14-day forecasts
- **REQ-018**: System MUST display weather conditions (temperature, precipitation, cloud cover, wind) for booking dates
- **REQ-019**: System MUST highlight dates with optimal weather (>20°C, <20% precipitation, <40% cloud cover)
- **REQ-020**: System MUST send weather alert notifications 24 hours before booking if forecast changes significantly
- **REQ-021**: System MUST cache weather data for performance (refresh every 6 hours)

**Dynamic Pricing**
- **REQ-022**: System MUST support base pricing configuration per patio
- **REQ-023**: System MUST apply time-based pricing multipliers (weekday vs weekend, time of day)
- **REQ-024**: System MUST apply weather-based pricing multipliers (sunny day premium)
- **REQ-025**: System MUST apply demand-based pricing (occupancy-driven adjustments)
- **REQ-026**: System MUST enforce maximum price multiplier limits per business (configurable, default 3x)
- **REQ-027**: System MUST display pricing breakdown to customers (base price + adjustments)

**Multi-City Support**
- **REQ-028**: System MUST support multiple cities with city-specific patio listings
- **REQ-029**: System MUST allow users to select/switch cities via dropdown or geolocation
- **REQ-030**: System MUST filter search results by selected city
- **REQ-031**: System MUST support timezone-aware scheduling per city

**Search & Discovery**
- **REQ-032**: System MUST support patio search by city, date, capacity, price range
- **REQ-033**: System MUST support filtering by amenities (covered, heating, food service, bar, pet-friendly)
- **REQ-034**: System MUST support proximity search (show patios near address/coordinates)
- **REQ-035**: System MUST display search results with photos, price, rating, availability

**Payments**
- **REQ-036**: System MUST integrate with payment gateway (Stripe or PayPal) for secure transactions
- **REQ-037**: System MUST support deposit payments (partial upfront, balance on arrival) or full payment
- **REQ-038**: System MUST process refunds per cancellation policy
- **REQ-039**: System MUST support business payout schedules

### Key Entities *(include if application involves data)*

- **User**: Represents customers, business owners, and admins
  - Attributes: user_id, email, password_hash, role (customer/business/admin), mfa_enabled, created_at
  - Relationships: has many Bookings (if customer), has many Patios (if business owner)

- **Patio**: Represents a bookable patio space at a bar/restaurant
  - Attributes: patio_id, business_owner_id, name, description, address, city_id, capacity, amenities[], base_price_hourly, photos[], latitude, longitude, created_at
  - Relationships: belongs to User (business owner), has many Bookings, has many AvailabilityBlocks, has many PricingRules

- **City**: Represents a geographic city where patios are located
  - Attributes: city_id, name, state/province, country, timezone, latitude, longitude, is_active
  - Relationships: has many Patios

- **Booking**: Represents a customer reservation for a patio
  - Attributes: booking_id, customer_id, patio_id, start_datetime, end_datetime, duration_hours, base_price, final_price, pricing_breakdown, status (pending/confirmed/cancelled), payment_status, created_at
  - Relationships: belongs to User (customer), belongs to Patio

- **AvailabilityBlock**: Represents time periods when patio is unavailable
  - Attributes: block_id, patio_id, start_datetime, end_datetime, reason (closed/booked/maintenance)
  - Relationships: belongs to Patio

- **PricingRule**: Represents dynamic pricing configuration for a patio
  - Attributes: rule_id, patio_id, rule_type (time_based/weather_based/demand_based), multiplier, conditions (JSON), is_active
  - Relationships: belongs to Patio

- **WeatherForecast**: Cached weather data for cities
  - Attributes: forecast_id, city_id, forecast_date, temperature_high, temperature_low, precipitation_chance, cloud_cover, conditions, fetched_at
  - Relationships: belongs to City

### Tier-Specific Constraints *(mandatory for Application tier)*

**Application Tier Constraints**:
- **Performance SLAs**: 
  - API response time <200ms p95 for search/browse operations
  - API response time <500ms p95 for booking operations
  - Page load time <2 seconds p95
  - Support 1,000 concurrent users initially, scale to 10,000
  - Database query performance <100ms p95
  
- **Deployment Strategy**: Blue-green deployment with automated rollback
  - Deploy to dev → staging → production with approval gates
  - Zero-downtime deployments during business hours
  - Database migrations run separately with rollback plan
  
- **Scaling Constraints**: 
  - Web tier: Horizontal auto-scaling (2-10 instances) based on CPU >70%
  - Database: MySQL with read replicas for scaling read operations
  - Session storage: Shared session store (Redis) for multi-instance support
  - File storage: Azure Blob Storage for patio photos (not local disk)
  - CDN: Use Azure CDN for static assets and photo delivery
  
- **ARTIFACT ORGANIZATION** (Required per `specs/platform/001-application-artifact-organization/spec.md`):
  - **Application Directory**: `/artifacts/applications/patio/`
  - **Required Subdirectories**: `iac/`, `modules/`, `scripts/`, `pipelines/`, `docs/`
  - **Creation**: Run `./artifacts/.templates/scripts/create-app-directory.ps1 -AppName "patio"`
  - **Naming Convention**: `patio-<component>.bicep` (IaC), `patio-<purpose>.<ext>` (scripts)
  - **Validation**: Run `./artifacts/.templates/scripts/validate-artifact-structure.ps1 -AppName "patio"`

**Upstream Tier Compliance**:
- **Cost (cost-001 v2.0.0)**: 
  - Workload tier: Non-Critical (user-facing web app, not mission-critical)
  - Monthly infrastructure budget: $50-100 per cost-001 baseline for non-critical tier
  - VM SKU: Standard_B2s or Standard_D2s_v3 (approved per compute-001)
  - Storage tier: Standard LRS for patio photos, premium for database (per stor-001)
  
- **Security (dp-001 v1.0.0)**: 
  - Database encryption at rest: AES-256 (MySQL encryption enabled)
  - TLS 1.2+ for all HTTPS traffic
  - Password storage: bcrypt hashing (cost factor 12)
  - Azure Key Vault for database credentials, API keys, payment gateway secrets
  - No secrets in code or configuration files
  
- **Security (ac-001 v1.0.0-draft)**: 
  - Server SSH access: SSH keys only, no password authentication
  - Application RBAC: Customer, Business Owner, Admin roles with least privilege
  - MFA required for business owner and admin accounts
  - Session timeout: 24 hours for customers, 4 hours for business/admin
  - CSRF protection on all state-changing operations
  
- **Security (audit-001 v1.0.0-draft)**:
  - Audit logging for authentication events (login, logout, failed attempts)
  - Audit logging for booking transactions (create, modify, cancel)
  - Audit logging for pricing changes and patio modifications
  - Logs sent to Azure Monitor Log Analytics
  - 90-day log retention for compliance
  
- **Infrastructure (compute-001 v2.0.0)**:
  - Use Standard_B2s for dev/test environments
  - Use Standard_D2s_v3 for production web tier (approved non-critical SKU)
  - Multi-zone deployment not required for non-critical tier (cost optimization)
  
- **Infrastructure (net-001 v2.0.0)**:
  - Single-zone deployment (non-critical tier per cost baselines)
  - Standard load balancer tier
  - NSG rules: Allow 443 (HTTPS), 22 (SSH keys only), deny all else
  
- **Infrastructure (stor-001 v2.0.0)**:
  - MySQL database: Standard tier with daily backups, 7-day retention
  - Blob storage: Standard LRS for patio photos
  - No GRS replication required (non-critical tier)
  
- **Infrastructure (cicd-001 v2.0.0)**:
  - GitHub Actions CI/CD pipelines with cost validation gates
  - Automated testing before deployment
  - Approval required for production deployments (per gov-001)
  
- **Infrastructure (iac-001 v1.0.0-draft)**: 
  - Use AVM wrapper modules from `/artifacts/infrastructure/iac-modules/`
  - Required: avm-wrapper-linux-vm, avm-wrapper-vnet, avm-wrapper-nsg, avm-wrapper-storage-account, avm-wrapper-key-vault, avm-wrapper-mysql-flexibleserver
  
- **DevOps (obs-001 v1.0.0-placeholder)**: 
  - Application logging: Apache error/access logs, PHP application logs
  - Metrics: Request rate, response time, error rate, database query time
  - Tracing: Request tracing for booking flow (search → view → book → confirm)
  - SLI/SLO: 99% availability, <200ms p95 response time for search, <500ms p95 for bookings
  - Azure Application Insights integration
  
- **DevOps (env-001 v1.0.0-placeholder)**: 
  - Dev environment: Single VM, reduced dataset, weather API sandbox
  - Staging environment: Production-like, full weather API, test payment gateway
  - Production environment: Load balanced, production weather API, live payment gateway
  - Environment-specific configuration via environment variables
  - Secrets managed via Azure Key Vault per environment

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Customers can successfully create account, search patios, and complete booking in under 5 minutes
- **SC-002**: Weather forecasts display accurately for all available booking dates with <1 hour data staleness
- **SC-003**: Dynamic pricing calculates correctly with visible breakdown showing base + adjustments
- **SC-004**: System supports at least 3 cities at launch with ability to add new cities without code changes
- **SC-005**: 95% of search queries return results in under 200ms
- **SC-006**: 95% of booking transactions complete successfully without errors
- **SC-007**: Zero double-bookings occur (optimistic locking prevents conflicts)
- **SC-008**: Business owners can list new patio and configure pricing in under 10 minutes
- **SC-009**: System maintains 99% uptime during business hours (6am-midnight local time)
- **SC-010**: Infrastructure costs remain within $50-100/month budget for non-critical tier (per cost-001)
- **SC-011**: All data encrypted at rest (AES-256) and in transit (TLS 1.2+) per security requirements
- **SC-012**: Successful Azure Policy compliance scan (100% pass rate) per pac-001
- **SC-013**: All IaC modules use approved AVM wrappers per iac-001
- **SC-014**: Observability dashboards show request rate, response time, error rate metrics per obs-001
- **SC-015**: Automated deployment to dev/staging/prod completes in under 15 minutes per environment

---

## Artifact Generation & Human Review

**Generated Outputs** (AI-assisted, human-reviewed per constitution):
- IaC modules for patio application infrastructure (`/artifacts/applications/patio/iac/`)
- Deployment pipelines (`/artifacts/applications/patio/pipelines/`)
- Configuration scripts (`/artifacts/applications/patio/scripts/`)
- Documentation (`/artifacts/applications/patio/docs/`)

**Review Checklist**:
- [ ] Outputs correctly implement this spec
- [ ] Outputs align with all 21 parent tier specs (no constraint violations)
- [ ] Cost estimates match business tier budgets
- [ ] Security controls implemented (encryption, RBAC, SSH keys, audit logging)
- [ ] Infrastructure uses approved compute SKUs, networking patterns, storage tiers
- [ ] DevOps practices implemented (observability, environments, deployment automation)
- [ ] Code quality passes linting & best practices
- [ ] Artifact directory structure follows `/artifacts/applications/patio/` standard
- [ ] Traceability to source spec is documented
- [ ] Outputs are versioned & tagged with spec version

---

## Assumptions

**Business Model Assumptions**:
- Businesses pay subscription fee (not commission per booking) or commission-based model TBD
- Payment processing fees passed to customer or absorbed by business (TBD)
- Initial launch in 3 US cities (timezone: Eastern, Central, or Pacific)
- Patio capacity ranges from 10-200 people (typical bar/restaurant patios)

**Technical Assumptions**:
- Weather API provides 14-day forecasts with reasonable accuracy
- Weather API has generous rate limits or paid tier supports expected request volume
- Payment gateway (Stripe/PayPal) supports required features (deposits, refunds, splits)
- Users access via modern web browsers (Chrome, Firefox, Safari, Edge - last 2 versions)
- LAMP stack hosted on Azure Linux VMs (Ubuntu 22.04 LTS)
- MySQL 8.0+ provides required performance at expected scale
- PHP 8.1+ with Apache 2.4 meets performance requirements

**User & Scale Assumptions**:
- Initial launch: 50 businesses, 1,000 customers, 500 bookings/month
- Growth target: 200 businesses, 10,000 customers, 5,000 bookings/month within 1 year
- Peak usage: Friday-Sunday evenings (5pm-10pm local time)
- Average booking duration: 2-4 hours
- Average booking value: $100-300 (varies by patio, time, weather)
- Customer booking lead time: 3-14 days in advance (some same-day)

**Operational Assumptions**:
- Customer support team handles booking disputes and cancellations
- Business owners are responsible for patio maintenance and actual availability
- Weather data accuracy sufficient for customer decision-making (not liability for incorrect forecasts)
- Customers understand booking is subject to business's final approval/confirmation

**Data & Privacy Assumptions**:
- GDPR/CCPA compliance required (user data deletion, export capabilities)
- Data residency: US regions only per comp-001 (East US or West US 2)
- User photos uploaded by businesses are their responsibility (copyright, licensing)
- Weather data from third-party API used within API provider's terms of service

---

## Out of Scope

**Not Included in Initial Release**:
- Mobile native apps (iOS/Android) - web-only for MVP
- Real-time chat between customers and business owners
- Social features (reviews, ratings, photos from customers) - future enhancement
- Loyalty programs or reward points
- Gift cards or vouchers
- Integration with business POS systems
- Automatic calendar sync with Google Calendar/Outlook
- Multi-language support (English only initially)
- Accessibility features beyond basic WCAG 2.1 Level A compliance

**Business Features Not Included**:
- Commission-based revenue splitting (flat subscription model initially)
- Business analytics beyond basic dashboard (advanced BI is future enhancement)
- Inventory management or food/beverage ordering
- Staff scheduling or management tools
- Marketing automation or email campaigns (basic transactional emails only)

**Technical Features Not Included**:
- GraphQL API (REST only)
- Real-time WebSocket notifications (email/polling only)
- Advanced caching strategies (basic query caching only)
- Multi-region deployment (single Azure region)
- Advanced fraud detection (basic validation only)
- A/B testing framework
- Feature flagging system

**Integrations Not Included**:
- Social media login (OAuth) - email/password only
- Google Maps embedding (static maps only, or links to Google Maps)
- Event management platforms (Eventbrite, etc.)
- Accounting software integration (QuickBooks, Xero)
- Marketing platforms (Mailchimp, HubSpot)

---

## Glossary

- **AVM**: Azure Verified Modules - Microsoft-verified IaC module patterns
- **HSM**: Hardware Security Module - for cryptographic key management
- **RBAC**: Role-Based Access Control
- **SLI/SLO**: Service Level Indicator / Service Level Objective
- **TLS**: Transport Layer Security
