using 'main.bicep'

param functionAppName = 'phapp-selfhealer'
param storageAccountName = 'phappselfhealersa'
param workspaceName = 'phapp-selfhealer-law'
param applicationInsightsName = 'phapp-selfhealer-ai'
param hostingPlanName = 'phapp-selfhealer-plan'
param actionGroupName = 'phapp-selfhealer-ag'

param monitoredResourceGroup = 'phapp-rg'
param monitoredAppServiceName = 'phapp-api-dev-kglcsej7bua2e'
param monitoredAppInsightsName = 'phapp-appi-dev-kglcsej7bua2e'
