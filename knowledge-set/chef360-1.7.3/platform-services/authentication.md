# Platform Authentication and Authorization

## Authentication Methods

### OAuth (External Identity Providers)
- Azure Active Directory
- Other OAuth providers
- SAML identity providers
- OpenID Connect identity providers

### Local Users
- Users created directly in Chef Platform
- Password management via platform

## API Token Management

### Token Structure
- Requesting user
- Organizational unit (OU)
- Tenant
- Signature based on caller's secret

### Token Operations
- Generate API tokens
- Revoke API tokens
- Rotate API keys

### Token Usage
```
Authorization: Bearer <API_TOKEN>
```

## Authorization (RBAC)

### Roles
- Assigned to users, OUs, or agents
- Map to one or more policies
- Can be enabled/disabled per OU or user

### System Roles
- **Tenant Admin**: Tenant management
- **Organization Admin**: Organization management
- **Node Manager**: Node management
- **Courier Operator**: Courier operations

### Custom Roles
- Create roles based on business needs
- Reference system roles as templates

### Policies
- Define specific API endpoint permissions
- Not attribute-dependent
- Enable service endpoints for all accessible data values

## User Management
- Assign users to tenants and OUs
- Manage passwords
- Enable/disable users
- Send one-time passcodes for account reset
- Add roles to users
