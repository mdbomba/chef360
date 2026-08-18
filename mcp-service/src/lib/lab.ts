import { execFile } from "node:child_process";
import net from "node:net";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export const labMachines = {
  chef360: {
    domain: "20_chef360",
    ip: "10.0.0.20",
    role: "Chef 360 Platform",
    servicePort: 31000,
  },
  automate: {
    domain: "21_automate",
    ip: "10.0.0.21",
    role: "Chef Automate",
    servicePort: 443,
  },
  node1: {
    domain: "31_node1",
    ip: "10.0.0.31",
    role: "Managed node 1",
    servicePort: 22,
  },
  node2: {
    domain: "32_node2",
    ip: "10.0.0.32",
    role: "Managed node 2",
    servicePort: 22,
  },
} as const;

export type MachineName = keyof typeof labMachines;

export async function getVmState(domain: string): Promise<string> {
  const { stdout } = await execFileAsync("virsh", ["domstate", domain]);
  return stdout.trim();
}

export async function getWorkstationVersions(): Promise<string> {
  const { stdout } = await execFileAsync("chef", ["--version"]);
  return stdout.trim();
}

export function checkTcpPort(
  host: string,
  port: number,
  timeoutMs = 2000,
): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host, port });
    const finish = (reachable: boolean) => {
      socket.destroy();
      resolve(reachable);
    };

    socket.setTimeout(timeoutMs);
    socket.once("connect", () => finish(true));
    socket.once("error", () => finish(false));
    socket.once("timeout", () => finish(false));
  });
}

export async function inspectMachine(name: MachineName) {
  const machine = labMachines[name];
  const [vmState, serviceReachable] = await Promise.all([
    getVmState(machine.domain),
    checkTcpPort(machine.ip, machine.servicePort),
  ]);

  return { name, ...machine, vmState, serviceReachable };
}
