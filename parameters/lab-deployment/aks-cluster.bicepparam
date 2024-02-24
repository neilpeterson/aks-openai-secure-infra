using '../../cluster-deployment/aks-cluster.bicep'

param aksOSSKU = 'AzureLinux'
param clusterName = 'aks-cluster-one'
param keyVaultResourceGroupoName = 'aks-shared-resources'
param keyVautlName = 'aks-certificates'
param location = 'eastus'
param aksAdminGroup = '1c53e0cf-094a-49bb-b746-ff2d9f601b6c'
param kubernetesVersion = '1.28.3'
param logAnalyticsWorkspaceName = 'all-logs'
param virtualNetworkName = 'appgw-kubernetes'
param privateCluster = false
param applicationGatewayName = 'appgw-kubernetes'
param domainName = 'apim-lab-aks.nepeters.supplychain.microsoft.com'
