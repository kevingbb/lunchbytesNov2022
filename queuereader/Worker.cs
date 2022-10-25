namespace QueueWorker
{
    using Azure.Storage.Queues;
    using Azure.Storage.Queues.Models;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging;
    using System;
    using System.Net.Http;
    using System.Net.Http.Json;
    using System.Threading;
    using System.Threading.Tasks;

    internal sealed class Worker : BackgroundService
    {
        private readonly IHostApplicationLifetime applicationLifetime;
        private readonly ILogger<Worker> logger;
        private readonly IConfiguration config;
        private readonly HttpClient httpClient;

        public Worker(ILogger<Worker> logger, IConfiguration config, IHostApplicationLifetime applicationLifetime, HttpClient httpClient)
        {
            this.logger = logger;
            this.config = config;
            this.applicationLifetime = applicationLifetime;
            this.httpClient = httpClient;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try
            {
                QueueClient client = this.getQueueClient();

                Uri storeUrl = this.getStoreUrl();

                while (true)
                {
                    stoppingToken.ThrowIfCancellationRequested();

                    try
                    {
                        QueueMessage message = await client.ReceiveMessageAsync(cancellationToken: stoppingToken);

                        if (message == null)
                        {
                            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                            continue;
                        }

                        logger.LogInformation($"Message ID: '{message.MessageId}', contents: '{message.Body?.ToString()}'");

                        await httpClient.PostAsync(storeUrl, JsonContent.Create(new { Id = message.MessageId, Message = message.Body?.ToString() }), stoppingToken);

                        await client.DeleteMessageAsync(message.MessageId, message.PopReceipt, stoppingToken);

                    }
                    catch (Azure.RequestFailedException rfe)
                    {
                        if (rfe.ErrorCode == "QueueNotFound")
                        {
                            logger.LogInformation($"Queue '{client.Name}' does not exist. Waiting..");
                            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
                        }
                        else
                        {
                            logger.LogError($"Something went wrong connecting to the queue: {rfe}");
                        }
                    }
                    catch (HttpRequestException hre)
                    {
                        logger.LogError($"Something went wrong writing to the store: {hre.Message}");
                    }
                }

            }
            catch (OperationCanceledException)
            {
                logger.LogInformation("Queue reader is shutting down..");
            }
            catch (Exception e)
            {
                logger.LogError(e.Message);
            }
            finally
            {
                applicationLifetime.StopApplication();
            }
        }


        /// <summary>
        /// Creates a QueueClient or throws if there are input errors.
        /// </summary>
        /// <exception cref="ArgumentNullException" />
        /// <exception cref="FormatException" />
        /// <returns></returns>
        private QueueClient getQueueClient()
        {
            string connectionString = this.config["QueueConnectionString"];
            string queueName = this.config["QueueName"];

            if (string.IsNullOrEmpty(connectionString))
            {
                throw new ArgumentNullException("'QueueConnectionString' config value is required. Please add an environemnt variable or app setting.");
            }

            if (string.IsNullOrEmpty(queueName))
            {
                throw new ArgumentNullException("'QueueName' config value is required. Please add an environemnt variable or app setting.");
            }

            logger.LogInformation($"Waiting for messages on '{queueName}'.");

            return new QueueClient(connectionString, queueName);
        }

        /// <summary>
        /// Gets the URL for the orders app.
        /// </summary>
        /// <returns></returns>
        private Uri getStoreUrl()
        {
            string daprPort = this.config["DAPR_HTTP_PORT"];
            string targetApp = this.config["TargetApp"];

            if (string.IsNullOrEmpty(daprPort))
            {
                throw new ArgumentNullException("'DaprPort' config value is required. Please add an environment variable or app setting.");
            }

            if (string.IsNullOrEmpty(targetApp))
            {
                throw new ArgumentNullException("'TargetApp' config value is required. Please add an environment variable or app setting.");
            }

            Uri storeUrl = new Uri($"http://localhost:{daprPort}/v1.0/invoke/{targetApp}/method/store");

            logger.LogInformation($"Ready to send messages to '{storeUrl}'.");

            return storeUrl;
        }
    }
}
