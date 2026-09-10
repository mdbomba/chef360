# Node Filters and Tags

## Node Filters
A node filter is a search expression used to identify a set of nodes.

### Filter Expression Syntax
SQL-like expressions on namespaces and attributes.

### Examples
```
# Nodes with specific attribute value
tags.environment = "production"

# Nodes with attribute in range
ohai.cpu.total > 4

# Complex expressions
(tags.department = "engineering" AND ohai.os = "linux") OR tags.critical = "true"

# Exclude nodes
NOT tags.archived = "true"
```

### Use Cases
- Target nodes for Courier jobs
- Create dynamic node groups
- Automate node management actions

## Node Lists
User-created and managed static lists of nodes.
- Manually curated
- For groups that don't change frequently
- Can be used as job targets

## Tags
User-provided custom attributes for grouping nodes.

### Tag Namespace
Tags stored under the `tags` namespace.

### Examples
```
tags.department = "engineering"
tags.cost_center = "CC-1234"
tags.store_name = "Store-001"
tags.environment = "production"
tags.critical = "true"
```

### Use Cases
- Organize nodes by business requirements
- Department, cost center, location grouping
- Priority classification
- Environment designation
