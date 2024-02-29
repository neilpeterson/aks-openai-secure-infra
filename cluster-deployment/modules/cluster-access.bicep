targetScope = 'resourceGroup'

param miClusterControlPlanePrincipalId string
param clusterControlPlaneIdentityName string
param targetVirtualNetworkName string

/*** EXISTING SUBSCRIPTION RESOURCES ***/

resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  scope: subscription()
}

/*** EXISTING HUB RESOURCES ***/

resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: targetVirtualNetworkName
}

// TODO - add subnet parameter
resource snetClusterNodes 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: 'kubernetes-nodes'
}

// TODO - add subnet parameter
resource snetClusterIngress 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: 'cluster-internal-lb'
}

/*** RESOURCES ***/

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
