# Access Control

Chef 360 Platform uses role-based access control (RBAC) and attribute-based access control (ABAC) for authorization.

## Authorization Model

### Roles
- Assigned to users, organizational units (OUs), or agents.
- A role maps to one or more specific policies.
- Roles can be enabled/disabled across the OU or with individual users.

### Policies
- Define specific permissions for API endpoints.
- Not attribute-dependent (RBAC, not ABAC).
- A policy applied to a user in a specific tenant enables service endpoints for all data values the user has OU access to.

### System-Defined Roles (v1.1+)
- **Tenant Admin**: Tenant management operations
- **Organization Admin**: Organization management operations
- **Node Manager**: Node management operations
- **Courier Operator**: Courier-specific actions

### Example Roles
- **Operator role**: Allows creating jobs in Courier
- **Node Management agent role**: Allows periodic check-ins and skill updates

## API Gateway Authentication
- Requests validated with API token containing:
  - Requesting user
  - Organizational unit
  - Tenant
  - Signature based on caller's secret
- Token validated against required policies for the endpoint.

## Multi-Tenancy
- Tenant is the fundamental security boundary.
- Each tenant has special attributes: FQDN, slug, tenant secret.
- Tenants contain one or more organizational units.
