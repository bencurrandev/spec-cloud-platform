# Scripts Subdirectory

**Purpose**: Deployment, validation, and operations scripts  
**Naming Convention**: `<appname>-<purpose>.<ext>`  
**Languages**: PowerShell (.ps1), Python (.py), Bash (.sh)  
**Examples**:
- `payment-service-deploy.ps1` - Deployment automation
- `payment-service-validate.py` - Validation checks
- `payment-service-rollback.ps1` - Rollback automation

## Guidelines

1. **Single responsibility**: One script per purpose
2. **Error handling**: Comprehensive error messages and logging
3. **Idempotency**: Safe to run multiple times
4. **Documentation**: Clear usage instructions in header comments
5. **Parameterized**: Accept environment/configuration parameters

## Script Types

### Deployment Scripts
- Deploy infrastructure
- Setup databases
- Configure applications
- Initialize services

### Validation Scripts
- Check deployments
- Verify configurations
- Run policy validation
- Test connectivity

### Operations Scripts
- Rollback changes
- Monitor health
- Perform maintenance
- Generate reports

## Example Script

```powershell
<#
  .SYNOPSIS
    Deploys payment service infrastructure
  .DESCRIPTION
    Deploys the payment service with all required Azure resources
  .PARAMETER ResourceGroup
    Target resource group name
  .PARAMETER Environment
    Deployment environment (dev/staging/prod)
  .EXAMPLE
    ./payment-service-deploy.ps1 -ResourceGroup "my-rg" -Environment "prod"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# ... script implementation
```

## See Also

- **Parent Directory**: [`../README.md`](../README.md) - Template overview
- **Related**: [`../iac/`](../iac/) - Infrastructure files this script deploys
- **Specification**: `/specs/platform/001-application-artifact-organization/spec.md`

---

**Created**: 2026-02-05  
**Version**: v1.0.0