using System.ComponentModel.DataAnnotations;
using System.Threading.RateLimiting;
using PrintServer.Models;
using PrintServer.Services;

// Local sidecar: config files are static, so disable host config file watching
// BEFORE the builder ctor loads appsettings.json. This keeps the server from
// consuming inotify instances at startup and crashing when the per-user
// inotify limit is exhausted by other tooling.
Environment.SetEnvironmentVariable("DOTNET_hostBuilder:reloadConfigOnChange", "false");

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

var parentPid = ParseParentPid(args);
if (parentPid > 0)
{
    // Kill ourselves when the cashier app exits (crash or close) so the
    // port is released and the next launch can bind it.
    builder.Services.AddHostedService(sp =>
        new ParentProcessWatcher(
            parentPid,
            sp.GetRequiredService<Microsoft.Extensions.Hosting.IHostApplicationLifetime>()));
}

var app = builder.Build();

app.UseRateLimiter();

// Lightweight liveness probe (no printer enumeration) used by the cashier app
// to decide between adopting a running instance and killing a stale one.
app.MapGet("/api/printing/health", () => Results.Ok(new { status = "ok" }));

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

        var printSuccess = !request.SkipPrint && printer.PrintReceipt(request);

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

app.MapPost("/api/printing/ticket", (TicketRequest request, PrinterService printer) =>
{
    if (request.Items.Count == 0)
    {
        return Results.BadRequest(new { error = "Ticket must contain items" });
    }
    var printSuccess = printer.PrintTicket(request);
    return Results.Ok(new { printed = printSuccess });
});

app.Run();

static int ParseParentPid(string[] args)
{
    const string flag = "--parent-pid";
    for (var i = 0; i < args.Length; i++)
    {
        var arg = args[i];
        if (arg == flag && i + 1 < args.Length && int.TryParse(args[i + 1], out var next))
            return next;
        if (arg.StartsWith(flag + "=", StringComparison.OrdinalIgnoreCase) &&
            int.TryParse(arg[(flag.Length + 1)..], out var inline))
            return inline;
    }
    return 0;
}
