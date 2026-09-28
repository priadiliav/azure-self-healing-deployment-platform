<img width="1469" height="330" alt="image" src="https://github.com/user-attachments/assets/ae4c1e2a-71c3-41e7-a487-599273270303" />
A small, rule-based self-healing sample: on a failed-requests alert, a Function App restarts the monitored App Service (with a cooldown to stop restart loops). 

### Used Services
- Azure Function App (Consumption) - HTTP-triggered function (`/api/heal`) that restarts the monitored App Service via ARM
- Azure Storage Account - Function App's own runtime storage (AzureWebJobsStorage) and the restart-cooldown table
- Azure App Service Plan (Y1, Consumption) - hosting plan for the Function App
- Azure Monitor Metric Alert - watches the monitored app's Application Insights for failed requests
- Azure Monitor Action Group - calls the Function App when the alert fires or resolves
- Azure Application Insights + Log Analytics Workspace - monitoring/logging for the Function App itself
- Managed Identity (system-assigned) - grants the Function App rights to restart the monitored App Service, no secrets
- Monitored App Service + Application Insights (existing, not deployed by this project) - the app being healed
