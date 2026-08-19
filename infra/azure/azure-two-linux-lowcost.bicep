targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Prefix used for resource names.')
param namePrefix string = 'sa-linux'

@description('Number of Linux VMs to create.')
@minValue(2)
@maxValue(2)
param vmCount int = 2

@description('Admin username for Linux VMs.')
param adminUsername string = 'chef'

@description('SSH public key for Linux VMs.')
param sshPublicKey string

@description('VM size. Standard_B1s is generally one of the lowest cost general-purpose sizes.')
param vmSize string = 'Standard_B1s'

@description('Use Spot VMs for lowest cost. Suitable for non-production/interruptible workloads.')
param useSpot bool = true

@description('Maximum price for Spot VMs in USD/hour. -1 means pay up to on-demand price.')
param spotMaxPrice int = -1

@description('Enable public IPs on VMs. Keeping this false lowers cost and reduces exposure.')
param createPublicIp bool = false

@description('CIDR allowed to SSH (22) when createPublicIp=true.')
param sshSourceCidr string = '*'

@description('Address space for the VNet.')
param vnetAddressPrefix string = '10.42.0.0/16'

@description('Address space for the VM subnet.')
param subnetAddressPrefix string = '10.42.1.0/24'

@description('First usable subnet host offset assigned to the VMs. Node addresses increment from this value.')
@minValue(4)
param privateIpHostOffset int = 4

@description('Progress tag: X-Customer')
param xCustomer string

@description('Progress tag: X-Project')
param xProject string

@description('Progress tag: X-Application')
param xApplication string

@description('Progress tag: X-Dept')
param xDept string

@description('Progress tag: X-Name')
param xName string

@description('Progress tag: X-Contact')
param xContact string

@description('Progress tag: X-TTL (hours)')
param xTTL string

@description('Progress tag: application')
param application string

@description('Progress tag: team')
param team string

@description('Progress tag: owner')
param owner string

@description('Progress tag: expiration (YYYY-MM-DD)')
param expiration string = dateTimeAdd(utcNow(), 'P2D', 'yyyy-MM-dd')

@description('Progress tag: ephemeral (yes/no)')
@allowed([
  'yes'
  'no'
])
param ephemeral string = 'yes'

var tags = {
  'X-Customer': xCustomer
  'X-Project': xProject
  'X-Application': xApplication
  'X-Dept': xDept
  'X-Name': xName
  'X-Contact': xContact
  'X-TTL': xTTL
  application: application
  team: team
  owner: owner
  expiration: expiration
  ephemeral: ephemeral
}

var vmIndices = range(0, vmCount)
var vmNames = [for i in vmIndices: '${namePrefix}-${i + 1}']
var privateIpAddresses = [for i in vmIndices: cidrHost(subnetAddressPrefix, privateIpHostOffset + i)]
var expectedPublicIpNames = [for vmName in vmNames: '${vmName}-pip']
var linuxCloudInit = base64(format('''
#cloud-config
package_update: true
packages:
  - curl
  - jq
  - openssh-client
  - openssh-server
ssh_pwauth: false
write_files:
  - path: /etc/sudoers.d/chef
    permissions: '0440'
    owner: root:root
    content: |
      {0} ALL=(ALL) NOPASSWD:ALL
runcmd:
  - [ sh, -c, "sed -i '/[[:space:]]node1$/d; /[[:space:]]node2$/d' /etc/hosts && printf '%s\\tnode1\\n%s\\tnode2\\n' '{1}' '{2}' >> /etc/hosts" ]
  - [ chmod, '0440', /etc/sudoers.d/chef ]
  - [ visudo, -cf, /etc/sudoers.d/chef ]
  - [ systemctl, enable, --now, ssh ]
  - [ touch, /var/lib/chef360-template-ready ]
''', adminUsername, privateIpAddresses[0], privateIpAddresses[1]))

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${namePrefix}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: createPublicIp ? [
      {
        name: 'allow-ssh'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: sshSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-https'
        properties: {
          priority: 1010
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ] : []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: '${namePrefix}-subnet'
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2023-11-01' = [for (vmName, i) in vmNames: if (createPublicIp) {
  name: '${vmName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2023-11-01' = [for (vmName, i) in vmNames: {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIpAddresses[i]
          subnet: {
            id: '${vnet.id}/subnets/${namePrefix}-subnet'
          }
          publicIPAddress: createPublicIp ? {
            id: publicIps[i].id
          } : null
        }
      }
    ]
  }
}]

resource linuxVms 'Microsoft.Compute/virtualMachines@2024-03-01' = [for (vmName, i) in vmNames: {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-22_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      customData: linuxCloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    priority: useSpot ? 'Spot' : 'Regular'
    evictionPolicy: useSpot ? 'Deallocate' : null
    billingProfile: useSpot ? {
      maxPrice: spotMaxPrice
    } : null
  }
}]

output vmNames array = [for i in vmIndices: linuxVms[i].name]
output privateIps array = [for i in vmIndices: nics[i].properties.ipConfigurations[0].properties.privateIPAddress]
output publicIpResourceNames array = createPublicIp ? expectedPublicIpNames : []
output nodeHostEntries array = [for i in vmIndices: '${privateIpAddresses[i]} ${vmNames[i]}']
