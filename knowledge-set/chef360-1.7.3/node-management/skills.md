# Skills

Skills are agents installed on nodes that perform specific actions for a desired outcome.

## Skill Types
- **Canister-based skills**: Packaged as containers
- **Non-canister-based skills**: Traditional agents

## Built-in Skills
- **Chef Infra Client**: Configuration management
- **Chef InSpec**: Compliance scanning
- **Chef Courier Runner**: Job execution
- **Node Management Agent**: Platform communication
- **Gohai**: System information collection

## Custom Skills
User-defined skills for custom use cases.

## Skill Management

### Define Skills
Skills must be defined in Chef 360 Platform Server before deployment.

### Skill Assembly
A skill assembly groups skills for deployment to nodes.
- Create and manage skill assemblies
- Update assemblies to add/remove skills

### Override Settings
Configure skill-specific settings:
- **Courier Runner**: Job execution settings
- **Gohai**: System information collection settings

### Skill Lifecycle Hooks
Run custom scripts on nodes at specific points:
- Pre-install / Post-install
- Pre-update / Post-update
- Pre-delete / Post-delete
