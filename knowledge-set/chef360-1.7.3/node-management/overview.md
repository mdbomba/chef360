# Chef Node Management Overview

Chef Node Management enrolls nodes into Chef 360 Platform, makes nodes visible in a node fleet, manages skills installed on nodes, and groups nodes using filters or lists.

## What's a Node?
A node is a resource (physical or virtual) accessible over a network.
- Uniquely identified by node ID
- Has basic attributes extended with custom named key/value pairs
- Attributes describe properties or current state

## Features

### Archive Nodes
Remove nodes from active management while preserving data for historical reference.
- Archived nodes auto-unarchive when they check in.

### Default Node Management Settings
New organizations can be configured with default:
- Node cohort
- Node Management agent settings
- Skill assembly
- Override settings

### Node Attributes
- Filter, group, sort, or search for nodes
- Reserved namespaces for integration
- User-defined custom namespaces

### Node Enrollment
Brings nodes under Chef 360 Platform management.

### Node Filters
SQL-like search expressions to identify node sets.
- Match based on namespace and attribute patterns
- Include/exclude nodes based on specific pattern sets

### Node Lists
User-created and managed static lists of nodes.

### Skills
Agents that perform actions on nodes for specific outcomes.
- **Canister-based skills** or **non-canister-based skills**
- Chef-owned: Chef Infra, Chef InSpec, Chef Courier
- Custom user-defined skills
- Defined in Chef 360 Platform Server
- Added to nodes via skill assemblies
- Configured via override settings
- Lifecycle hooks for install/update/delete operations

### Tags
User-provided custom attributes for grouping nodes.
- Categories: department, cost center code, store name, etc.
- Stored under the `tags` namespace
