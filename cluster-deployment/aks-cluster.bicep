
param AKS_CONFIG_PARAM object
param CONTAINER_REGISTRY_NAME string
param KEY_VAULT object
param APPLICATION_GATEWAY object
param LOG_ANALYTICS_WORKSPACE_NAME string
param LOCATION string = resourceGroup().location
param VIRTUAL_NETWORK_NAME string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: VIRTUAL_NETWORK_NAME
}

resource AKSNodeSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: virtualNetwork
  name: AKS_CONFIG_PARAM.AKS_NODES_SUBNET_NAME
}

resource AKSInternalLBSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: virtualNetwork
  name: AKS_CONFIG_PARAM.AKS_INTERNAL_LB_NAME
}

resource logAnalyticeWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: LOG_ANALYTICS_WORKSPACE_NAME
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: KEY_VAULT.NAME
  scope: resourceGroup(KEY_VAULT.RESOURCE_GROUP_NAME)
}

resource aksDomainCertificate 'Microsoft.KeyVault/vaults/secrets@2023-07-01'  existing = {
  parent: keyVault
  name: 'apim-lab-aks'
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: CONTAINER_REGISTRY_NAME
}

// The control plane identity used by the cluster. Used for networking access (VNET joining and DNS updating)
resource clusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: AKS_CONFIG_PARAM.CLUSTER_NAME
  location: LOCATION
}

module clusterIdentityAssignment 'modules/cluster-access.bicep' = {
  name: 'EnsureClusterIdentityHasRbacToSelfManagedResources'
  scope: resourceGroup(resourceGroup().name)
  params: {
    miClusterControlPlanePrincipalId: clusterIdentity.properties.principalId
    clusterControlPlaneIdentityName: clusterIdentity.name
    targetVirtualNetworkName: virtualNetwork.name
    aksNodesSubnetName: AKSNodeSubnet.name
    aksInternalLABSubnetName: AKSInternalLBSubnet.name
  }
}

// Built-in Azure RBAC role that can be applied to a cluster or a namespace to grant read and write privileges to that scope for a user or group
resource clusterAdminRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
  scope: subscription()
}

// resource clusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
resource clusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: AKSCluster
  name: guid('microsoft-entra-admin-group', AKSCluster.id, AKS_CONFIG_PARAM.AKS_ENTRA_ADMIN_GROUP)
  properties: {
    roleDefinitionId: clusterAdminRole.id
    description: 'Members of this group are cluster admins of this cluster.'
    principalId: AKS_CONFIG_PARAM.AKS_ENTRA_ADMIN_GROUP
    principalType: 'Group'
  }
}

// Built-in Azure RBAC role that is applied to a cluster to indicate they can be considered a user/group of the cluster, subject to additional RBAC permissions
// TODO - don't think I quite understand this.
resource serviceClusterUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
  scope: subscription()
}

// resource serviceClusterUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
resource serviceClusterUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: AKSCluster
  name: guid('microsoft-entra-admin-group-sc', AKSCluster.id, AKS_CONFIG_PARAM.AKS_ENTRA_ADMIN_GROUP)
  properties: {
    roleDefinitionId: serviceClusterUserRole.id
    description: 'Members of this group are cluster users of this cluster.'
    principalId: AKS_CONFIG_PARAM.AKS_ENTRA_ADMIN_GROUP
    principalType: 'Group'
  }
}

