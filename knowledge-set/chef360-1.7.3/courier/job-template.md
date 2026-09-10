# Courier Job Template

## Format
Jobs are defined as JSON, YAML, or TOML documents.

## Structure

### JSON Example
```json
{
  "name": "job-name",
  "description": "Job description",
  "schedule": {
    "type": "immediate|scheduled|cron",
    "cron": "0 0 * * *",
    "start_time": "2024-01-01T00:00:00Z"
  },
  "nodes": {
    "filter": "node_filter_expression",
    "list": ["node-id-1", "node-id-2"]
  },
  "steps": [
    {
      "interpreter": "shell|infra_client|inspec|ansible|restart",
      "timeout": 300,
      "retry_count": 3,
      "payload": {
        "command": "echo hello",
        "inline_recipe": "...",
        "profile": "...",
        "playbook": "..."
      }
    }
  ],
  "error_compensation": {
    "on_failure": "continue|stop",
    "compensation_step": {}
  }
}
```

### Key Fields

#### Schedule Types
- `immediate`: Run as soon as possible
- `scheduled`: Run at a specific future time
- `cron`: Run on a cron schedule

#### Node Targeting
- `filter`: SQL-like expression to match nodes
- `list`: Explicit list of node IDs

#### Step Configuration
- `interpreter`: Type of execution (shell, infra_client, inspec, ansible, restart)
- `timeout`: Maximum execution time in seconds
- `retry_count`: Number of retry attempts on failure
- `payload`: Interpreter-specific configuration

#### Interpreter Payloads

**Shell Interpreter:**
```json
{
  "command": "ls -la /etc",
  "working_directory": "/tmp",
  "environment": {"KEY": "VALUE"}
}
```

**Infra Client Interpreter:**
```json
{
  "inline_recipe": "package 'nginx' do\n  action :install\nend",
  "run_list": ["recipe[mycookbook]"],
  "policy_name": "my-policy",
  "policy_group": "production"
}
```

**InSpec Interpreter:**
```json
{
  "profile": "path/to/profile",
  "profile_url": "https://github.com/org/profile",
  "attributes": {},
  "reporter": "cli"
}
```

**Ansible Interpreter:**
```json
{
  "playbook": "playbook.yml",
  "inventory": "inventory.ini",
  "extra_vars": {"key": "value"}
}
```
