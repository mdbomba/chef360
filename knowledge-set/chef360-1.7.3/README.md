# Chef 360 Platform 1.7.3 Knowledge Set

A structured knowledge base for Chef 360 Platform 1.7.3, designed for use in building an MCP (Model Context Protocol) service.

## Source

- Documentation: https://docs.chef.io/360/1.7/
- Version: 1.7.3

## Structure

```
chef360-1.7.3/
  architecture/           # Platform architecture and services overview
  apis/                   # API endpoints and specifications
  courier/                # Chef Courier job management
  node-management/        # Node enrollment, skills, filters
  dsm/                    # Declarative State Management
  platform-services/      # Platform auth, accounts, system services
  cli/                    # CLI tools reference
  glossary/               # Terms and definitions
```

## Usage

Load any markdown file as context for an MCP service to enable Chef 360 Platform operations including:
- Node management (enrollment, skills, filters, tags)
- Courier job scheduling and execution
- DSM cookbook/policy management
- Platform administration (users, roles, policies)
- API interactions
