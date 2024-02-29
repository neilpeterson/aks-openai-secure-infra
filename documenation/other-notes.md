## CSI Testing

## Jump Box Configuration

### Install AZ CLI on Jump Box
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

### Install Kubectl on Jump Box
sudo az aks install-cli

### Remote commands to private AKS cluster
az aks command invoke --resource-group aks-cluster-one --name aks-test-001 --command "kubectl get pods -n kube-system"

### Add internal load balancer
k apply -f ./traefik-ingress.yaml

### Attache to POD and list environmetn variables
kubectl exec --stdin --tty nginx-deployment-86dcfdf4c6-dzm7h -- /bin/bash
> printenv


