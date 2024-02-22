# Create cluster admins group
az ad group create --display-name 'aks-admins' --mail-nickname 'aks-admins' --description "Principals in this group are AKS admins" --query id -o tsv

# Create AD user if needed
az ad user create --display-name=aks-cluster-admin --user-principal-name aks-cluster-admin@nepeters.onmicrosoft.com --force-change-password-next-sign-in --password ''

# Add user to cluster admin group
az ad group member add -g aks-admin --member-id 6f6a0824-2d7e-4380-bbfa-6846edb74401

# Create namespace reader group
az ad group create --display-name 'aks-namespace-reader' --mail-nickname 'aks-namespace-reader' --description "Principals in this group can read a specified namespace" --query id -o tsv

## Deploy Hub Network
az group create --name aks-hub-network --location eastus
az deployment group create --template-file ./cluster-deployment/hub-network.bicep -g aks-hub-network

## Deploy jumpbox
az group create --name aks-jump-box --location eastus
az deployment group create --template-file ./cluster-deployment/jump-box.bicep -g aks-jump-box

## Deploy spoke network
az group create --name aks-cluster-001 --location eastus
az deployment group create --template-file ./cluster-deployment/spoke-network-and-acr.bicep -g aks-cluster-001

## Deoply AKS
az deployment group create --template-file ./cluster-deployment/aks-cluster.bicep -g aks-cluster-001

# Install AZ CLI on Jump Box
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Kubectl on Jump Box
sudo az aks install-cli

# Test ACR Build
az acr import --source ghcr.io/kubereboot/kured:1.14.0 -n scecontainerregistry

# Remote commands to private AKS cluster
az aks command invoke --resource-group aks-cluster-001 --name aks-test-001 --command "kubectl get pods -n kube-system"


