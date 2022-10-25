namespace HttpApi
{
    using Azure.Storage.Queues;
    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.OpenApi.Models;
    using System;

    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {

            services.AddControllers();
            services.AddSingleton(typeof(QueueClient), this.getQueueClient());
            services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new OpenApiInfo { Title = "HttpApi", Version = "v1" });
            });
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseSwagger();
                app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "HttpApi v1"));
            }

            app.UseRouting();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });
        }

        /// <summary>
        /// Creates a QueueClient or throws ApplicationException if there are input errors.
        /// </summary>
        /// <returns></returns>
        private QueueClient getQueueClient()
        {
            string connectionString = this.Configuration["QueueConnectionString"];
            string queueName = this.Configuration["QueueName"];

            if (String.IsNullOrEmpty(connectionString))
            {
                throw new ArgumentNullException("'QueueConnectionString' config value is required. Please add an environment variable or app setting.");
            }

            if (String.IsNullOrEmpty(queueName))
            {
                throw new ArgumentNullException("'QueueName' config value is required. Please add an environment variable or app setting.");
            }

            return new QueueClient(connectionString, queueName);
        }
    }
}
