using 'main.bicep'

param functionAppName = 'phapp-selfhealer'
param storageAccountName = 'phapp-selfhealer-sa'
param workspaceName = 'phapp-selfhealer-law'
param applicationInsightsName = 'phapp-selfhealer-ai'
param hostingPlanName = 'phapp-selfhealer-plan'
param actionGroupName = 'phapp-selfhealer-ag'

param monitoredResourceGroup = '<fill-in-monitored-resource-group>'
param monitoredAppServiceName = '<fill-in-monitored-app-service-name>'
param monitoredAppInsightsName = '<fill-in-monitored-app-insights-name>'
