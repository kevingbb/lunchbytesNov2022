// namespace HttpApi.Controllers
// {
//     using Microsoft.AspNetCore.Mvc;
//     using Microsoft.Extensions.Logging;
//     using System;
//     using System.Threading.Tasks;
//     using Dapr;
//     using Dapr.Client;
//     using System.Threading;
//     using System.Text.Json.Serialization;

//     [ApiController]
//     [Route("[controller]")]
//     public class DataController : ControllerBase
//     {

//         private readonly ILogger<DataController> logger;
//         private readonly DaprClient daprClient;
//         private readonly string PUBSUB_NAME = "servicebus-pubsub";
//         private readonly string TOPIC_NAME = "orders";
//         public record Message([property: JsonPropertyName("message")] string message);

//         public DataController(ILogger<DataController> logger, DaprClient daprClient)
//         {
//             this.logger = logger;
//             this.daprClient = daprClient;
//         }

//         [HttpGet]
//         public ActionResult GetAsync()
//         {
//             logger.LogInformation($"Get message received.");
//             return Ok($"Get not implemented, only Post :).");
//         }

//         [HttpPost]
//         public async Task<ActionResult> PostAsync(string message)
//         {
//             try
//             {
//                 CancellationTokenSource source = new CancellationTokenSource();
//                 CancellationToken cancellationToken = source.Token;
//                 var pubsubMessage = new Message (DateTimeOffset.Now.ToString() + " -- " + message);
//                 //Using Dapr SDK to publish a topic
//                 await daprClient.PublishEventAsync(PUBSUB_NAME, TOPIC_NAME, pubsubMessage , cancellationToken);
//                 logger.LogInformation($"Message Contents: '{message}'");
//                 return Ok();
//             }
//             catch (Exception exc)
//             {
//                 logger.LogError($"Something went wrong with pub/sub: {exc.Message}");
//                 this.Response.StatusCode = 503;
//                 this.Response.Headers.Add("Retry-After", "10");
//                 return Problem("Something went wrong with pub/sub.");
//             }
//         }

//         // // For testing pubsub in a single application.
//         // // Subscribe to a topic 
//         // [Topic("servicebus-pubsub", "orders")]
//         // [HttpPost("message")]
//         // public ActionResult<string> getMessage(Message message)
//         // {
//         //     logger.LogInformation("Subscriber received : " + message);
//         //     return Ok(message);
//         // }
//     }
// }
