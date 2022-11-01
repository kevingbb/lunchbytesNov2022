# Full Deployment

Use the ARM or Bicep deployments to deploy the full solution.

## Getting Started

```bash
# Login into Azure CLI
az login

# Check you are logged into the right Azure subscription. Inspect the name field
az account show

# In case not the right subscription
az account set -s <subscription-id>

```

### ARM

Setup some variables to be used for the deployment.

```bash
# Generate a random name
name=ca-$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-5} | head -n 1)
# Set variables for the rest of the demo
resourceGroup=${name}-rg
location=westeurope
containerAppEnv=${name}-env
logAnalytics=${name}-la
appInsights=${name}-ai
storageAccount=$(echo $name | tr -d -)sa
servicebusNamespace=$(echo $name | tr -d -)sb
```

Create the Resource Group where Azure Container Apps will be deployed.

```bash

# Create Resource Group
az group create --name $resourceGroup --location $location -o table
```

```bash
# Deploy Entire Solution
cd /workspaces/lunchbytesNov2022/deploy/arm
az deployment group create \
  -g $resourceGroup \
  --template-file single_deployment_template.json \
  --parameters @single_deployment_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location \
    ServiceBus.NamespaceName=$servicebusNamespace
```

### Bicep (Under Construction)

Setup some variables to be used for the deployment.

```bash
# Generate a random name
name=ca-$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-5} | head -n 1)
# Set variables for the rest of the demo
resourceGroup=${name}-rg
location=westeurope
```

Create the Resource Group where Azure Container Apps will be deployed.

```bash
# Create Resource Group
az group create --name $resourceGroup --location $location -o table
```

```bash
# Deploy Entire Solution
cd /workspaces/lunchbytesNov2022/deploy/bicep
az deployment group create -n lunchbytesnov2022 -g $resourceGroup -f ./single_deployment_template.bicep

# Capture Bicep Output into Variables
containerAppEnv=$(az deployment group show -n lunchbytesnov2022 -g $resourceGroup -o json --query properties.outputs.containerAppEnvName.value -o tsv)
echo $containerAppEnv
logAnalytics=$(az deployment group show -n lunchbytesnov2022 -g $resourceGroup -o json --query properties.outputs.logAnalyticsName.value -o tsv)
echo $logAnalytics
appInsights=$(az deployment group show -n lunchbytesnov2022 -g $resourceGroup -o json --query properties.outputs.appInsightsName.value -o tsv)
echo $appInsights
storageAccount=$(az deployment group show -n lunchbytesnov2022 -g $resourceGroup -o json --query properties.outputs.storageAccountName.value -o tsv)
echo $storageAccount
```

## Cleanup

Deleting the Azure resource group should remove everything associated with this demo.

```bash
az group delete -g $resourceGroup --no-wait -y
```
