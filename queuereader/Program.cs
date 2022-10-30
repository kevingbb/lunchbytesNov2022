using Dapr;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using Azure.Messaging.ServiceBus;
using Azure.Messaging.ServiceBus.Administration;

var builder = WebApplication.CreateBuilder(args);

// Add additional services
builder.Services.AddHttpClient();
builder.Services.AddSingleton<Store>();
builder.Services.AddSingleton<Queue>();

var app = builder.Build();

// Dapr will send serialized event object vs. being raw CloudEvent
app.UseCloudEvents();

// needed for Dapr pub/sub routing
app.MapSubscribeHandler();

if (app.Environment.IsDevelopment()) {app.UseDeveloperExceptionPage();}

// Dapr subscription in [Topic] routes orders topic to this route
app.MapPost("/message", [Topic("servicebus-pubsub", "orders")] async (ILogger<Program> logger, HttpClient httpClient, Message receivedMessage) => {
    try {
        logger.LogInformation($"Content Received: '{receivedMessage.message}'");
        CancellationTokenSource source = new CancellationTokenSource();
        CancellationToken cancellationToken = source.Token;
        var response = await httpClient.PostAsync(Store.getStoreUrl(), JsonContent.Create(new { message = receivedMessage.message }), cancellationToken);
        if (response.IsSuccessStatusCode){
            return Results.Ok();
        }
        else {
            return Results.Problem("Post to store failed.");
        }
        
    }
    catch (Exception exc){
        logger.LogError($"Content Received Error: {exc.Message}");
        return Results.Problem("Error processing message.");
    }
});

app.MapGet("/count", async (ILogger<Program> logger) => {
    try {
        CancellationTokenSource source = new CancellationTokenSource();
        CancellationToken cancellationToken = source.Token;

        // TopicRuntimeProperties topicProperties = await Queue.getManagementClient().GetTopicRuntimePropertiesAsync(Queue.TOPIC_NAME, cancellationToken);
        // logger.LogInformation($"Topic Properties: '{topicProperties.ScheduledMessageCount}'");
        // return Results.Ok($"Store Subscriber '{Queue.SUBSCRIPTION_NAME}' has {topicProperties.ScheduledMessageCount} message{(topicProperties.ScheduledMessageCount != 1 ? "s" : "")}");

        // ServiceBusReceiver receiver = Queue.getServiceBusClient().CreateReceiver(Queue.TOPIC_NAME, Queue.SUBSCRIPTION_NAME);
        // IReadOnlyList<ServiceBusReceivedMessage> peekedMessages = await receiver.PeekMessagesAsync(int.MaxValue, 0, cancellationToken);       
        // logger.LogInformation($"Store Subscriber Count: '{peekedMessages.Count}'");
        // return Results.Ok($"Store Subscriber '{Queue.SUBSCRIPTION_NAME}' has {peekedMessages.Count} message{(peekedMessages.Count != 1 ? "s" : "")}");

        SubscriptionRuntimeProperties subscriptionProperties = await Queue.getManagementClient().GetSubscriptionRuntimePropertiesAsync(Queue.TOPIC_NAME, Queue.SUBSCRIPTION_NAME, cancellationToken);
        logger.LogInformation($"Subscription Properties: '{subscriptionProperties.ActiveMessageCount}'");
        return Results.Ok($"Store Subscriber '{Queue.SUBSCRIPTION_NAME}' has {subscriptionProperties.ActiveMessageCount} message{(subscriptionProperties.ActiveMessageCount != 1 ? "s" : "")}");
    }
    catch (Exception exc){
        logger.LogError($"Count Request Received Error: {exc.Message}");
        return Results.Problem("Error processing count.");
    }
});

await app.RunAsync();

internal record Message([property: JsonPropertyName("message")] string message);

public class Store
{
    private static string storeURL = "";
    /// <summary>
    /// Gets the URL for the orders app.
    /// </summary>
    /// <returns></returns>
    public static Uri getStoreUrl()
    {
        if (String.IsNullOrEmpty(storeURL)) {
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

            return new Uri($"http://localhost:{daprPort}/v1.0/invoke/{targetApp}/method/store");
        }
        else {
            return new Uri(storeURL);
        }
    }
}

public class Queue {

    public static readonly string PUBSUB_NAME = "servicebus-pubsub";
    public static readonly string TOPIC_NAME = "orders";
    public static readonly string SUBSCRIPTION_NAME = "queuereader";
    private static ServiceBusClient? serviceBusClient = null;

    private static ServiceBusAdministrationClient? serviceBusAdministrationClient = null;

    /// <summary>
    /// Creates a ServiceBusClient or throws ApplicationException if there are input errors.
    /// </summary>
    /// <returns></returns>
    public static ServiceBusClient getServiceBusClient()
    {
        if (serviceBusClient is null){
            string connectionString = Environment.GetEnvironmentVariable("SBConnectionString") ?? "";

            if (String.IsNullOrEmpty(connectionString))
            {
                throw new ArgumentNullException("'Service Bus ConnectionString' config value is required. Please add an environment variable or app setting.");
            }

            return new ServiceBusClient(connectionString);
        }
        else {
            return serviceBusClient;
        }
    }

    /// <summary>
    /// Creates a ServiceBusAdministrationClient or throws ApplicationException if there are input errors.
    /// </summary>
    /// <returns></returns>
    public static ServiceBusAdministrationClient getManagementClient()
    {
        if (serviceBusAdministrationClient is null){
            string connectionString = Environment.GetEnvironmentVariable("SBConnectionString") ?? "";

            if (String.IsNullOrEmpty(connectionString))
            {
                throw new ArgumentNullException("'Service Bus ConnectionString' config value is required. Please add an environment variable or app setting.");
            }

            return new ServiceBusAdministrationClient(connectionString);
        }
        else {
            return serviceBusAdministrationClient;
        }
    }
}