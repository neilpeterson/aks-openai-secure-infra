using '../../cluster-deployment/hub-network.bicep'

param LOG_ANALYTICS_WORKSPACE_NAME  = 'hub-network-logs'

param HUB_VIRTUAL_NETWORK = {
  NAME:                   'aks-hub-network'
  ADDRESS_SPACE:          ['10.200.0.0/24']
  SUBNET_NAME_FIREWALL:   'AzureFirewallSubnet'
  SUBNET_RANGE_FIREWALL:  '10.200.0.0/26'
  SUBNET_RANGE_BASTION:   '10.200.0.128/26' // Subnet name is predetermined and hard coded.
}

param BASTION = {
  NAME:             'aks-bastion'
  NSG_NAME:         'aks-bastion'
  PUBLIC_IP_NAME:   'aks-bastion-ip'
  PUBLIC_IP_SKU:    'Standard'
}
