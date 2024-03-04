using '../../cluster-deployment/aks-cluster.bicep'

param AKS_CONFIG_PARAM = {
  CLUSTER_NAME:               'aks-cluster-one'
  AKS_OS_SKU:                 'AzureLinux'
  AKS_ENTRA_ADMIN_GROUP:      '1c53e0cf-094a-49bb-b746-ff2d9f601b6c'
  KUBERNETES_VERSION:         '1.28.3'
  PRIVATE_CLUSTER:            false
  WORKLOAD_IDENTITY_SA_NAME:  'pod-workload'  // Used when setting up federated credential, need to match service account manifest.
  WORKLOAD_IDENTITY_NS:       'default'       // Used when setting up federated credential, need to match service account manifest.
  AUTHORIZED_IP_RANGES:       []
  AKS_NODES_SUBNET_NAME:      'kubernetes-nodes'
  AKS_INTERNAL_LB_NAME:       'kubernetes-internal-lb'
}

param APPLICATION_GATEWAY = {
  NAME:                'appgw-kubernetes'
  DOMAIN:             'apim-lab-aks.nepeters.supplychain.microsoft.com'
}

param KEY_VAULT = {
  NAME:                'aks-certificates'
  RESOURCE_GROUP_NAME: 'aks-shared-resources'
  LOCATION:                      'eastus'
}

param CONTAINER_REGISTRY_NAME       = 'scecontainerregistry'
param LOG_ANALYTICS_WORKSPACE_NAME  = 'all-logs'
param VIRTUAL_NETWORK_NAME          = 'appgw-kubernetes'
