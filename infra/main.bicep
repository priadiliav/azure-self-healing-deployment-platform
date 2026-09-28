targetScope = 'resourceGroup'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Function App that runs the self-healing logic.')
param functionAppName string

@description('Name of the storage account backing the Function App.')
param storageAccountName string

@description('Name of the Log Analytics workspace for the Function App.')
param workspaceName string

@description('Name of the Application Insights resource for the Function App.')
param applicationInsightsName string

@description('Name of the Action Group that triggers the self-healing Function App.')
param actionGroupName string

@description('Name of the hosting plan for the Function App.')
param hostingPlanName string

@description('Resource group of the monitored App Service, if different from this deployment\'s resource group.')
param monitoredResourceGroup string

@description('Name of the App Service that is being monitored and healed by this Function App.')
param monitoredAppServiceName string

@description('Name of the Application Insights resource for the monitored app (the one we heal) - NOT this Function App\'s own App Insights.')
param monitoredAppInsightsName string


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: false
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v10.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'APP_SERVICE_RESOURCE_ID'
          value: resourceId('Microsoft.Web/sites', monitoredAppServiceName)
        }
      ]
    }
  }
}

module healPermission 'modules/appServiceRoleAssignment.bicep' = {
  name: 'healPermission'
  scope: resourceGroup(monitoredResourceGroup)
  params: {
    appServiceName: monitoredAppServiceName
    principalId: functionApp.identity.principalId
  }
}

resource monitoredAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: monitoredAppInsightsName
  scope: resourceGroup(monitoredResourceGroup)
}


var healFunctionUrl = 'https://${functionApp.properties.defaultHostName}/api/heal?code=${listKeys('${functionApp.id}/host/default', '2023-12-01').functionKeys.default}'
var healFunctionName = 'SelfHealerHttpTrigger'

resource healActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: 'selfheal'
    enabled: true
    azureFunctionReceivers: [
      {
        name: 'restart-app-service'
        functionAppResourceId: functionApp.id
        functionName: healFunctionName
        httpTriggerUrl: healFunctionUrl
        useCommonAlertSchema: true
      }
    ]
  }
}

resource failedRequestsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${monitoredAppServiceName}-failed-requests-alert'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [
      monitoredAppInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailedRequests'
          metricName: 'requests/failed'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: healActionGroup.id
      }
    ]
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
output healUrl string = 'https://${functionApp.properties.defaultHostName}/api/heal'
output healActionGroupId string = healActionGroup.id