// TODO - review all settings
resource AKSCluster 'Microsoft.ContainerService/managedClusters@2023-02-02-preview' = {
  name: AKS_CONFIG_PARAM.CLUSTER_NAME
  location: LOCATION
  properties: {
    kubernetesVersion: AKS_CONFIG_PARAM.KUBERNETES_VERSION
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, AKS_CONFIG_PARAM.CLUSTER_NAME)
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 3
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 80
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: AKS_CONFIG_PARAM.AKS_OS_SKU
        minCount: 3
        maxCount: 4
        vnetSubnetID: AKSNodeSubnet.id
        enableAutoScaling: true
        enableCustomCATrust: false
        enableFIPS: false
        enableEncryptionAtHost: false
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: AKS_CONFIG_PARAM.KUBERNETES_VERSION
        enableNodePublicIP: false
        maxPods: 30
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'npuser01'
        count: 2
        vmSize: 'Standard_DS3_v2'
        osDiskSizeGB: 120
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: AKS_CONFIG_PARAM.AKS_OS_SKU
        minCount: 2
        maxCount: 5
        vnetSubnetID: AKSNodeSubnet.id
        enableAutoScaling: true
        enableCustomCATrust: false
        enableFIPS: false
        enableEncryptionAtHost: false
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: AKS_CONFIG_PARAM.KUBERNETES_VERSION
        enableNodePublicIP: false
        maxPods: 30
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceId: logAnalyticeWorkspace.id
        }
      }
      aciConnectorLinux: {
        enabled: false
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
        }
      }
      ingressApplicationGateway: {
        config: {
          applicationGatewayId: applicationGateway.id
        }
        enabled: true
      }
    }
    nodeResourceGroup: '${resourceGroup().name}-nodes'
    enableRBAC: true
    enablePodSecurityPolicy: false
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      //TODO - I am changing this from userDefinedRouting, need to better understand.
      outboundType: 'loadBalancer'
      loadBalancerSku: 'standard'
      loadBalancerProfile: null
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [AKS_CONFIG_PARAM.AKS_ENTRA_ADMIN_GROUP] // This is an array however template does not support an arry at this time.
      tenantID: subscription().tenantId
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '20s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'true'
      'skip-nodes-with-system-pods': 'true'
    }
    apiServerAccessProfile: {
      authorizedIPRanges: AKS_CONFIG_PARAM.AUTHORIZED_IP_RANGES
      enablePrivateCluster: AKS_CONFIG_PARAM.PRIVATE_CLUSTER
    }
    podIdentityProfile: {
      enabled: false // Using Microsoft Entra Workload IDs for pod identities.
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    azureMonitorProfile: {
      metrics: {
        enabled: false // This is for the AKS-PrometheusAddonPreview, which is not enabled in this cluster as Container Insights is already collecting.
      }
    }
    storageProfile: {  // By default, do not support native state storage, enable as needed to support workloads that require state
      blobCSIDriver: {
        enabled: false // Azure Blobs
      }
      diskCSIDriver: {
        enabled: false // Azure Disk
      }
      fileCSIDriver: {
        enabled: false // Azure Files
      }
      snapshotController: {
        enabled: false // CSI Snapshotter: https://github.com/kubernetes-csi/external-snapshotter
      }
    }
    workloadAutoScalerProfile: {
      keda: {
        enabled: false // Enable if using KEDA to scale workloads
      }
    }
    disableLocalAccounts: true
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 120 // 5 days
      }
      azureKeyVaultKms: {
        enabled: false // Not enabled in the this deployment, as it is not used. Enable as needed.
      }
      nodeRestriction: {
        enabled: true // https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction
      }
      customCATrustCertificates: []
      defender: {
        logAnalyticsWorkspaceResourceId: logAnalyticeWorkspace.id
        securityMonitoring: {
          enabled: true
        }
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    enableNamespaceResources: false
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${clusterIdentity.id}': {}
    }
  }
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
}

resource ACRPullRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

resource cluaterACRAccess 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: containerRegistry
  name: guid(clusterIdentity.id, ACRPullRole.id)
  properties: {
    roleDefinitionId: ACRPullRole.id
    description: 'Allows AKS to pull container images from this ACR instance.'
    principalId: AKSCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Workload Identity for Key Vault access.
resource podWorkladIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'pod-workload'
  location: LOCATION

  resource federatedCreds 'federatedIdentityCredentials@2022-01-31-preview' = {
    name: 'pod-workload'
    properties: {
      issuer: AKSCluster.properties.oidcIssuerProfile.issuerURL
      subject: 'system:serviceaccount:${AKS_CONFIG_PARAM.WORKLOAD_IDENTITY_NS}:${AKS_CONFIG_PARAM.WORKLOAD_IDENTITY_SA_NAME}'
      audiences: [
        'api://AzureADTokenExchange'
      ]
    }
  }
}

