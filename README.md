# Lunch Bytes November 2022 - Hands-on with Container Apps

The purpose of this repo is to help you quickly get hands-on with Container Apps. It is meant to be consumed either through GitHub codespaces or through a local VS Code Dev Container. The idea being that everything you need from tooling to runtimes is already included in the Dev Container so it should be as simple as executing a run command.

## Scenario

As a retailer, you want your customers to place online orders, while providing them the best online experience. This includes an API to receive orders that is able to scale out and in based on demand. You want to asynchronously store and process the orders using a queing mechanism that also needs to be auto-scaled. With a microservices architecture, Container Apps offer a simple experience that allows your developers focus on the services, and not infrastructure.

In this sample you will see how to:

1. Deploy the solution and configuration through IaaC, no need to understand Kubernetes
2. Ability to troubleshoot using built-in logging capability with Azure Monitor (Log Analytics)
3. Ability to split http traffic when deploying a new version
4. Ability to configure scaling to meet usage needs
5. Out of the box Telemetry with Dapr + Azure Monitor (Log Analytics)

![Image of sample application architecture and how messages flow through queue into store](/images/th-arch.png)

### Pre-requisites

There are two options:

1. [Access to GitHub Codespaces](#getting-started-via-codespaces)
1. [VS Code + Local Dev Container](#getting-started-via-vs-code-and-local-dev-container)

### Getting Started

You will need to install an Azure CLI extension to work with Azure Container Apps.

Run the following command.

```bash
az extension add --name containerapp
```

We will be using the `hey` load testing tool later on. If you are using Codespaces or VS Code Dev Containers then `hey` is already installed.

If you are using an environment other than Codespaces or VS Code Dev Containers, you can find installation instructions for `hey` here - [https://github.com/rakyll/hey](https://github.com/rakyll/hey)

Optional -  if using Codespaces or not logged into Azure CLI

```bash
# Login into Azure CLI
az login

# Check you are logged into the right Azure subscription. Inspect the name field
az account show

# In case not the right subscription
az account set -s <subscription-id>
```

Setup some variables to be used throughout the walkthrough.

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
```

Create the Resource Group where Azure Container Apps will be deployed.

```bash
# Create Resource Group
az group create --name $resourceGroup --location $location -o table
```

### Setup Solution in Single Deployment

If you are not interested in following the story, and just want to deploy the final solution, then check out the [deploy](deploy/README.md) folder for ARM and Bicep deployments and skip the rest.

### Follow Story and Deploy initial version of the application

We'll deploy the first version of the application to Azure. This typically takes around 3 to 5 minutes to complete.

```bash
az deployment group create \
  -g $resourceGroup \
  --template-file v1_template.json \
  --parameters @v1_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location
```

Now the application is deployed, let's determine the URL we'll need to use to access it and store that in a variable for convenience

```bash
# Get URLs
storeURL=https://storeapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/store
echo $storeURL
apiURL=https://httpapi.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)/Data
echo $apiURL
```

Let's see what happens if we call the URL of the store with curl.

> Alternatively, you can run `echo $storeURL` to get the URL for the application and then open that in a browser.

```bash
# Test Endpoints
curl $storeURL && echo ""
curl $apiURL && echo ""
curl -X POST $apiURL?message=test
curl $apiURL && echo ""
curl $storeURL | jq .
```

The response you see has a message, but it is not the right one. Something's not working, but what?

ContainerApps integrates with Application Insights and Log Analytics out of the box, no configuration required. You can either go to the Azure Portal -> the Log Analytics workspace in the resource group we're using for this demo and run the following query to view the logs for the `queuereader` application, or you can run it via the command line so you don't have to leave your IDE.

```text
ContainerAppConsoleLogs_CL
| where ContainerAppName_s has "queuereader" and ContainerName_s has "queuereader"
| where Log_s has 'Message'
| project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s
| order by TimeGenerated desc
```

Alternatively, if you prefer to stay in the CLI, you can run the Log Analytics query from there.

```bash
# Troubleshoot using out of the box Azure Monitor log integration
workspaceId=$(az monitor log-analytics workspace show -n $logAnalytics -g $resourceGroup --query "customerId" -o tsv)
# Check queuereader first
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'queuereader' and ContainerName_s has 'queuereader' | where Log_s has 'Message' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"
```

You should see a number of log file entries which will contain a similar message. You should see something like the following:

> "Log_s": "      Message ID: '0df9b2e0-7d94-4ac4-8870-bff035dee20d', contents: '8febea3b-b373-49ba-8fb6-54843cbe7b52'",

```bash
# Check httpapi next
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'httpapi' and ContainerName_s has 'httpapi' | where Log_s has 'Message' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"
```

You should see a number of log file entries which will contain a similar message. You should see something like the following:

> "Log_s": "      Message Contents: 'TODO: MISSING'",

```bash
# Look at httpapi code
code /workspaces/lunchbytesNov2022/httpapi/Controllers/DataController.cs
```

Ok, that's something but that's not the message we sent. Let's take a look at the application code

**DataController.cs**

```c#
...
  [HttpPost]
  public async Task PostAsync()
  {
      try
      {
          CancellationTokenSource source = new CancellationTokenSource();
          CancellationToken cancellationToken = source.Token;
          // TODO: Replace with Message from querystring.
          var pubsubMessage = new Message (Guid.NewGuid().ToString());
          //Using Dapr SDK to publish a topic
          await daprClient.PublishEventAsync(PUBSUB_NAME, TOPIC_NAME, pubsubMessage , cancellationToken);
          logger.LogInformation($"Message Contents: 'TODO: MISSING'");
          Ok();
      }
...
```

It looks like the code is set to send a GUID, not the message itself. Must have been something the developer left in to test things out. Let's modify that code:

**DataController.cs** (version 2)

```c#
  [HttpPost]
  public async Task PostAsync(string message)
  {
      try
      {
          CancellationTokenSource source = new CancellationTokenSource();
          CancellationToken cancellationToken = source.Token;
          var pubsubMessage = new Message (DateTimeOffset.Now.ToString() + " -- " + message);
          //Using Dapr SDK to publish a topic
          await daprClient.PublishEventAsync(PUBSUB_NAME, TOPIC_NAME, pubsubMessage , cancellationToken);
          logger.LogInformation($"Message Contents: '{message}'");
          Ok();
      }
```

We've fixed the code so that the message received is now actually being sent and we've packaged this up into a new container ready to be redeployed.

But maybe we should be cautious and make sure this new change is working as expected. Let's perform a controlled rollout of the new version and split the incoming network traffic so that only 20% of requests will be sent to the new version of the application.

To implement the traffic split, the following has been added to the deployment template

```json
  "ingress": {
      "external": true,
      "targetPort": 80,
      "traffic":[
          {
              "revisionName": "[concat('httpapi--', parameters('ContainerApps.HttpApi.CurrentRevisionName'))]",
              "weight": 80
          },
          {
              "latestRevision": true,
              "weight": 20
          }
      ]
```

Effectively, we're asking for 80% of traffic to be sent to the current version (revision) of the application and 20% to be sent to the new version that's about to be deployed.

### Deploy fixed version of httpapi with 80/20 traffic splitting

We'll repeat the deployment command from earlier, but we've updated our template to use version 2 of the queuereader application.

```bash
az deployment group create \
  -g $resourceGroup \
  --template-file v2_template.json \
  --parameters @v2_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location
```

Let's check that the new version resolved the issue.

```bash
# Send multiple messages to see canary testing (ie. traffic splitting)
hey -m POST -n 25 -c 1 $apiURL?message=hello
```

Now let's see what happens if we access that URL

``` bash
# Check Store URL
curl $storeURL | jq

# Check queuereader logs
az monitor log-analytics query -w $workspaceId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s has 'queuereader' and ContainerName_s has 'queuereader' | where Log_s has 'Message' | project TimeGenerated, ContainerAppName_s, ContainerName_s, Log_s | order by TimeGenerated desc"
```

```json
[
  {
    "id": "b205d410-5150-4ac6-9e26-7079ebcae67b",
    "message": "a39ecc22-cece-4442-851e-25d7329a1f55"
  },
  {
    "id": "318e72bb-8c55-486c-99ec-18a5bd76bc1d",
    "message": "10/26/2022 13:28:33 +00:00 -- hello"
  }
]
```

That's looking better. We can still see the original message, but we can also now see our "test" message with the date and time appended to it.

We configured traffic splitting, so let's see that in action. First we will need to send multiple messages to the application. We can use the load testing tool `hey` to do that.

So, is our app ready for primetime now? Let's change things so that the new app is now receiving all of the traffic, plus we'll also setup some scaling rules. This will allow the container apps to scale up when things are busy, and scale to zero when things are quiet.

## Deploy autoscaling version with rules

One final time, we'll now deploy the new configuration with scaling configured. We will also add a simple api and dashboard for monitoring the messages flow.

```bash
az deployment group create \
  -g $resourceGroup \
  --template-file v3_template.json \
  --parameters @v3_parameters.json \
  --parameters ContainerApps.Environment.Name=$containerAppEnv \
    LogAnalytics.Workspace.Name=$logAnalytics \
    AppInsights.Name=$appInsights \
    StorageAccount.Name=$storageAccount \
    Location=$location
```

First, let's look at the new Dashboard.

```bash
# Get Dashboard UI
dashboardURL=https://dashboardapp.$(az containerapp env show -g $resourceGroup -n $containerAppEnv --query 'properties.defaultDomain' -o tsv)
echo 'Open the URL in your browser of choice:' $dashboardURL

# Check updated version of the solution (everything should be correct, no traffic splitting)
hey -m POST -n 10 -c 1 $apiURL?message=testscale

# Let's check the number of orders in the queue
curl $apiURL && echo ""

# Check Store URL
curl $storeURL | jq . | grep testscale
```

Now let's see scaling in action. To do this, we will generate a large amount of messages which should cause the applications to scale up to cope with the demand. To demonstrate this, a script that uses the `tmux` command is provided in the `scripts` folder of this repository. Run the following commands:

```bash
cd scripts
./appwatch.sh $resourceGroup $apiURL
```

This will split your terminal into four separate views.

* On the left, you will see the output from the `hey` command. It's going to send 10,000 requests to the application, so there will be a short delay, around 20 to 30 seconds, whilst the requests are sent. Once the `hey` command finishes, it should report its results.
* On the right at the top, you will see a list of the container app versions (revisions) that we've deployed. One of these will be the latest version that we just deployed. As `hey` sends more and more messages, you should notice that one of these revisions of the app starts to increase its replica count
* Also on the right, in the middle, you should see the current count of messages in the queue. This will increase to 10,000 and then slowly decrease as the app works it way through the queue.

Once `hey` has finished generating messages, the number of instances of the HTTP API application should start to scale up and eventually max out at 10 replicas. After the number of messages in the queue reduces to zero, you should see the number of replicas scale down and return to 1.

> Tip! To exit from tmux when you're finished, type `CTRL-b`, then `:` and then the command `kill-session`

### Cleanup

Deleting the Azure resource group should remove everything associated with this demo.

```bash
az group delete -g $resourceGroup --no-wait -y
```

## Contributors

* Kevin Harris - kevin.harris@microsoft.com
* Mahmoud El Zayet - mahmoud.elzayet@microsoft.com
* Mark Whitby - mark.whitby@microsft.com
