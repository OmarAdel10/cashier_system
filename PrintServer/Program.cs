using System.ComponentModel.DataAnnotations;
using System.Threading.RateLimiting;
using PrintServer.Models;
using PrintServer.Services;

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory,
});

builder.WebHost.UseUrls("http://127.0.0.1:5150");

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(_ =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromSeconds(1),
            }));
});

builder.Services.AddSingleton<PrinterService>();
builder.Services.AddSingleton<ImageExportService>();

var app = builder.Build();

app.UseRateLimiter();

app.MapGet("/api/printing/local-printers", (PrinterService printerService) =>
{
    var printers = printerService.GetInstalledPrinters();
    return Results.Ok(printers);
});

app.MapPost("/api/printing/receipt", async (
    ReceiptRequest request,
    ImageExportService imageExport,
    PrinterService printer) =>
{
    string? pngPath = null;

    if (request.SaveAsPng && !string.IsNullOrWhiteSpace(request.OutputDirectory))
    {
        pngPath = await imageExport.SaveReceiptAsPngAsync(request);
    }

    var printSuccess = printer.PrintReceipt(request, pngPath);

    return Results.Ok(new { printed = printSuccess, pngPath });
});

app.MapPost("/api/printing/barcode", async (
    BarcodeRequest request,
    PrinterService printer) =>
{
    var validationResults = new List<ValidationResult>();
    var context = new ValidationContext(request);
    if (!Validator.TryValidateObject(request, context, validationResults, true))
    {
        var errors = validationResults.Select(v => v.ErrorMessage);
        return Results.BadRequest(new { errors });
    }
    var printSuccess = await printer.PrintBarcodeAsync(request);
    return Results.Ok(new { printed = printSuccess });
});

app.Run();
