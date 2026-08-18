# Chef Declarative State Management (DSM)

Chef DSM acts as a central repository for configuration data, managing cookbooks, policies, and metadata for nodes managed by Chef Infra Client.

## Key Features
- Central repository for configuration data
- Stores cookbooks, policies, and metadata
- Nodes use Chef Infra Client to request configuration details
- Provides recipes, templates, and file distributions

## Benefits

### Scalability
- Kubernetes-based runtime
- Horizontal scaling by adding/removing pods
- Handles unpredictable workloads and rapid growth

### High Availability
- Self-healing capabilities
- Continuous availability even during failures

### Streamlined Updates
- Automatic updates with preflight checks
- Rollback capability for configuration changes

### Resource Optimization
- Dynamic resource allocation
- Efficient CPU, memory, and storage usage

### Portability
- Deploy across any cloud or on-premises
- Minimal changes required for different environments

### Enhanced Security
- Isolated containers reduce attack surfaces
- Granular RBAC

## Migration from Chef Infra Server
- Import existing Chef Infra Server data into Chef DSM
- Import users, organizations, and organization data
- DSM import service handles the migration

## DSM Services
- Store cookbooks and policies applied to nodes
- Store metadata describing registered nodes
- Provide recipes, templates, and file distributions
