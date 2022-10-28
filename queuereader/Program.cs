using Dapr;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

// Add additional services
builder.Services.AddHttpClient();
builder.Services.AddSingleton<Store>();

var app = builder.Build();

// Dapr will send serialized event object vs. being raw CloudEvent
app.UseCloudEvents();

// needed for Dapr pub/sub routing
app.MapSubscribeHandler();

if (app.Environment.IsDevelopment()) {app.UseDeveloperExceptionPage();}

// Dapr subscription in [Topic] routes orders topic to this route
app.MapPost("/message", [Topic("servicebus-pubsub", "orders")] async (ILogger<Program> logger, HttpClient httpClient, [FromServices] Store store, Message receivedMessage) => {
    try {
        logger.LogInformation($"Content Received: '{receivedMessage.message}'");
        // string messageId = Guid.NewGuid().ToString();
        CancellationTokenSource source = new CancellationTokenSource();
        CancellationToken cancellationToken = source.Token;
        await httpClient.PostAsync(store.getStoreUrl(), JsonContent.Create(new { message = receivedMessage.message }), cancellationToken);
    }
    catch (Exception exc){
        logger.LogError($"Content Received Error: {exc.Message}");
    }

    return Results.Ok();
});

await app.RunAsync();

internal record Message([property: JsonPropertyName("message")] string message);

public class Store
{
    /// <summary>
    /// Gets the URL for the orders app.
    /// </summary>
    /// <returns></returns>
    public Uri getStoreUrl()
    {
        string daprPort = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3500";
        string targetApp = Environment.GetEnvironmentVariable("TARGET_APP") ?? "storeapp";

        if (string.IsNullOrEmpty(daprPort))
        {
            throw new ArgumentNullException("'DaprPort' config value is required. Please add an environment variable or app setting.");
        }

        if (string.IsNullOrEmpty(targetApp))
        {
            throw new ArgumentNullException("'TargetApp' config value is required. Please add an environment variable or app setting.");
        }

        Uri storeUrl = new Uri($"http://localhost:{daprPort}/v1.0/invoke/{targetApp}/method/store");

        return storeUrl;
    }
}