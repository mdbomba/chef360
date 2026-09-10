# chef-platform-auth-cli Reference

Manages users, node accounts, authentication, authorization, roles, licenses, and system settings.

## User Management

### List Users
```bash
chef-platform-auth-cli user list
```

### Create User
```bash
chef-platform-auth-cli user create --username "john.doe" --email "john@example.com" --tenant-id <tenant-id> --ou-id <ou-id>
```

### Get User Details
```bash
chef-platform-auth-cli user get --username <username>
```

### Enable/Disable User
```bash
chef-platform-auth-cli user enable --username <username>
chef-platform-auth-cli user disable --username <username>
```

### Delete User
```bash
chef-platform-auth-cli user delete --username <username>
```

## API Token Management

### Generate Token
```bash
chef-platform-auth-cli token generate --username <username> --description "CI/CD Token"
```

### List Tokens
```bash
chef-platform-auth-cli token list --username <username>
```

### Revoke Token
```bash
chef-platform-auth-cli token revoke --token-id <token-id>
```

## Role Management

### List Roles
```bash
chef-platform-auth-cli role list
```

### Create Role
```bash
chef-platform-auth-cli role create --name "custom-role" --policies '["courier:create_job", "node_management:view_nodes"]'
```

### Assign Role
```bash
chef-platform-auth-cli role assign --role <role-name> --user <username>
```

### Remove Role
```bash
chef-platform-auth-cli role remove --role <role-name> --user <username>
```

## Node Account Management

### List Node Accounts
```bash
chef-platform-auth-cli node-account list
```

### Create Node Account
```bash
chef-platform-auth-cli node-account create --name "web-server-01" --ou-id <ou-id>
```

## Tenant Management

### List Tenants
```bash
chef-platform-auth-cli tenant list
```

### Create Tenant
```bash
chef-platform-auth-cli tenant create --name "my-org" --slug "myorg" --fqdn "myorg.example.com"
```

## License Management

### View License
```bash
chef-platform-auth-cli license view
```

### Add License
```bash
chef-platform-auth-cli license add --key <license-key>
```

## System Settings

### Get System Settings
```bash
chef-platform-auth-cli system get
```

### Update System Settings
```bash
chef-platform-auth-cli system update --smtp-host "smtp.example.com" --smtp-port 587
```
