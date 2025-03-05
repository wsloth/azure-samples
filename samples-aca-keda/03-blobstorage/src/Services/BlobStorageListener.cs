using Azure.Identity;
using Azure.Storage.Blobs;

namespace BlobStorageScaling.Services;

public class BlobStorageListener : BackgroundService
{
    private readonly ILogger<BlobStorageListener> _logger;
    private readonly BlobContainerClient _containerClient;

    public BlobStorageListener(ILogger<BlobStorageListener> logger, IConfiguration configuration)
    {
        _logger = logger;
        
        var accountName = configuration["BlobStorage:AccountName"];
        var containerName = configuration["BlobStorage:ContainerName"];
        
        var blobServiceClient = new BlobServiceClient(
            new Uri($"https://{accountName}.blob.core.windows.net"),
            new DefaultAzureCredential());
            
        _containerClient = blobServiceClient.GetBlobContainerClient(containerName);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await foreach (var blobItem in _containerClient.GetBlobsAsync(cancellationToken: stoppingToken))
                {
                    _logger.LogInformation("Found blob: {Name}", blobItem.Name);
                    var blobClient = _containerClient.GetBlobClient(blobItem.Name);
                    await blobClient.DeleteAsync(cancellationToken: stoppingToken);
                    _logger.LogInformation("Processed & Deleted blob: {Name}", blobItem.Name);
                }
                
                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing blobs");
                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
        }
    }
}
