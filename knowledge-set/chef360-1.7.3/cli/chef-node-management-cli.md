# chef-node-management-cli Reference

Manages nodes, node groups, skills, and skill assemblies.

## Node Management

### List Nodes
```bash
chef-node-management-cli node list
chef-node-management-cli node list --filter "tags.environment = 'production'"
```

### Get Node Details
```bash
chef-node-management-cli node get --id <node-id>
```

### Update Node
```bash
chef-node-management-cli node update --id <node-id> --attributes '{"custom_attr": "value"}'
```

### Archive Node
```bash
chef-node-management-cli node archive --id <node-id>
```

### Unarchive Node
```bash
chef-node-management-cli node unarchive --id <node-id>
```

## Node Groups

### List Node Groups
```bash
chef-node-management-cli group list
```

### Create Node Group
```bash
chef-node-management-cli group create --name "production-servers" --filter "tags.environment = 'production'"
```

### Delete Node Group
```bash
chef-node-management-cli group delete --id <group-id>
```

## Skills

### List Skills
```bash
chef-node-management-cli skill list
```

### Create Skill
```bash
chef-node-management-cli skill create --name "my-skill" --type canister --image "my-skill:latest"
```

### Delete Skill
```bash
chef-node-management-cli skill delete --id <skill-id>
```

## Skill Assemblies

### List Skill Assemblies
```bash
chef-node-management-cli assembly list
```

### Create Skill Assembly
```bash
chef-node-management-cli assembly create --name "standard-assembly" --skills '["chef-infra-client", "courier-runner"]'
```

### Update Skill Assembly
```bash
chef-node-management-cli assembly update --id <assembly-id> --skills '["chef-infra-client", "courier-runner", "custom-skill"]'
```

## Node Filters

### List Filters
```bash
chef-node-management-cli filter list
```

### Create Filter
```bash
chef-node-management-cli filter create --name "linux-production" --expression "ohai.platform_family = 'debian' AND tags.environment = 'production'"
```

## Node Tags

### Add Tag
```bash
chef-node-management-cli tag add --node-id <node-id> --tag "department:engineering"
```

### Remove Tag
```bash
chef-node-management-cli tag remove --node-id <node-id> --tag "department:engineering"
```

### List Tags
```bash
chef-node-management-cli tag list --node-id <node-id>
```
