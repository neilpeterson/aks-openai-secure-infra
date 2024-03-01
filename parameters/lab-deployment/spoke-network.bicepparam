using '../../cluster-deployment/spoke-network-and-acr.bicep'

param CONTAINER_REGISTRY = {
  NAME: 'scecontainerregistry'
  SKU_NAME: 'Premium'
  GEO_REDUNDANT_LOCATION: 'westus'
}


param CLUSTER_VIRTUAL_NETWORK = {
  NAME:                         'appgw-kubernetes'
  ADDRESS_SPACE:                ['10.240.0.0/16']
  // SUBNET_NAME_FIREWALL:         'AzureFirewallSubnet' // Not yet in template, will also add NSG
  // SUBNET_RANGE_FIREWALL:        '10.200.0.0/26'
  SUBNET_RANGE_BASTION:         '10.200.0.128/26' // Subnet name is predetermined and hard coded.
  AKS_NODES_SUBNET_NAME:        'kubernetes-nodes'
  AKS_NODES_SUBNET_RANGE:       '10.240.0.0/22'
  AKS_NODES_SUBNET_NSG_NAME:    'aks-nodes'
  AKS_INTERNAL_LB_NAME:         'kubernetes-internal-lb'
  AKS_INTERNAL_LB_SUBNET_NAME:  'cluster-internal-lb'
  AKS_INTERNAL_LB_SUBNET_RANGE: '10.240.4.0/28'
  APP_GW_SUBNET_NAME:           'application-gateway'
  APP_GW_SUBNET_RANGE:          '10.240.5.0/24'
  APP_GW_NSG_NAME:              'application-gateway'
  PRIVATE_LINK_SUBNET_NAME:     'private-link-endpoints'
  PRIVATE_LINK_SUBNET_RANGE:    '10.240.4.32/28'
  PRIVATE_LINK_NSG_NAME:        'private-link-endpoints'
  PEER_TO_HUB_NAME:             'peer-to-hub'
  PEER_FROM_HUB_NAME:           'peer-hub-to-spoke'
}

param HUB_VIRTUAL_NETWORK = {
  NAME: 'aks-hub-network'
  RESOURCE_GROUP_NAME: 'aks-hub-network'
}

param KEY_VAULT = {
  NAME: 'aks-certificates'
  RESOURCE_GROUP_NAME: 'aks-shared-resources'
}
param LOG_ANALYTICS_WORKSPACE_NAME =  'all-logs'
