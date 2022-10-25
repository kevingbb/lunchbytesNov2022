namespace HttpApi.Controllers
{
    using Azure.Storage.Queues;
    using Azure.Storage.Queues.Models;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;
    using System;
    using System.Threading.Tasks;

    [ApiController]
    [Route("[controller]")]
    public class DataController : ControllerBase
    {

        private readonly ILogger<DataController> logger;
        private readonly QueueClient queueClient;

        public DataController(ILogger<DataController> logger, QueueClient queueClient)
        {
            this.logger = logger;
            this.queueClient = queueClient;
        }
        [HttpGet]
        public async Task<string> GetAsync()
        {
            QueueProperties properties = await this.queueClient.GetPropertiesAsync();

            return $"Queue '{this.queueClient.Name}' has {properties.ApproximateMessagesCount} message{(properties.ApproximateMessagesCount != 1 ? "s" : "")}";
        }

        [HttpPost]
        public async Task PostAsync()
        {
            try
            {
                // TODO: Replace with Message from querystring.
                await queueClient.SendMessageAsync(Guid.NewGuid().ToString());
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
    }
}
