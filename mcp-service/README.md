# Chef 360 MCP Service

TypeScript MCP service backed by the Chef 360 Platform knowledge set.

## Structure

```text
mcp-service/
  src/
    lib/       Knowledge access and other reusable integrations
    tools/     MCP tool registrations
    config.ts  Environment configuration
    server.ts  MCP server composition
    index.ts   Stdio transport entry point
  tests/
```

## Run locally

```bash
npm install
npm run build
npm start
```

For the Streamable HTTP transport used by hosted clients:

```bash
npm run dev:http
```

The MCP endpoint is `POST /mcp`; Azure health probes can use `GET /health`.

The default knowledge path is `../knowledge-set/chef360-1.7.3`. Override it with
the `KNOWLEDGE_PATH` environment variable.

The stdio transport is intended for local MCP clients. Both transports use the
same `createServer()` function and tool registrations.

## Lab Tools

The service includes these read-only tools for the local KVM Chef lab:

- `list_lab_machines`: returns the fixed Chef360, Automate, and managed-node inventory.
- `inspect_lab_machine`: returns libvirt power state and known service-port reachability.
- `chef_workstation_versions`: returns Chef component versions installed on the host.
- `search_knowledge`: searches Chef360 documentation and local lab topology.

Run the service directly on `fury.demo.lab` to use the libvirt and Chef
Workstation tools. The service account must be able to run `virsh` against the
system libvirt connection and execute `chef --version`. No credentials, API
tokens, or SSH keys are stored by the service.

An Azure-hosted instance can still search the bundled knowledge set. It cannot
inspect local KVM guests unless Azure has private connectivity to this lab and
the service is redesigned to use a secured remote management interface; the
local libvirt socket is not included in the container.

## Container

Build from the repository root so the image includes the knowledge set:

```bash
docker build -f mcp-service/Dockerfile -t chef360-mcp .
docker run --rm -p 3000:3000 chef360-mcp
```

The repository-level `azure.yaml` configures this container for Azure Developer
CLI and Azure Container Apps. Run `azd up` from the repository root after
installing and signing in to Azure Developer CLI.
