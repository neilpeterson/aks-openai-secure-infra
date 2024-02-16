# Create cluster admins group
az ad group create --display-name 'aks-admins' --mail-nickname 'aks-admins' --description "Principals in this group are AKS admins" --query id -o tsv

# Create AD user if needed
az ad user create --display-name=aks-cluster-admin --user-principal-name aks-cluster-admin@nepeters.onmicrosoft.com --force-change-password-next-sign-in --password ''

# Add user to cluster admin group
az ad group member add -g aks-admin --member-id 6f6a0824-2d7e-4380-bbfa-6846edb74401

# Create namespace reader group
az ad group create --display-name 'aks-namespace-reader' --mail-nickname 'aks-namespace-reader' --description "Principals in this group can read a specified namespace" --query id -o tsv

# Deploy AKS network
az group create --name aks-cluster-001 --location eastus
az deployment group create --template-file ./aks-networking.bicep -g aks-cluster-001

# Get network id
az network vnet list -g aks-cluster-001 --query [].id -o tsv

# Deploy ACR and ALA
az deployment group create --template-file ./container-regisry.bicep -g aks-cluster-001

# Stage boot critical images in ACR
az acr import --source ghcr.io/kubereboot/kured:1.14.0 -n sceacr