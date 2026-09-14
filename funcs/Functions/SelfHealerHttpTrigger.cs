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
}