# Pipelines Subdirectory

**Purpose**: CI/CD pipeline definitions and GitHub Actions workflows  
**Naming Convention**: `<purpose>.yml`  
**Examples**:
- `deploy-infrastructure.yml` - Main deployment workflow
- `validate-policy.yml` - Policy compliance validation
- `run-tests.yml` - Automated testing

## Guidelines

1. **Descriptive names**: Clear purpose from filename
2. **Modular workflows**: Reusable jobs and steps
3. **Environment-aware**: Different steps for dev/staging/prod
4. **Documented**: Comments explaining complex logic
5. **Secure**: Never hardcode secrets, use GitHub secrets

## GitHub Actions Workflow Structure

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [ main ]
    paths:
      - 'artifacts/applications/payment-service/iac/**'
  workflow_dispatch:

env:
  APP_NAME: payment-service
  ARTIFACT_PATH: artifacts/applications/${{ env.APP_NAME }}

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate structure
        run: |
          ./artifacts/.templates/scripts/validate-artifact-structure.ps1 \
            -AppName ${{ env.APP_NAME }}

  deploy:
    needs: validate
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Azure
        run: |
          az deployment group create \
            --resource-group ${{ env.APP_NAME }}-rg \
            --template-file ${{ env.ARTIFACT_PATH }}/iac/main.bicep
```

## Workflow Types

### Deployment Workflows
- Validate IaC
- Deploy to Azure
- Run smoke tests
- Notify teams

### Validation Workflows
- Policy compliance checks
- Cost validation
- Security scanning
- Architecture validation

### Testing Workflows
- Unit tests
- Integration tests
- Performance tests
- Compliance tests

## See Also

- **Parent Directory**: [`../README.md`](../README.md) - Template overview
- **Related**: [`../scripts/`](../scripts/) - Scripts triggered by pipelines
- **Specification**: `/specs/platform/001-application-artifact-organization/spec.md`

---

**Created**: 2026-02-05  
**Version**: v1.0.0