# Docs Subdirectory

**Purpose**: Documentation, runbooks, architecture diagrams, configuration guides  
**Naming Convention**: Clear, descriptive titles  
**Examples**:
- `README.md` - Application overview (REQUIRED)
- `ARCHITECTURE.md` - Architecture diagrams and explanations
- `RUNBOOK.md` - Operations runbook
- `DEPLOYMENT.md` - Deployment guide

## Guidelines

1. **Start with README.md**: Required, application overview
2. **Clear structure**: Use headers, bullet points, code examples
3. **Audience-aware**: Different docs for different roles
4. **Link to specs**: Reference parent specs in documentation
5. **Keep updated**: Review with each major change

## Required Files

### README.md (REQUIRED)

```markdown
# Application: payment-service

**Source Spec**: /specs/application/payment-service/spec.md  
**Parent Specs**: 
- /specs/business/001-cost-reduction-targets/
- /specs/security/001-cost-constrained-policies/
- /specs/infrastructure/001-cost-optimized-compute-modules/

## Overview

[Brief description of the application]

## Key Components

- Function App (compute)
- Database (storage)
- Storage Account (state)

## How to Deploy

See [DEPLOYMENT.md](DEPLOYMENT.md)

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md)

## Operations

See [RUNBOOK.md](RUNBOOK.md)
```

## Additional Documentation

### ARCHITECTURE.md
- System architecture diagram
- Component relationships
- Data flow
- Security boundaries

### DEPLOYMENT.md
- Prerequisites
- Step-by-step deployment instructions
- Configuration steps
- Verification steps

### RUNBOOK.md
- Common operations
- Troubleshooting
- Monitoring
- Escalation procedures

### CONFIGURATION.md (Optional)
- Configuration parameters
- Environment-specific settings
- How to customize for your needs

## Directory Structure

```
docs/
├── README.md                 # Application overview (REQUIRED)
├── ARCHITECTURE.md           # Architecture documentation
├── DEPLOYMENT.md             # Deployment guide
├── RUNBOOK.md                # Operations runbook
└── CONFIGURATION.md          # Configuration guide (optional)
```

## Markdown Tips

- Use `# ` for main headings, `## ` for sections
- Link to other docs: `[DEPLOYMENT.md](DEPLOYMENT.md)`
- Link to code: `[main.bicep](../iac/main.bicep)`
- Use code blocks with language: `` ``` bicep ``
- Use tables for structured information

## See Also

- **Parent Directory**: [`../README.md`](../README.md) - Template overview
- **Specification**: `/specs/platform/001-application-artifact-organization/spec.md`

---

**Created**: 2026-02-05  
**Version**: v1.0.0