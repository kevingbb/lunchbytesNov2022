#!/bin/bash

# Links
#https://github.com/kevingbb/lunchbytesNov2022

# Demo Script

# Setup Variables
name=ca-$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-5} | head -n 1)
echo $name
#name=ca-sbzwu
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
    Location=$location \
    ServiceBus.NamespaceName=$servicebusNamespace

# Get URLs
storeURL=https://storeapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/store
echo $storeURL
storeCountURL=https://storeapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/count
echo $storeCountURL
apiURL=https://httpapi.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/Data
echo $apiURL
# Test Endpoints
curl $storeURL && echo ""
curl $storeCountURL | jq .
curl -X POST $apiURL?message=test
curl $storeCountURL | jq .
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
    Location=$location \
    ServiceBus.NamespaceName=$servicebusNamespace

# Send multiple messages to see canary testing (ie. traffic splitting)
hey -m POST -n 25 -c 1 $apiURL?message=hello
# Check queuereader logs again
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'queuereader' and ContainerName_s has 'queuereader' | where Log_s has 'Content' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"
# Check Store URL
curl $storeURL | jq .

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
    Location=$location \
    ServiceBus.NamespaceName=$servicebusNamespace

# Get Dashboard UI
dashboardURL=https://dashboardapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)
echo 'Open the URL in your browser of choice:' $dashboardURL
# Get Dashboard API
dashboardAPIURL=https://dashboardapi.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)
echo $dashboardAPIURL
# Check updated version of the solution (everything should be correct, no traffic splitting)
hey -m POST -n 10 -c 1 $apiURL?message=testscale01
curl $storeURL | jq . | grep -i testscale01
curl $dashboardAPIURL/queue && echo ""

# Run scaling test
cd /workspaces/lunchbytesNov2022/scripts
./appwatch.sh $resourceGroup $apiURL $dashboardAPIURL/queue

# Portal Walkthrough
# 1. ACA Environment & Apps
# 2. Azure Monitor Integration (Log Analytics & App Insights)
# 3. Telemetry via DAPR - App Insights App Map

# Clean everything up
az group delete -g $resourceGroup --no-wait -y



# Local Dapr Setup (open in new terminal window)
# Setup Dapr Components
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
    value: ""
# Azure Tables State Store
vi ~/.dapr/components/azuretables-statestore.yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: azuretables-state
spec:
  type: state.azure.tablestorage
  version: v1
  metadata:
  - name: accountName
    value: ""
  - name: accountKey
    value: ""
  - name: tableName
    value: "store"
# Run Applications with Dapr
cd /workspaces/lunchbytesNov2022/storeapp
dapr run --app-id storeapp --app-port 3000 --dapr-http-port 3602 -- node app.js
cd /workspaces/lunchbytesNov2022/queuereader
dapr run --app-id queuereader --app-port 8090 --dapr-http-port 3601 -- dotnet run
cd /workspaces/lunchbytesNov2022/httpapi
dapr run --app-id httpapi --app-port 8080 --dapr-http-port 3600 -- dotnet run
cd /workspaces/lunchbytesNov2022/httpapi
dapr run --app-id ca-operational-api --app-port 5000 --dapr-http-port 3603 -- python app.py

# Local Endpoints for Debugging
# Store
curl http://localhost:3000/store && echo ""
curl http://localhost:3000/store | jq .
curl http://localhost:3000/store/ff0ce67c-107e-411b-97a6-437c01173303 | jq .
curl http://localhost:3000/count && echo ""
curl http://localhost:3000/count | jq .
# Queue Reader
curl http://localhost:8090/count && echo ""
# HTTP API
curl http://localhost:8080/data && echo ""
curl -X POST http://localhost:8080/data?message=test14
curl -X POST http://localhost:8080/data
# Dashboard API
curl http://localhost:5000/orders | jq .
curl http://localhost:5000/queue && echo ""
