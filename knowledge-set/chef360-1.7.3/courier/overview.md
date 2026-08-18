# Chef Courier

Chef Courier executes actions on any set or subset of nodes at any time or time interval.

## Integration
- Integrates with existing scripts, commands, and tools
- Orchestrates workflows across Chef tools, automation platforms, custom scripts, and APIs
- Triggers from: Web UI, API, CLI, or schedule
- Role-based and attribute-based access control for task delegation

## Job Components

### Job Definition Template
- Fundamental specification of a Courier job
- Format: JSON, YAML, or TOML file/string
- Contains details of a single Courier job

### Job Identifier
- Unique UUID/GUID assigned at creation
- Used for lookups, tracking, and future requests

### Job Instance
- Single occurrence of a job
- Multiple instances per job, executed across multiple nodes/actions

### Job Run
- Assigned job instance for a specific node
- Every node in the job definition has a job run per instance

### Job Action
- Workloads with corresponding payloads executed during a job run
- Multiple actions per job run

### Job Step
- Individual command executed for an action of a job run

## Courier Services

### Courier Dispatcher
- Central service that sends job definitions to nodes
- Maintains all information regarding job runs

### Courier Runner
- Runs on each node
- Interprets and executes job definitions sent by the dispatcher

### Interpreters
- Individual services invoked by the Runner for each step type
- Every skill has a corresponding interpreter

## Available Interpreters
- **Ansible**: Execute Ansible playbooks
- **Infra Client**: Run Chef Infra Client
- **Chef InSpec**: Execute InSpec profiles
- **Restart**: Restart node services
- **Shell**: Execute shell commands

## Job Scheduling
- Immediate execution or future scheduling
- Schedule exceptions (blackout windows) supported
- Cron-based scheduling available

## Key Concepts
- Jobs are written as JSON documents
- Zero-trust: agents pull from channels, services don't push
- Archived nodes are excluded from job execution
