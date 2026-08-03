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
builder.Services.AddSingleton<SvgValidator>();

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
    try
    {
        string? pngPath = null;

        if (request.SaveAsPng && !string.IsNullOrWhiteSpace(request.OutputDirectory))
        {
            pngPath = await imageExport.SaveReceiptAsPngAsync(request);
        }

        var printSuccess = !request.SkipPrint && printer.PrintReceipt(request, pngPath);

        return Results.Ok(new { printed = printSuccess, pngPath });
    }
    catch (Exception ex)
    {
        System.Diagnostics.Debug.WriteLine($"[PrintServer] /receipt error: {ex}");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "Receipt processing failed"
        );
    }
});

app.MapPost("/api/printing/save-png", async (
    ReceiptRequest request,
    ImageExportService imageExport) =>
{
    try
    {
        if (string.IsNullOrWhiteSpace(request.OutputDirectory))
            return Results.BadRequest(new { error = "OutputDirectory required" });
        request.SaveAsPng = true;
        var pngPath = await imageExport.SaveReceiptAsPngAsync(request);
        return Results.Ok(new { pngPath });
    }
    catch (Exception ex)
    {
        System.Diagnostics.Debug.WriteLine($"[PrintServer] /save-png error: {ex}");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "PNG save failed"
        );
    }
});

app.MapPost("/api/printing/validate-svg", (
    SvgValidationRequest request,
    SvgValidator validator) =>
{
    try
    {
        var result = validator.Validate(request.Data);
        return Results.Ok(new { valid = result.Valid, errors = result.Errors });
    }
    catch (Exception ex)
    {
        System.Diagnostics.Debug.WriteLine($"[PrintServer] /validate-svg error: {ex}");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "SVG validation failed"
        );
    }
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
