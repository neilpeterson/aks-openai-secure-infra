param targetVnetResourceId string
param location string = resourceGroup().location 
param geoRedundancyLocation string = 'westus'
param acrIdentifier string = 'sceacr'

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: last(split(targetVnetResourceId,'/'))
  
  resource snetPrivateLinkEndpoints 'subnets' existing = {
    name: 'privatelinkendpoints'
  }
}

resource laAks 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'aks-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Apply the built-in 'Container registries should have anonymous authentication disabled' policy. Azure RBAC only is allowed.
var pdAnonymousContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '9f2dea28-e834-476c-99c5-3507b4728395')
resource paAnonymousContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid(resourceGroup().id, pdAnonymousContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[[${acrIdentifier}] ${reference(pdAnonymousContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(pdAnonymousContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: pdAnonymousContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Apply the built-in 'Container registries should have local admin account disabled' policy. Azure RBAC only is allowed.
var pdAdminAccountContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'dc921057-6b28-4fbe-9b83-f7bec05db6c2')
resource paAdminAccountContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid(resourceGroup().id, pdAdminAccountContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${acrIdentifier}] ${reference(pdAdminAccountContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(pdAdminAccountContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: pdAdminAccountContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Azure Container Registry will be exposed via Private Link, set up the related Private DNS zone and virtual network link to the spoke.
resource dnsPrivateZoneAcr 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  properties: {}

  resource dnsVnetLinkAcrToSpoke 'virtualNetworkLinks' = {
    name: 'to_${spokeVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: spokeVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

// The Container Registry that the AKS cluster will be authorized to use to pull images.
resource acrAks 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrIdentifier
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 15
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Disabled'
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: true
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled' // This Preview feature only supports three regions at this time, and eastus2's paired region (centralus), does not support this. So disabling for now.
  }
  dependsOn: [
    paAdminAccountContainerRegistryAccessDisallowed
    paAnonymousContainerRegistryAccessDisallowed
  ]

  resource acrReplication 'replications@2021-09-01' = {
    name: geoRedundancyLocation
    location: geoRedundancyLocation
    properties: {}
  }
}

resource acrAks_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: acrAks
  properties: {
    workspaceId: laAks.id
    metrics: [
      {
        timeGrain: 'PT1M'
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// Expose Azure Container Registry via Private Link, into the cluster nodes virtual network.
resource privateEndpointAcrToVnet 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: acrAks.name
  location: location
  dependsOn: [
    acrAks::acrReplication
  ]
  properties: {
    subnet: {
      id: spokeVirtualNetwork::snetPrivateLinkEndpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to_${spokeVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: acrAks.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }

  resource privateDnsZoneGroupAcr 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-azurecr-io'
          properties: {
            privateDnsZoneId: dnsPrivateZoneAcr.id
          }
        }
      ]
    }
  }
}