module podWorkloadIdentityAKVAccess 'modules/key-vault-access.bicep' = {
  name: 'podWorkloadIdentityAKVAccess'
  scope: resourceGroup(KEY_VAULT.RESOURCE_GROUP_NAME)
  params: {
    keyVaultName: keyVault.name
    miAppGatewayPrincipalId: podWorkladIdentity.properties.principalId
    identityName: podWorkladIdentity.name
  }
}

// Workload Identity for Ingress Controller Key Vault access.
resource podWorkladIdentityIngress 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'ingress-pod-workload'
  location: LOCATION

  resource federatedCreds 'federatedIdentityCredentials@2022-01-31-preview' = {
    name: 'ingress-controller'
    properties: {
      issuer: AKSCluster.properties.oidcIssuerProfile.issuerURL
      subject: 'system:serviceaccount:a0008:traefik-ingress-controller'
      audiences: [
        'api://AzureADTokenExchange'
      ]
    }
  }
}

module ingressIdentityAKVAccess 'modules/key-vault-access.bicep' = {
  name: 'ingressIdentityAKVAccess'
  scope: resourceGroup(KEY_VAULT.RESOURCE_GROUP_NAME)
  params: {
    keyVaultName: keyVault.name
    miAppGatewayPrincipalId: podWorkladIdentityIngress.properties.principalId
    identityName: podWorkladIdentityIngress.name
  }
}

// User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.
resource appGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'application-gateway'
  location: LOCATION
}

resource applicationGatewayIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'cluster-ingress-ip'
  location: LOCATION
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource WAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-05-01' = {
  name: AKS_CONFIG_PARAM.CLUSTER_NAME
  location: LOCATION
  properties: {
    policySettings: {
      fileUploadLimitInMb: 10
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

module appGatewayKeyVaultAccess 'modules/key-vault-access.bicep' = {
  name: 'appGatewayKeyVaultAccess'
  scope: resourceGroup(KEY_VAULT.RESOURCE_GROUP_NAME)
  params: {
    keyVaultName: keyVault.name
    miAppGatewayPrincipalId: appGatewayIdentity.properties.principalId
    identityName: appGatewayIdentity.name
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: APPLICATION_GATEWAY.NAME
  location: LOCATION
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGatewayIdentity.id}': {}
    }
  }
  zones: pickZones('Microsoft.Network', 'applicationGateways', LOCATION, 3)
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslPolicy: {
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    gatewayIPConfigurations: [
      {
        name: 'apw-ip-configuration'
        properties: {
          subnet: {
            //TODO - config with param.
            id: '${virtualNetwork.id}/subnets/application-gateway'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'apw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: applicationGatewayIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-443'
        properties: {
          port: 443
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    firewallPolicy: {
      id: WAFPolicy.id
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: '${APPLICATION_GATEWAY.NAME}-ssl-certificate'
        properties: {
          keyVaultSecretId: aksDomainCertificate.properties.secretUri
        }
      }
    ]
    probes: []
    backendAddressPools: [
      {
        name: 'bicep-deployment-requires-backend-pool'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'aks-ingress-backendpool-httpsettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', APPLICATION_GATEWAY.NAME, 'apw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', APPLICATION_GATEWAY.NAME, 'port-443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', APPLICATION_GATEWAY.NAME, '${APPLICATION_GATEWAY.NAME}-ssl-certificate')
          }
          hostName: APPLICATION_GATEWAY.DOMAIN
          hostNames: []
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'apw-routing-rules'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', APPLICATION_GATEWAY.NAME, 'listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', APPLICATION_GATEWAY.NAME, 'bicep-deployment-requires-backend-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', APPLICATION_GATEWAY.NAME, 'aks-ingress-backendpool-httpsettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    appGatewayKeyVaultAccess
  ]
}

resource Contributor 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: subscription()
}

// TODO - should be able to squeese this down a bit, no?
resource appGwContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(applicationGateway.id, containerRegistry.id, 'agic')
  properties: {
    roleDefinitionId: Contributor.id
    principalId: AKSCluster.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
    scope: resourceGroup().id
  }
}
