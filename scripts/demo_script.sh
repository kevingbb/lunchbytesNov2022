#!/bin/bash

# Links
#https://github.com/kevingbb/lunchbytesNov2022

# Demo Script

# Setup Variables
name=ca-$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-5} | head -n 1)
echo $name
#name=ca-khqfz
resourceGroup=${name}-rg
location=westeurope
containerAppEnv=${name}-env
logAnalytics=${name}-la
appInsights=${name}-ai
storageAccount=$(echo $name | tr -d -)sa
servicebusNamespace=$(echo $name | tr -d -)sb


# Create Resource Group
az group create --name $resourceGroup --location $location -o table

# Deploy first iteration of the Solution
az deployment group create \
  -g $resourceGroup \
  --template-file v1_template.json \
  --parameters @v1_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location

# Get URLs
storeURL=https://storeapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/store
echo $storeURL
apiURL=https://httpapi.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/Data
echo $apiURL
# Test Endpoints
curl $storeURL && echo ""
curl $apiURL && echo ""
curl -X POST $apiURL?message=test
curl $apiURL && echo ""
curl $storeURL | jq .

# Troubleshoot using out of the box Azure Monitor log integration
workspaceId=$(az monitor log-analytics workspace show -n $logAnalytics -g $resourceGroup --query "customerId" -o tsv)
# Check queuereader first
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'queuereader' and ContainerName_s has 'queuereader' | where Log_s has 'Content' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"
# Check httpapi next
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'httpapi' and ContainerName_s has 'httpapi' | where Log_s has 'Message' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"

# Look at httpapi code
code /workspaces/lunchbytesNov2022/httpapi/Controllers/DataController.cs

# Deploy updated httpapi code via Canary Testing
az deployment group create \
  -g $resourceGroup \
  --template-file v2_template.json \
  --parameters @v2_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location

# Send multiple messages to see canary testing (ie. traffic splitting)
hey -m POST -n 25 -c 1 $apiURL?message=helloagain
curl $apiURL && echo ""
# Check queuereader logs again
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'queuereader' and ContainerName_s has 'queuereader' | where Log_s has 'Message' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"

# Let's setup for autoscaling test, deploy with updated scaling rules
# Also added monitoring api and dashboard
az deployment group create \
  -g $resourceGroup \
  --template-file v3_template.json \
  --parameters @v3_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location

# Get Dashboard UI
dashboardURL=https://dashboardapp.$(az containerapp env show -g $resourceGroup -n ${name}-env --query 'properties.defaultDomain' -o tsv)
echo 'Open the URL in your browser of choice:' $dashboardURL
# Check updated version of the solution (everything should be correct, no traffic splitting)
hey -m POST -n 10 -c 1 $apiURL?message=testscale
curl $apiURL && echo ""

# Run scaling test
cd /workspaces/lunchbytesNov2022/scripts
./appwatch.sh $resourceGroup $apiURL

# Portal Walkthrough
# 1. ACA Environment & Apps
# 2. Azure Monitor Integration (Log Analytics & App Insights)
# 3. Telemetry via DAPR - App Insights App Map

# Clean everything up
az group delete -g $resourceGroup --no-wait -y


az deployment group create \
  -g $resourceGroup \
  --template-file sb_template.json \
  --parameters @sb_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location \
    ServiceBus.NamespaceName=$servicebusNamespace