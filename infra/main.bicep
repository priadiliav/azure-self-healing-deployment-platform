targetScope = 'resourceGroup'

@description('Name of the Function App that runs the self-healing logic.')
param functionAppName string = 'phapp-selfhealer'

@description('Name of the App Service (in this resource group) that the Function App is allowed to heal.')
param appServiceName string = 'phapp-api-dev-kglcsej7bua2e'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the storage account backing the Function App.')
param storageAccountName string = 'st${uniqueString(resourceGroup().id, functionAppName)}'

var appServiceResourceId = resourceId('Microsoft.Web/sites', appServiceName)

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
  name: '${functionAppName}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionAppName}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${functionAppName}-plan'
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
          value: appServiceResourceId
        }
      ]
    }
  }
}

resource healedAppService 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appServiceName
}

@description('Lets the Function App restart the target App Service via ARM (Website Contributor).')
resource healPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(healedAppService.id, functionApp.id, 'de139f84-1756-47ae-9be6-808fbbe84772')
  scope: healedAppService
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772')
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
output healUrl string = 'https://${functionApp.properties.defaultHostName}/api/heal'
