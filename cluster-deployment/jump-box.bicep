param location string = resourceGroup().location
param adminUsername string = 'azureadmin'
param hubVirtualNetworkResoruceGroupName string = 'aks-hub-network'
param hubVirtualNetworkName string  = 'vnet-eastus-hub'

@secure()
param adminPassword string

module jumpBoxSubnet 'modules/jump-box-subnet.bicep' = {
  name: 'jump-box'
  scope: resourceGroup(hubVirtualNetworkResoruceGroupName)
  params: {
    hubVirtualNetworkName: hubVirtualNetworkName
    location: location
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'jump-box'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: jumpBoxSubnet.outputs.jumbBoxSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: jumpBoxSubnet.outputs.virtualMachineNSGID
    }
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: 'jump-box'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: 'jump-box'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
  }
}
