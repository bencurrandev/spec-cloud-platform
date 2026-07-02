# Modules Subdirectory

**Purpose**: Reusable IaC modules shared across application components  
**Naming Convention**: `<modulename>.bicep`  
**Examples**:
- `app-insights-monitoring.bicep`
- `storage-with-encryption.bicep`
- `private-endpoint-setup.bicep`

## Guidelines

1. **Reusable patterns**: Design for multiple components to consume
2. **Well-parameterized**: Accept all necessary parameters
3. **Documented**: Clear parameter descriptions and examples
4. **Tested**: Include example usage
5. **Versioned**: Track module versions if using multiple versions

## Example Usage in IaC

```bicep
// main.bicep
module appInsights 'modules/app-insights-monitoring.bicep' = {
  name: 'appInsights'
  params: {
    name: 'my-app-insights'
    location: location
    workspaceId: logWorkspace.id
  }
}
```

## Directory Structure

```
modules/
├── app-insights-monitoring.bicep
├── storage-with-encryption.bicep
└── private-endpoint-setup.bicep
```

## See Also

- **Parent Directory**: [`../README.md`](../README.md) - Template overview
- **Uses In**: [`../iac/`](../iac/) - Infrastructure templates
- **Specification**: `/specs/platform/001-application-artifact-organization/spec.md`

---

**Created**: 2026-02-05  
**Version**: v1.0.0