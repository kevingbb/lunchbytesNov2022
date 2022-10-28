#!/bin/bash

# Links
#https://github.com/kevingbb/lunchbytesNov2022

# Demo Script

# Setup Variables
name=ca-$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-5} | head -n 1)
echo $name
#name=ca-sdlrr
resourceGroup=${name}-rg
location=westeurope
containerAppEnv=${name}-env
logAnalytics=${name}-la
appInsights=${name}-ai
storageAccount=$(echo $name | tr -d -)sa
#servicebusNamespace=$(echo $name | tr -d -)sb
servicebusNamespace=khsbdaprdemotest03


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
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'queuereader' and ContainerName_s has 'queuereader' | where Log_s has 'Message' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"
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
    ServiceBus.NamespaceName=khsbdaprdemotest03

Endpoint=sb://khsbdaprdemotest03.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=kA9bnWx0TdiPyGHQCIegnfTAaT0cOY+cHE4ZNbZfdAk=
DefaultEndpointsProtocol=https;AccountName=casdlrrsa;AccountKey=IHT3FZa8Zj23YNle9GkogwCQE4GZxANyGpHaYUUBog+jFB2lOhQU58Ux/VComHRoFVu5f6TNoRST+AStVj7zYw==;EndpointSuffix=core.windows.net
cd /workspaces/lunchbytesNov2022/httpapi
dotnet add package Dapr.AspNetCore
dotnet add package Azure.Messaging.ServiceBus
dotnet add package Azure.Storage.Blobs

dapr run --app-id storeapp --app-port 3000 --dapr-http-port 3602 -- node app.js
dapr run --app-id queuereader --app-port 8090 --dapr-http-port 3601 -- dotnet run
dapr run --app-id httpapi --app-port 8080 --dapr-http-port 3600 -- dotnet run
dapr run --app-id ca-operational-api --app-port 5000 --dapr-http-port 3603 -- python app.py

dapr publish --publish-app-id httpapi --pubsub pubsub --topic orders --data 'Hello!'

curl http://localhost:8080/data && echo ""
curl -X POST http://localhost:8080/data?message=test00
curl -X POST http://localhost:8080/data
curl http://localhost:3000/store && echo ""
curl http://localhost:3000/store | jq .
curl http://localhost:3000/store/ff0ce67c-107e-411b-97a6-437c01173303 | jq .
curl http://localhost:3000/store/count && echo ""
curl http://localhost:3000/store/count | jq .
curl http://localhost:5000/orders | jq .
curl http://localhost:5000/queue && echo ""

hey -m POST -n 100 -c 10 http://localhost:8080/data?message=heytest

vi ~/.dapr/components/servicebus-pubsub.yaml

apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: servicebus-pubsub
spec:
  type: pubsub.azure.servicebus
  version: v1
  metadata:
  - name: connectionString # Required when not using Azure Authentication.
    value: "Endpoint=sb://khsbdaprdemotest03.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=kA9bnWx0TdiPyGHQCIegnfTAaT0cOY+cHE4ZNbZfdAk="

vi ~/.dapr/components/azureblobs-statestore.yaml

DefaultEndpointsProtocol=https;AccountName=casdlrrsa;AccountKey=IHT3FZa8Zj23YNle9GkogwCQE4GZxANyGpHaYUUBog+jFB2lOhQU58Ux/VComHRoFVu5f6TNoRST+AStVj7zYw==;EndpointSuffix=core.windows.net

apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: azureblobs-state
spec:
  type: state.azure.blobstorage
  version: v1
  metadata:
  - name: accountName
    value: "casdlrrsa"
  - name: accountKey
    value: "IHT3FZa8Zj23YNle9GkogwCQE4GZxANyGpHaYUUBog+jFB2lOhQU58Ux/VComHRoFVu5f6TNoRST+AStVj7zYw=="
  - name: containerName
    value: "store"

[
  {
    "key": "",
    "value": ""
  }
]

