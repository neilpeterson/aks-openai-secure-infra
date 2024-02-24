using '../../cluster-deployment/jump-box.bicep'

param adminUsername = 'azureadmin'
param jumpBoxName = 'aks-jump-box'
param hubVirtualNetworkName = 'hub-vnet'
param hubVirtualNetworkResoruceGroupName = 'hub-vnet-rg'
param location = 'eastus'
