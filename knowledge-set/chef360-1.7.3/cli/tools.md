# Chef 360 Platform CLI Tools

## Available CLIs

### chef-courier-cli
Schedules, executes, and monitors jobs on nodes.

### chef-dsm-cli
Registers and manages nodes within Chef DSM.

### chef-import-cli
Manages data import processes into Chef 360 Platform.

### chef-node-enrollment-cli
Provides commands for nodes to self-enroll with Chef 360 Platform.

### chef-node-management-cli
Manages nodes, node groups, skills, and skill assemblies.

### chef-platform-auth-cli
Manages users, node accounts, authentication, authorization, roles, licenses, and system settings.

### knife
Chef Infra Server management tool with extensions:
- **knife ec backup**: Backup operations
- **knife tidy**: Cleanup operations

## Common CLI Patterns

### Authentication
All CLIs require authentication credentials:
```bash
# Using API token
export CHEF_ORG=<organization>
export CHEF_TOKEN=<api-token>
export CHEF_SERVER_URL=<server-url>

# Or using config file
chef-node-management-cli --config ~/.chef/config.rb
```

### Output Formats
- JSON (default)
- Table
- YAML

### Common Flags
```
--config <path>       Configuration file path
--format <format>     Output format (json, table, yaml)
--no-color            Disable colored output
--verbose             Enable verbose output
```
