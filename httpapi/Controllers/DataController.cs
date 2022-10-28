namespace HttpApi.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;
    using System;
    using System.Threading.Tasks;
    using Dapr;
    using Dapr.Client;
    using System.Threading;
    using System.Text.Json.Serialization;
    using Azure.Messaging.ServiceBus;
    using System.Collections.Generic;

    [ApiController]
    [Route("[controller]")]
    public class DataController : ControllerBase
    {

        private readonly ILogger<DataController> logger;
        private readonly DaprClient daprClient;
        private readonly string PUBSUB_NAME = "servicebus-pubsub";
        private readonly string TOPIC_NAME = "orders";
        private readonly string SUBSCRIPTION_NAME = "queuereader";
        public record Message([property: JsonPropertyName("message")] string message);
        private readonly ServiceBusClient sbClient;

        public DataController(ILogger<DataController> logger, DaprClient daprClient, ServiceBusClient sbClient)
        {
            this.logger = logger;
            this.daprClient = daprClient;
            this.sbClient = sbClient;
        }
        [HttpGet]
        public async Task<string> GetAsync()
        {
            CancellationTokenSource source = new CancellationTokenSource();
            CancellationToken cancellationToken = source.Token;

            ServiceBusReceiver receiver = sbClient.CreateReceiver(TOPIC_NAME, SUBSCRIPTION_NAME);
            IReadOnlyList<ServiceBusReceivedMessage> peekedMessages = await receiver.PeekMessagesAsync(20000, null, cancellationToken);
            
            logger.LogInformation($"Store Subscriber Count: '{peekedMessages.Count}'");
            return $"Store Subscriber '{SUBSCRIPTION_NAME}' has {peekedMessages.Count} message{(peekedMessages.Count != 1 ? "s" : "")}";
        }

        [HttpPost]
        public async Task PostAsync()
        {
            try
            {
                CancellationTokenSource source = new CancellationTokenSource();
                CancellationToken cancellationToken = source.Token;
                // TODO: Replace with Message from querystring.
                var pubsubMessage = new Message (Guid.NewGuid().ToString());
                //Using Dapr SDK to publish a topic
                await daprClient.PublishEventAsync(PUBSUB_NAME, TOPIC_NAME, pubsubMessage , cancellationToken);
                logger.LogInformation($"Message Contents: 'TODO: MISSING'");
                Ok();
            }
            catch (Azure.RequestFailedException rfe)
            {
                logger.LogError($"Something went wrong connecting to the queue: {rfe}");

                this.Response.StatusCode = 503;
                this.Response.Headers.Add("Retry-After", "10");
            }
        }

        // // For testing pubsub in a single application.
        // // Subscribe to a topic 
        // [Topic("servicebus-pubsub", "orders")]
        // [HttpPost("message")]
        // public ActionResult<string> getMessage(Message message)
        // {
        //     logger.LogInformation("Subscriber received : " + message);
        //     return Ok(message);
        // }
    }
}
