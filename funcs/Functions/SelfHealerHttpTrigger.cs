using System.Text.Json;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.AppService;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace funcs.Functions;

public class SelfHealerHttpTrigger(
    ILogger<SelfHealerHttpTrigger> logger)
{
    [Function("SelfHealerHttpTrigger")]
    public async Task<IActionResult> Run(
        [HttpTrigger(
            AuthorizationLevel.Function,
            "post",
            Route = "heal")]
        HttpRequest req)
    {
        // Azure Monitor action groups call this URL both when an alert fires and when it
        // resolves (Common Alert Schema, data.essentials.monitorCondition). Only restart
        // on "Fired" - a resolved notification means the problem is already gone.
        var monitorCondition = await TryGetMonitorConditionAsync(req);
        if (monitorCondition == "Resolved")
        {
            logger.LogInformation("Ignoring alert callback with monitorCondition=Resolved");
            return new OkObjectResult(new { Message = "Alert resolved, no action taken" });
        }

        var credential = new DefaultAzureCredential();
        
        var armClient = new ArmClient(credential);
        
        var resourceId = new ResourceIdentifier(
            Environment.GetEnvironmentVariable(
                "APP_SERVICE_RESOURCE_ID")!);

        var webApp = armClient
            .GetWebSiteResource(resourceId);

        logger.LogInformation(
            "Restarting App Service {ResourceId}",
            resourceId);

        await webApp.RestartAsync();
        
        return new OkObjectResult(new
        {
            Message = "App Service restart requested",
            ResourceId = resourceId.ToString()
        });
    }

    private static async Task<string?> TryGetMonitorConditionAsync(HttpRequest req)
    {
        if (req.ContentLength is null or 0)
        {
            return null;
        }

        try
        {
            using var document = await JsonDocument.ParseAsync(req.Body);
            if (document.RootElement.TryGetProperty("data", out var data) &&
                data.TryGetProperty("essentials", out var essentials) &&
                essentials.TryGetProperty("monitorCondition", out var monitorCondition))
            {
                return monitorCondition.GetString();
            }
        }
        catch (JsonException)
        {
            // Not a Common Alert Schema payload (e.g. a manual test call) - fall through and heal.
        }

        return null;
    }
}