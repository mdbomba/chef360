# Tenants and Organizational Units

## Tenants
The fundamental security boundary in Chef 360 Platform.

### Tenant Attributes
- **Fully Qualified Domain Name (FQDN)**
- **Slug**: Common name for internal service routing
- **Tenant Secret**: Initially provisions the installation

### Tenant Operations
- Create/manage tenants
- Configure tenant settings
- Manage tenant SSO (OpenID Connect, SAML)

## Organizational Units (OUs)
Internal groupings of users and node resources within a tenant.

### OU Structure
- One or more OUs per tenant
- Example: One tenant with OU per business unit

### OU Operations
- Create/manage OUs
- Assign users to OUs
- Assign nodes to OUs
- Configure OU-specific policies

## Tenant Management via Web UI
- Tenant management interface
- SSO configuration
- OpenID Connect setup
- SAML setup

## Tenant Management via CLI
```bash
# List tenants
chef-platform-auth-cli tenant list

# Create tenant
chef-platform-auth-cli tenant create --name <name> --slug <slug>

# Get tenant details
chef-platform-auth-cli tenant get --id <tenant-id>
```
