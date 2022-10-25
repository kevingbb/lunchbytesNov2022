param Location string = resourceGroup().location
param Name string = uniqueString(resourceGroup().id)
param StorageAccount_Name string = take(toLower('st${Name}'),24)
param LogAnalytics_Workspace_Name string = 'log-${Name}'
param AppInsights_Name string = 'ai-${Name}'
param ContainerApps_Environment_Name string = 'env-${Name}'
param ContainerApps_HttpApi_CurrentRevisionName string
param ContainerApps_HttpApi_NewRevisionName string

var StorageAccount_ApiVersion = '2018-07-01'
var StorageAccount_Queue_Name = 'demoqueue'
var ContainerApps_Environment_Id = ContainerApps_Environment.id

resource StorageAccount 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: StorageAccount_Name
  location: Location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource StorageAccount_Name_default_StorageAccount_Queue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-01-01' = {
  name: '${StorageAccount_Name}/default/${StorageAccount_Queue_Name}'
  properties: {
    metadata: {
    }
  }
  dependsOn: [
    StorageAccount
  ]
}

resource log 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: LogAnalytics_Workspace_Name
  location: Location
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource AppInsights 'Microsoft.Insights/Components@2020-02-02' = {
  name: AppInsights_Name
  location: Location
  properties: {
    ApplicationId: AppInsights_Name
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'CustomDeployment'
  }
}

resource ContainerApps_Environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: ContainerApps_Environment_Name
  location: Location
  tags: {
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId : log.properties.customerId
        sharedKey: listKeys(log.id, '2015-03-20').primarySharedKey
      }
    }
    daprAIInstrumentationKey: reference(AppInsights.id, '2020-02-02', 'Full').properties.InstrumentationKey
  }
}

resource queuereader 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'queuereader'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name};AccountKey=${listKeys(StorageAccount.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: true
        appId: 'queuereader'
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/queuereader:v0.1'
          name: 'queuereader'
          env: [
            {
              name: 'QueueName'
              value: 'demoqueue'
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
            {
              name: 'TargetApp'
              value: 'storeapp'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
        rules: [
          {
            name: 'myqueuerule'
            custom: {
              type: 'azure-queue'
              metadata: {
                queueName: 'demoqueue'
                queueLength: '10'
              }
              auth: [
                {
                  secretRef: 'queueconnection'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource dashboardapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'dashboardapp'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      dapr: {
        enabled: true
        appId: 'dashboardapp'
        appProcotol: 'http'
        appPort: 80
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/ca-operational-dashboard:v0.1'
          name: 'dashboardapp'
          env: [
            {
              name: 'REACT_APP_API'
              value: 'dashboardapi'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: []
      }
    }
  }
}

resource dashboardapi 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'dashboardapi'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
      }
      dapr: {
        enabled: true
        appId: 'dashboardapi'
        appProcotol: 'http'
        appPort: 5000
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/ca-operational-api:v0.1'
          name: 'dashboardapi'
          env: [
            {
              name: 'DAPR_HTTP_PORT'
              value: '3500'
            }
            {
              name: 'TARGET_APP'
              value: 'storeapp'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: []
      }
    }
  }
}

resource storeapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'storeapp'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
      }
      dapr: {
        enabled: true
        appId: 'storeapp'
        appProcotol: 'http'
        appPort: 3000
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/storeapp:v0.1'
          name: 'storeapp'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: []
      }
    }
  }
}

resource httpapi 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'httpapi'
  kind: 'containerapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: 80
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name};AccountKey=${listKeys(StorageAccount.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: true
        appId: 'httpapi'
        appProcotol: 'http'
        appPort: 80
      }
    }
    template: {
      revisionSuffix: ContainerApps_HttpApi_NewRevisionName
      containers: [
        {
          image: 'kevingbb/httpapi:v0.2'
          name: 'httpapi'
          env: [
            {
              name: 'QueueName'
              value: 'demoqueue'
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'httpscalingrule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}
