# IaC Subdirectory

**Purpose**: Infrastructure-as-Code files (Bicep, ARM templates, Terraform)  
**Naming Convention**: `<appname>-<component>.bicep`  
**Examples**:
- `payment-service-function-app.bicep`
- `payment-service-database.bicep`
- `payment-service-storage.bicep`

## Guidelines

1. **One component per file**: Separate concerns (Function App, Database, Storage, etc.)
2. **Parameterized designs**: Use parameters for environment-specific values
3. **Modular approach**: Reference shared modules from `../modules/`
4. **Documentation**: Include inline comments explaining complex configurations
5. **Cost-aware**: Follow `/specs/platform/001-application-artifact-organization/` constraints

## Example Structure

```
iac/
├── main.bicep                          # Root template (orchestrates components)
├── parameters.json                     # Default parameters
├── payment-service-function-app.bicep  # Function App component
├── payment-service-database.bicep      # Database component
└── payment-service-storage.bicep       # Storage component
```

## Deployment

From `/artifacts/applications/<appname>/`:

```powershell
# Validate
az deployment group validate \
  --resource-group myResourceGroup \
  --template-file iac/main.bicep \
  --parameters iac/parameters.json

# Deploy
az deployment group create \
  --resource-group myResourceGroup \
  --template-file iac/main.bicep \
  --parameters iac/parameters.json
```

## See Also

- **Parent Directory**: [`../README.md`](../README.md) - Template overview
- **Related**: [`../modules/`](../modules/) - Reusable modules
- **Specification**: `/specs/platform/001-application-artifact-organization/spec.md`

---

**Created**: 2026-02-05  
**Version**: v1.0.0