targetScope = 'resourceGroup'

param miClusterControlPlanePrincipalId string
param clusterControlPlaneIdentityName string
param targetVirtualNetworkName string
param aksNodesSubnetName string
param aksInternalLABSubnetName string

resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  scope: subscription()
}

resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: targetVirtualNetworkName
}

resource snetClusterNodes 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: aksNodesSubnetName
}

resource snetClusterIngress 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: aksInternalLABSubnetName
}

resource snetClusterNodesMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: snetClusterNodes
  name: guid(snetClusterNodes.id, networkContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetClusterIngressServicesMiClusterControlPlaneSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: snetClusterIngress
  name: guid(snetClusterIngress.id, networkContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join load balancers (ingress resources) to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}
