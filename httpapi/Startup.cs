namespace HttpApi
{
    using System;
    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.OpenApi.Models;
    using Azure.Messaging.ServiceBus;

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
            services.AddSingleton(typeof(ServiceBusClient), this.getServiceBusClient());
            services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new OpenApiInfo { Title = "HttpApi", Version = "v1" });
            });

            // Add Dapr
            services.AddControllers().AddDapr();
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

            // Configure Dapr Middleware
            app.UseCloudEvents();

            app.UseRouting();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
                endpoints.MapSubscribeHandler();
            });
        }

        /// <summary>
        /// Creates a ServiceBusClient or throws ApplicationException if there are input errors.
        /// </summary>
        /// <returns></returns>
        private ServiceBusClient getServiceBusClient()
        {
            string connectionString = this.Configuration["SBConnectionString"];

            if (String.IsNullOrEmpty(connectionString))
            {
                throw new ArgumentNullException("'SBConnectionString' config value is required. Please add an environment variable or app setting.");
            }

            return new ServiceBusClient(connectionString);
        }
    }
}
