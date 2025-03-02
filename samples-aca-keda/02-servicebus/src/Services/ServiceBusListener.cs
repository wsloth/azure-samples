using Azure.Identity;
using Azure.Messaging.ServiceBus;

namespace ServiceBusScaling.Services;

public class ServiceBusListener : BackgroundService
{
    private readonly ILogger<ServiceBusListener> _logger;
    private readonly ServiceBusClient _client;
    private readonly ServiceBusProcessor _processor;

    public ServiceBusListener(ILogger<ServiceBusListener> logger, IConfiguration configuration)
    {
        _logger = logger;
        
        var connectionString = configuration["ServiceBus:ConnectionString"];
        var topicName = configuration["ServiceBus:TopicName"];
        var subscriptionName = configuration["ServiceBus:SubscriptionName"];

        _client = new ServiceBusClient(connectionString, new DefaultAzureCredential()); // Important: Use Managed Identity credential
        _processor = _client.CreateProcessor(topicName, subscriptionName);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _processor.ProcessMessageAsync += MessageHandler;
        _processor.ProcessErrorAsync += ErrorHandler;

        await _processor.StartProcessingAsync(stoppingToken);
        
        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation("Stopping service bus processor");
        }
        finally
        {
            await _processor.StopProcessingAsync();
            await _processor.DisposeAsync();
            await _client.DisposeAsync();
        }
    }

    private async Task MessageHandler(ProcessMessageEventArgs args)
    {
        var body = args.Message.Body.ToString();
        _logger.LogInformation("Received message: {Body}", body);
        // Simulate some work
        await Task.Delay(TimeSpan.FromSeconds(1));
        await args.CompleteMessageAsync(args.Message);
    }

    private Task ErrorHandler(ProcessErrorEventArgs args)
    {
        _logger.LogError(args.Exception, "Error processing message");
        return Task.CompletedTask;
    }
}
