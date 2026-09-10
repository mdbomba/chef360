# Chef 360 Platform 1.7.3 Knowledge Set

A curated, versioned knowledge base for answering questions and retrieving
operational guidance about Chef 360 Platform 1.7.3. MCP services search this
content and return bounded excerpts or document pages; they do not perform the
administrative operations described by the documents.

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
  automate/               # Chef Automate visibility and reporting
  inspec/                 # Chef InSpec compliance-as-code
  workstation/            # Chef Workstation tools and workflows
  operations/             # Installation, infrastructure, and operational prerequisites
  examples/               # Version-specific configuration examples
  lab/                    # Local lab topology and inventory guidance
  glossary/               # Terms and definitions
```

## Usage

Load any markdown file as context for an MCP service to enable Chef 360 Platform operations including:
- Node management (enrollment, skills, filters, tags)
- Courier job scheduling and execution
- DSM cookbook/policy management
- Platform administration (users, roles, policies)
- Chef Automate architecture, APIs, data flow, and operations
- Chef InSpec profiles, controls, execution, and result handling
- Chef Workstation tools, configuration, and development workflows
- Provider-neutral infrastructure requirements and automation boundaries
- Chef 360 command-line installation with version-specific ConfigValues
- AWS, Azure, KVM, Hyper-V, and Proxmox guest realization guidance
- Reviewed KVM autoinstall, checkpoint deployment, and troubleshooting workflow
- API interactions

These are topics and documented workflows, not executable MCP permissions. Each
MCP implementation advertises its actual tools at runtime and omits optional
capabilities whose backing source or host command is unavailable.
