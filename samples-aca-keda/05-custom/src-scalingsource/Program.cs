using ScalableService;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddGrpc();

var app = builder.Build();

app.MapGrpcService<ExternalScalerService>();
app.MapGet("/", () => "gRPC External Scaler Service");

await app.RunAsync();
