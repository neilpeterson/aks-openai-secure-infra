using '../../cluster-deployment/aks-cluster.bicep'

param aksOSSKU = 'AzureLinux'
param clusterName = 'aks-cluster-one'
param keyVaultResourceGroupoName = 'aks-shared-resources'
param keyVautlName = 'aks-certificates'
param location = 'eastus'
param aksAdminGroup = '<replace>'
param kubernetesVersion = '1.28.3'
param logAnalyticsWorkspaceName = 'all-logs'
param virtualNetworkName = 'appgw-kubernetes'
param privateCluster = false
param applicationGatewayName = 'appgw-kubernetes'
param domainName = '<replace>
param containerRegistryName = 'nepcontainerregistry'
param workloadIdentityServiceAccountName = 'pod-workload'
param workloadIdentityServiceAccountNamespace = 'default'
