# Chef 360 Platform APIs

## API Categories

### Chef Courier APIs
- **Courier Delivery Service**: Submit sub-jobs to nodes, create channels/queues
- **Courier Orchestrator**: Job orchestration and step distribution
- **Courier Scheduler**: Create/cancel/list jobs, manage exceptions
- **Courier State Service**: Job state management, status reporting, results retrieval
- **Courier Watchdog**: Job monitoring and retry

### Chef DSM APIs
- **DSM**: Cookbook, policy, and metadata management
- **DSM Manage**: DSM administration operations

### Chef Node Management APIs
- **Node Enrollment**: Node registration and enrollment status
- **Node Management**: Node attributes, tags, skills, filters management

### Chef Platform APIs
- **Platform Accounts**: User account management
- **Platform Authz**: Authorization and policy management
- **Platform Experience**: UI experience configuration
- **Platform Node Accounts**: Node account management
- **Platform Notification**: Notification management
- **Platform Secret**: Secrets management
- **Platform System**: System and tenant management
- **Platform User Accounts**: User management and authentication

## Authentication
- API tokens required for all requests
- Tokens contain user, OU, tenant, and signature
- Generated via `chef-platform-auth-cli` or web UI

## Common Headers
```
Authorization: Bearer <API_TOKEN>
Content-Type: application/json
```
