param aksAdminGroup string = '1c53e0cf-094a-49bb-b746-ff2d9f601b6c'
param clusterAuthorizedIPRanges array = []
param location string = resourceGroup().location
param kubernetesVersion string = '1.28.3'
param clusterName string = 'aks-test-one'
param logAnalyticsWorkspaceName string = 'all-logs'
param virtualNetworkName string = 'appgw-kubernetes'
param privateCluster bool = false
param applicationGatewayName string = 'appgw-kubernetes'
param domainName string = 'apim-lab-aks.nepeters.supplychain.microsoft.com'
// param aksDomainCertificate string = 'https://aks-certificates.vault.azure.net/secrets/apim-lab-aks/3fa2ff3f64ed46208cec22c6fd1f3285'
// param aksIngressCertificate string = 'https://aks-certificates.vault.azure.net/secrets/apim-lab-aks-ingress/2d3582cfa14d4c9a99f3ae9b4d3131fb'

param aksOSSKU string = 'AzureLinux'

param keyVautlName string = 'aks-certificates'
param keyVaultResourceGroupoName string = 'aks-shared-resources'

var isUsingAzureRBACasKubernetesRBAC = (subscription().tenantId == subscription().tenantId)
var aksIngressDomainName = 'aks-ingress.${domainName}'
var aksBackendDomainName = 'bu0001a0008-00.${aksIngressDomainName}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: virtualNetworkName
}

resource logAnalyticeWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVautlName
  scope: resourceGroup(keyVaultResourceGroupoName)
}

resource aksDomainCertificate 'Microsoft.KeyVault/vaults/secrets@2023-07-01'  existing = {
  parent: keyVault
  name: 'apim-lab-aks'
}

// resource aksIngressCertificate 'Microsoft.KeyVault/vaults/secrets@2023-07-01'  existing = {
//   parent: keyVault
//   name: 'apim-lab-aks-ingress'
// }

// Added Base64 encoded public cert as secret, but need to better understand, like rotation.
// resource kvsAppGwIngressInternalAksIngressTls 'Microsoft.KeyVault/vaults/secrets@2023-07-01' existing = {
//   parent: keyVault
//   name: 'appgw-ingress-internal-aks-ingress-tls'
// }

// The control plane identity used by the cluster. Used for networking access (VNET joining and DNS updating)
resource clusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'aks-${clusterName}'
  location: location
}

// Built-in Azure RBAC role that can be applied to a cluster or a namespace to grant read and write privileges to that scope for a user or group
resource clusterAdminRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
  scope: subscription()
}

resource mcMicrosoftEntraAdminGroupClusterAdminRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: AKSCluster
  name: guid('microsoft-entra-admin-group', AKSCluster.id, aksAdminGroup)
  properties: {
    roleDefinitionId: clusterAdminRole.id
    description: 'Members of this group are cluster admins of this cluster.'
    principalId: aksAdminGroup
    principalType: 'Group'
  }
}

// Built-in Azure RBAC role that is applied to a cluster to indicate they can be considered a user/group of the cluster, subject to additional RBAC permissions
resource serviceClusterUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
  scope: subscription()
}

resource mcMicrosoftEntraAdminGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: AKSCluster
  name: guid('microsoft-entra-admin-group-sc', AKSCluster.id, aksAdminGroup)
  properties: {
    roleDefinitionId: serviceClusterUserRole.id
    description: 'Members of this group are cluster users of this cluster.'
    principalId: aksAdminGroup
    principalType: 'Group'
  }
}

