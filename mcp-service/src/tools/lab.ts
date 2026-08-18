import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import {
  getWorkstationVersions,
  inspectMachine,
  labMachines,
  type MachineName,
} from "../lib/lab.js";

const machineNames = Object.keys(labMachines) as [MachineName, ...MachineName[]];

export function registerLabTools(server: McpServer): void {
  server.tool(
    "list_lab_machines",
    "List the allowlisted KVM machines in the local Chef lab",
    {},
    async () => ({
      content: [
        { type: "text", text: JSON.stringify(labMachines, null, 2) },
      ],
    }),
  );

  server.tool(
    "inspect_lab_machine",
    "Get libvirt state and known service-port reachability for a lab machine",
    { machine: z.enum(machineNames) },
    async ({ machine }) => ({
      content: [
        {
          type: "text",
          text: JSON.stringify(await inspectMachine(machine), null, 2),
        },
      ],
    }),
  );

  server.tool(
    "chef_workstation_versions",
    "Report Chef Workstation component versions installed on the MCP host",
    {},
    async () => ({
      content: [{ type: "text", text: await getWorkstationVersions() }],
    }),
  );
}
