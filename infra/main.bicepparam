using 'main.bicep'

param functionAppName = 'phapp-selfhealer'
param appServiceName = 'phapp-api-dev-kglcsej7bua2e'

// TODO: set this to the name of the Application Insights resource that monitors
// phapp-api-dev-kglcsej7bua2e (the app being healed) - not the healer's own App Insights.
param monitoredAppInsightsName = '<fill-in-monitored-app-insights-name>'