resource AKSCluster 'Microsoft.ContainerService/managedClusters@2023-02-02-preview' = {
  name: clusterName
  location: location
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, clusterName)
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 3
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 80
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: aksOSSKU
        minCount: 3
        maxCount: 4
        vnetSubnetID:'${virtualNetwork.id}/subnets/kubernetes-nodes'
        enableAutoScaling: true
        enableCustomCATrust: false
        enableFIPS: false
        enableEncryptionAtHost: false
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
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
        osSKU: aksOSSKU
        minCount: 2
        maxCount: 5
        vnetSubnetID: '${virtualNetwork.id}/subnets/kubernetes-nodes'
        enableAutoScaling: true
        enableCustomCATrust: false
        enableFIPS: false
        enableEncryptionAtHost: false
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
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
      enableAzureRBAC: isUsingAzureRBACasKubernetesRBAC
      adminGroupObjectIDs: ((!isUsingAzureRBACasKubernetesRBAC) ? array(aksAdminGroup) : [])
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
      authorizedIPRanges: clusterAuthorizedIPRanges
      enablePrivateCluster: privateCluster
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
      customCATrustCertificates: [] // Empty
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
    ingressProfile: {
      webAppRouting: {
        enabled: false
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${clusterControlPlane.id}': {}
    }
  }
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
}

// User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.
resource miAppGatewayFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-appgateway-frontend'
  location: location
}

resource applicationGatewayIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'cluster-ingress-ip'
  location: location
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

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-05-01' = {
  name: 'waf-${clusterName}'
  location: location
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

// // Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges.  Granted to App Gateway's managed identity.
// resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   name: '21090545-7ca7-4776-b22c-e363652d74d2'
//   scope: subscription()
// }

// // Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload's identity.
// resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   name: '4633458b-17de-408a-b874-0445c86b69e6'
//   scope: subscription()
// }

// // Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
// resource kvMiAppGatewayFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   scope: keyVault
//   name: guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultSecretsUserRole.id)
//   properties: {
//     roleDefinitionId: keyVaultSecretsUserRole.id
//     principalId: miAppGatewayFrontend.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

// // Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
// resource kvMiAppGatewayFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   scope: keyVault
//   name: guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultReaderRole.id)
//   properties: {
//     roleDefinitionId: keyVaultReaderRole.id
//     principalId: miAppGatewayFrontend.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

module appGatewayKeyVaultAccess 'modules/key-vault-access.bicep' = {
  name: 'appGatewayKeyVaultAccess'
  scope: resourceGroup(keyVaultResourceGroupoName)
  params: {
    keyVaultName: keyVault.name
    miAppGatewayPrincipalId: miAppGatewayFrontend.properties.principalId
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: applicationGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miAppGatewayFrontend.id}': {}
    }
  }
  zones: pickZones('Microsoft.Network', 'applicationGateways', location, 3)
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
    // TODO - do I need this, or is this only needed when using self signed certs?
    // trustedRootCertificates: [
    //   {
    //     name: 'root-cert-wildcard-aks-ingress'
    //     properties: {
    //       // keyVaultSecretId: aksIngressCertificate.properties.secretUri
    //       keyVaultSecretId: kvsAppGwIngressInternalAksIngressTls.properties.secretUri
    //     }
    //   }
    // ]
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
      id: wafPolicy.id
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: '${applicationGatewayName}-ssl-certificate'
        properties: {
          keyVaultSecretId: aksDomainCertificate.properties.secretUri
        }
      }
    ]
    probes: [
      {
        name: 'probe-${aksBackendDomainName}'
        properties: {
          protocol: 'Https'
          path: '/favicon.ico'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {}
        }
      }
    ]
    backendAddressPools: [
      {
        name: aksBackendDomainName
        properties: {
          backendAddresses: [
            {
              fqdn: aksBackendDomainName
            }
          ]
        }
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
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, 'probe-${aksBackendDomainName}')
          }
          // trustedRootCertificates: [
          //   {
          //     id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', applicationGatewayName, 'root-cert-wildcard-aks-ingress')
          //   }
          // ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'apw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'port-443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, '${applicationGatewayName}-ssl-certificate')
          }
          hostName: domainName
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, aksBackendDomainName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'aks-ingress-backendpool-httpsettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    appGatewayKeyVaultAccess
  ]
}

