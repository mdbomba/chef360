# Chef 360 Platform Service Overview

Chef 360 Platform is an integrated set of server services that provide DevSecOps, fleet management, job management, and other supporting services.

## Core Service Areas

### 1. Fleet Management (Node Management)
Manages nodes within the customer's IT environment, including public clouds and on-premises data centers.

### 2. Job Management (Chef Courier)
Plans ad-hoc or scheduled operations executed across nodes with the Courier agent and specific skills installed.

### 3. Declarative State Management (Chef DSM)
Infrastructure management bringing Chef's configuration management to Chef 360 Platform with enterprise-scale performance.

### 4. Supporting Services (Chef Platform Services)
Identity management, API routing gateway, secrets management, and integrations.

### 5. Web Application (Chef 360 Platform UI)
OU management, role management, password settings, and CLI device registration.

## Service Components

### Node Management Services
- **Node Management Service**: Manages nodes and node groups; provides endpoints for node identifiers, enrollment statuses, attributes, tags, installed skills, skill settings, check-ins, and node certificates.
- **Node Enrollment Service**: Enrolls new nodes, retrieves/updates enrollment status.

### Chef Courier Services (6 services)
- **Courier Scheduler**: Create/cancel/list jobs, manage schedule exceptions (blackout windows).
- **Courier Scheduler Worker**: Watches for new jobs, parses specifications, pushes to Orchestrator.
- **Courier Orchestrator Worker**: Accepts immediate jobs, validates steps/nodes, breaks jobs into discrete steps, sends to Delivery.
- **Courier Delivery**: Submits sub-jobs to nodes via message queues (zero-trust: agents pull, not push).
- **Courier State**: Manages persistent job state, lists steps/attributes, reports statuses, retrieves results.
- **Courier Orchestration Sentry**: Watches Orchestrator Workers, retries failed jobs.

### Chef DSM Services
- Stores cookbooks, Policyfiles, and node metadata.
- Nodes retrieve recipes, templates, and file distributions from DSM.

### Chef Platform Services
- **API Gateway**: Validates requests with API tokens (user, OU, tenant, signature).
- **Authorization Service**: Manages roles and policies (RBAC) for API gateway callers.
- **User Account Service**: User management, authentication (OAuth/local), API token management.
- **Node Account Service**: Node registration, role mapping, credential rotation.
- **System Management Service**: Tenants and organizational units (OUs).
- **Notifications Service**: Email integrations, SMTP gateway, message sending.

### Licensing Services
- License Management, License Proxy, License Consumption Collector, License Consumption Auditor, License Usage.

## Deployment Options
- **Bring Your Own Kubernetes (BYOK)**: Internet-connected or air-gapped clusters.
- **Implicit Kubernetes**: Managed Kubernetes with capacity planning, networking, runtime configuration.

## Key Concepts
- **Tenant**: Fundamental security boundary; one or more OUs.
- **Organizational Unit (OU)**: Internal grouping of users and node resources.
- **Skills**: Agents installed on nodes for specific outcomes (Chef Infra, Chef InSpec, Chef Courier, custom).
- **Job**: Fundamental unit of work with timing, steps, skills, nodes, and error compensations.
- **Node**: Physical or virtual resource accessible over a network.
