
param hubVirtualNetworkName string
param location string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: hubVirtualNetworkName
}

resource virtualMachineNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'jump-box'
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource jumpBoxSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: virtualNetwork
  name: 'jump-box'
  properties: {
    addressPrefix: '10.200.0.96/28'
    networkSecurityGroup: {
      id: virtualMachineNSG.id
    }
  }
}

output jumbBoxSubnetId string = jumpBoxSubnet.id
output virtualMachineNSGID string = virtualMachineNSG.id
