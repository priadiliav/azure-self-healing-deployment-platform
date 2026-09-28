targetScope = 'resourceGroup'

@description('Name of the App Service to grant permission on, in this module\'s target resource group.')
param appServiceName string

@description('Principal ID of the identity to grant Website Contributor on the App Service.')
param principalId string

resource appService 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appServiceName
}

resource healPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appService.id, principalId, 'de139f84-1756-47ae-9be6-808fbbe84772')
  scope: appService
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772')
  }
}
