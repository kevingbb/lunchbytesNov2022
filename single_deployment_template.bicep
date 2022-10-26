param Location string = resourceGroup().location
param Name string = uniqueString(resourceGroup().id)
param StorageAccount_Name string = take(toLower('st${Name}'),24)
param LogAnalytics_Workspace_Name string = 'log-${Name}'
param AppInsights_Name string = 'ai-${Name}'
param ContainerApps_Environment_Name string = 'env-${Name}'
param ContainerApps_HttpApi_CurrentRevisionName string = ''
param ContainerApps_HttpApi_NewRevisionName string =  toLower(utcNow())

var StorageAccount_Queue_Name = 'demoqueue'
var StorageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource StorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
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
  
  resource default 'queueServices' = {
    name: 'default'
    resource queue 'queues' = {
      name: StorageAccount_Queue_Name
    }
  }
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

resource AppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: AppInsights_Name
  location: Location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'CustomDeployment'
  }
}

resource AcaEnv 'Microsoft.App/managedEnvironments@2022-06-01-preview' = {
  name: ContainerApps_Environment_Name
  location: Location
  sku: {
    name: 'Consumption'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId : log.properties.customerId
        sharedKey: log.listKeys().primarySharedKey
      }
    }
    daprAIInstrumentationKey: AppInsights.properties.InstrumentationKey
  }
}

resource queuereader 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'queuereader'
  location: Location
  properties: {
    managedEnvironmentId: AcaEnv.id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'queueconnection'
          value: StorageAccountConnectionString
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

resource dashboardapp 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'dashboardapp'
  location: Location
  properties: {
    managedEnvironmentId: AcaEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      dapr: {
        enabled: true
        appId: 'dashboardapp'
        appProtocol: 'http'
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

resource dashboardapi 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'dashboardapi'
  location: Location
  properties: {
    managedEnvironmentId: AcaEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
      }
      dapr: {
        enabled: true
        appId: 'dashboardapi'
        appProtocol: 'http'
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

resource storeapp 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'storeapp'
  location: Location
  properties: {
    managedEnvironmentId: AcaEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
      }
      dapr: {
        enabled: true
        appId: 'storeapp'
        appProtocol: 'http'
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

resource httpapi 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'httpapi'
  location: Location
  properties: {
    managedEnvironmentId: AcaEnv.id
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
          value: StorageAccountConnectionString
        }
      ]
      dapr: {
        enabled: true
        appId: 'httpapi'
        appProtocol: 'http'
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

output Location string = Location
output ContainerAppEnvName string = AcaEnv.name
output LogAnalyticsName string = log.name
output AppInsightsName string = AppInsights.name
output StorageAccountName string = StorageAccount.name
