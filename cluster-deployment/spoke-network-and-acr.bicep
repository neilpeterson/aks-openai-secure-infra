param LOCATION string = resourceGroup().location
param CONTAINER_REGISTRY object
param KEY_VAULT object
param CLUSTER_VIRTUAL_NETWORK object
param HUB_VIRTUAL_NETWORK object
param LOG_ANALYTICS_WORKSPACE_NAME string

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: HUB_VIRTUAL_NETWORK.NAME
  scope: resourceGroup(HUB_VIRTUAL_NETWORK.RESOURCE_GROUP_NAME)
}

resource nsgNodepoolSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: CLUSTER_VIRTUAL_NETWORK.AKS_NODES_SUBNET_NSG_NAME
  location: LOCATION
  properties: {
    securityRules: []
  }
}

resource nsgInternalLoadBalancer 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: CLUSTER_VIRTUAL_NETWORK.AKS_INTERNAL_LB_NAME
  location: LOCATION
  properties: {
    securityRules: []
  }
}

resource nsgApplicationGateway 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: CLUSTER_VIRTUAL_NETWORK.APP_GW_NSG_NAME
  location: LOCATION
  properties: {
    securityRules: [
      {
        name: 'Allow443Inbound'
        properties: {
          description: 'Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you\'d list them.)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Allow Azure Control Plane in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '65200-65535'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 110
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 120
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'App Gateway v2 requires full outbound access.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgPrivateLinkEndpoints 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: CLUSTER_VIRTUAL_NETWORK.PRIVATE_LINK_NSG_NAME
  location: LOCATION
  properties: {
    securityRules: [
      {
        name: 'AllowAll443InFromVnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: CLUSTER_VIRTUAL_NETWORK.NAME
  location: LOCATION
  properties: {
    addressSpace: {
      addressPrefixes: CLUSTER_VIRTUAL_NETWORK.ADDRESS_SPACE //Casting an array from parameter object.
    }
    subnets: [
      {
        name: CLUSTER_VIRTUAL_NETWORK.AKS_NODES_SUBNET_NAME
        properties: {
          addressPrefix: CLUSTER_VIRTUAL_NETWORK.AKS_NODES_SUBNET_RANGE
          networkSecurityGroup: {
            id: nsgNodepoolSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: CLUSTER_VIRTUAL_NETWORK.AKS_INTERNAL_LB_SUBNET_NAME
        properties: {
          addressPrefix: CLUSTER_VIRTUAL_NETWORK.AKS_INTERNAL_LB_SUBNET_RANGE
          networkSecurityGroup: {
            id: nsgInternalLoadBalancer.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: CLUSTER_VIRTUAL_NETWORK.APP_GW_SUBNET_NAME
        properties: {
          addressPrefix: CLUSTER_VIRTUAL_NETWORK.APP_GW_SUBNET_RANGE
          networkSecurityGroup: {
            id: nsgApplicationGateway.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: CLUSTER_VIRTUAL_NETWORK.PRIVATE_LINK_SUBNET_NAME
        properties: {
          addressPrefix: CLUSTER_VIRTUAL_NETWORK.PRIVATE_LINK_SUBNET_RANGE
          networkSecurityGroup: {
            id: nsgPrivateLinkEndpoints.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource peeringSpokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: CLUSTER_VIRTUAL_NETWORK.PEER_TO_HUB_NAME
  parent: virtualNetwork
  properties: {
    remoteVirtualNetwork: {
      id: hubVirtualNetwork.id
    }
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
  }
}

module peeringHubToSpoke 'modules/peer-hub-to-spoke.bicep' = {
  name: CLUSTER_VIRTUAL_NETWORK.PEER_FROM_HUB_NAME
  scope: resourceGroup(HUB_VIRTUAL_NETWORK.RESOURCE_GROUP_NAME)
  params: {
    remoteVirtualNetworkId: virtualNetwork.id
    localVnetName: hubVirtualNetwork.name
  }
  dependsOn: [
    peeringSpokeToHub
  ]
}

resource logAnalyticeWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: LOG_ANALYTICS_WORKSPACE_NAME
  location: LOCATION
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
var anonymousContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '9f2dea28-e834-476c-99c5-3507b4728395')
resource anonymousContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid(resourceGroup().id, anonymousContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('${reference(anonymousContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(anonymousContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: anonymousContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Apply the built-in 'Container registries should have local admin account disabled' policy. Azure RBAC only is allowed.
var adminAccountContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'dc921057-6b28-4fbe-9b83-f7bec05db6c2')
resource adminAccountContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid(resourceGroup().id, adminAccountContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('${reference(adminAccountContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(adminAccountContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: adminAccountContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: CONTAINER_REGISTRY.NAME
  location: LOCATION
  sku: {
    name: CONTAINER_REGISTRY.SKU_NAME
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
    adminAccountContainerRegistryAccessDisallowed
    anonymousContainerRegistryAccessDisallowed
  ]

  resource acrReplication 'replications@2021-09-01' = {
    name: CONTAINER_REGISTRY.GEO_REDUNDANT_LOCATION
    location: CONTAINER_REGISTRY.GEO_REDUNDANT_LOCATION
    properties: {}
  }
}

resource containerRegistryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: containerRegistry
  properties: {
    workspaceId: logAnalyticeWorkspace.id
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
resource privateEndpointACRToVnet 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: containerRegistry.name
  location: LOCATION
  dependsOn: [
    containerRegistry::acrReplication
  ]
  properties: {
    subnet: {
      id: '${virtualNetwork.id}/subnets/private-link-endpoints'
    }
    privateLinkServiceConnections: [
      {
        name: virtualNetwork.name
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
    customNetworkInterfaceName: containerRegistry.name
  }

  resource privateDnsZoneGroupAcr 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-azurecr-io'
          properties: {
            privateDnsZoneId: dnsPrivateZoneACR.id
          }
        }
      ]
    }
  }
}

// Azure Container Registry will be exposed via Private Link, set up the related Private DNS zone and virtual network link to the spoke.
resource dnsPrivateZoneACR 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  properties: {}

  resource dnsVnetLinkAcrToSpoke 'virtualNetworkLinks' = {
    name: virtualNetwork.name
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: KEY_VAULT.NAME
  scope: resourceGroup(KEY_VAULT.RESOURCE_GROUP_NAME)
}

// Enabling Azure Key Vault Private Link support.
resource dnsPrivateZoneAKV 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'

  resource dnsVnetLinkAKVToSpoke 'virtualNetworkLinks' = {
    name: virtualNetwork.name
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource privateEndpointAKVToVnet 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: keyVault.name
  location: LOCATION
  properties: {
    subnet: {
      id: '${virtualNetwork.id}/subnets/private-link-endpoints'
    }
    privateLinkServiceConnections: [
      {
        name: virtualNetwork.name
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    customNetworkInterfaceName: keyVault.name
  }

  resource pdnszg 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-akv-net'
          properties: {
            privateDnsZoneId: dnsPrivateZoneAKV.id
          }
        }
      ]
    }
  }
}
