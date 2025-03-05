using Grpc.Core;
using Keda.Scaler;

namespace ScalableService;

/// <summary>
/// Basic implementation of an external scaler.
/// More information can be found here: https://keda.sh/docs/2.16/concepts/external-scalers/
/// </summary>
public class ExternalScalerService : ExternalScaler.ExternalScalerBase
{
    private readonly ILogger<ExternalScalerService> _logger;
    private static double _currentValue = 0;
    private const double _incrementValue = 5;
    private const double _maxValue = 200;

    public ExternalScalerService(ILogger<ExternalScalerService> logger)
    {
        _logger = logger;
    }

    public override Task<IsActiveResponse> IsActive(ScaledObjectRef request, ServerCallContext context)
    {
        // Indicates whether the scaler is active or not, for this example it always is
        return Task.FromResult(new IsActiveResponse { Result = true });
    }

    public override Task<GetMetricSpecResponse> GetMetricSpec(ScaledObjectRef request, ServerCallContext context)
    {
        // This defines the "metric spec" that KEDA will use to scale the application
        // Basically, it defines the metric name and the target value that one instance is expected to handle
        
        // In this example code, the counter is incremented to a maximum of 200, so we set the target to 25
        // This means that KEDA will scale the application to 8 instances when the metric reaches 200, and
        // scale down to zero instance when the metric is below 25
        
        return Task.FromResult(new GetMetricSpecResponse
        {
            MetricSpecs = { new MetricSpec { MetricName = "custom_metric", TargetSize = 25 } }
        });
    }

    public override Task<GetMetricsResponse> GetMetrics(GetMetricsRequest request, ServerCallContext context)
    {
        _currentValue += _incrementValue;
        
        // Reset when we reach the maximum
        if (_currentValue > _maxValue)
        {
            _currentValue = 0;
        }
        
        _logger.LogInformation("Current metric value: {Value}", _currentValue);
        
        return Task.FromResult(new GetMetricsResponse
        {
            MetricValues = { new MetricValue { MetricValue_ = (long)_currentValue } }
        });
    }
}
