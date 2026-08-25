using System.ComponentModel.DataAnnotations;
using System.Threading.RateLimiting;
using PrintServer.Linux.Models;
using PrintServer.Linux.Services;

// Bumped whenever the health contract changes; lets clients detect a stale
// PrintServer binary.
const int CurrentApiVersion = 4;

// Payload bounds: one request must never be able to drive multi-gigabyte
// bitmap allocations or unbounded PDF pagination in the shared sidecar.
const int MaxReceiptItems = 500;
const int MaxTicketItems = 500;
const int MaxSalesRows = 5000;

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

// The API is unauthenticated by design (local sidecar); keep the request
// body small enough that a single call cannot exhaust memory.
builder.WebHost.ConfigureKestrel(o =>
    o.Limits.MaxRequestBodySize = 8 * 1024 * 1024);

// Loopback binding stops remote sockets, not remote browsers: without a
// Host allowlist a DNS-rebinding page could read and drive this API.
builder.Services.AddHostFiltering(o =>
{
    o.AllowedHosts.Add("127.0.0.1");
    o.AllowedHosts.Add("localhost");
});

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

builder.Services.AddSingleton<CupsPrinterService>();
builder.Services.AddSingleton<ImageExportService>();
builder.Services.AddSingleton<InvoiceService>();
builder.Services.AddSingleton<SalesExportService>();
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

app.UseHostFiltering();

app.UseRateLimiter();

// Release builds strip Debug.WriteLine; endpoint failures must still leave
// a trace somewhere for an unattended POS sidecar.
var errorLog = app.Services.GetRequiredService<ILogger<Program>>();

app.MapGet("/api/printing/health", () =>
    Results.Ok(new { status = "ok", version = CurrentApiVersion }));

app.MapGet("/api/printing/local-printers", (CupsPrinterService printerService) =>
{
    var printers = printerService.GetInstalledPrinters();
    return Results.Ok(printers);
});

app.MapPost("/api/printing/receipt", async (
    ReceiptRequest request,
    ImageExportService imageExport,
    InvoiceService invoice,
    CupsPrinterService printer) =>
{
    if (request.Items.Count > MaxReceiptItems)
        return Results.BadRequest(new { error = $"Too many items (max {MaxReceiptItems})" });
    try
    {
        string? pngPath = null;

        if (request.SaveAsPng && !string.IsNullOrWhiteSpace(request.OutputDirectory))
        {
            pngPath = await imageExport.SaveReceiptAsPngAsync(request);
        }

        // Print-to-file: silent save, returns the written path so the app
        // can confirm and locate the PDF. On Linux there is no GDI
        // print-to-file: the A4 invoice PDF is generated directly by
        // InvoiceService into the PrintFileName directory (the client uses
        // the returned pdfPath, mirroring the Windows contract).
        string? pdfPath = null;
        if (request.PrintToFile && !string.IsNullOrWhiteSpace(request.PrintFileName))
        {
            var fileDir = Path.GetDirectoryName(request.PrintFileName);
            request.OutputDirectory = string.IsNullOrWhiteSpace(fileDir)
                ? AppContext.BaseDirectory
                : fileDir;
            pdfPath = await invoice.SaveInvoicePdfAsync(request);
            if (pdfPath == null)
            {
                return Results.Problem(
                    detail: "Receipt print-to-file failed (check the target directory and CUPS configuration).",
                    statusCode: StatusCodes.Status500InternalServerError,
                    title: "Print to file failed"
                );
            }
        }

        var printSuccess = !request.SkipPrint && !request.PrintToFile && printer.PrintReceipt(request);

        return Results.Ok(new { printed = printSuccess, pngPath, pdfPath });
    }
    catch (LogoRenderException ex)
    {
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "Logo render failed"
        );
    }
    catch (Exception ex)
    {
        errorLog.LogError(ex, "//receipt error");
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
    if (string.IsNullOrWhiteSpace(request.OutputDirectory))
        return Results.BadRequest(new { error = "OutputDirectory required" });
    if (request.Items.Count > MaxReceiptItems)
        return Results.BadRequest(new { error = $"Too many items (max {MaxReceiptItems})" });
    try
    {
        request.SaveAsPng = true;
        var pngPath = await imageExport.SaveReceiptAsPngAsync(request);
        return Results.Ok(new { pngPath });
    }
    catch (Exception ex)
    {
        errorLog.LogError(ex, "//save-png error");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "PNG save failed"
        );
    }
});

app.MapPost("/api/printing/save-pdf", async (
    ReceiptRequest request,
    InvoiceService invoice) =>
{
    if (string.IsNullOrWhiteSpace(request.OutputDirectory))
        return Results.BadRequest(new { error = "OutputDirectory required" });
    if (request.Items.Count > MaxReceiptItems)
        return Results.BadRequest(new { error = $"Too many items (max {MaxReceiptItems})" });
    try
    {
        var pdfPath = await invoice.SaveInvoicePdfAsync(request);
        return Results.Ok(new { pdfPath, saved = true });
    }
    catch (Exception ex)
    {
        errorLog.LogError(ex, "//save-pdf error");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "PDF save failed"
        );
    }
});

app.MapPost("/api/printing/sales-export", async (
    SalesExportRequest request,
    SalesExportService salesExport) =>
{
    if (string.IsNullOrWhiteSpace(request.OutputDirectory))
        return Results.BadRequest(new { error = "OutputDirectory required" });
    if (request.Rows.Count > MaxSalesRows)
        return Results.BadRequest(new { error = $"Too many rows (max {MaxSalesRows})" });
    try
    {
        var pdfPath = await salesExport.SaveSalesExportPdfAsync(request);
        return Results.Ok(new { pdfPath, saved = true });
    }
    catch (Exception ex)
    {
        errorLog.LogError(ex, "//sales-export error");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "Sales export PDF save failed"
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
        errorLog.LogError(ex, "//validate-svg error");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "SVG validation failed"
        );
    }
});

app.MapPost("/api/printing/barcode", async (
    BarcodeRequest request,
    CupsPrinterService printer) =>
{
    var validationResults = new List<ValidationResult>();
    var context = new ValidationContext(request);
    if (!Validator.TryValidateObject(request, context, validationResults, true))
    {
        var errors = validationResults.Select(v => v.ErrorMessage);
        return Results.BadRequest(new { errors });
    }
    var printSuccess = false;
    try
    {
        printSuccess = await printer.PrintBarcodeAsync(request);
    }
    catch (Exception ex)
    {
        errorLog.LogError(ex, "/barcode error");
        return Results.Problem(
            detail: ex.Message,
            statusCode: StatusCodes.Status500InternalServerError,
            title: "Barcode printing failed"
        );
    }
    return Results.Ok(new { printed = printSuccess });
});

app.MapPost("/api/printing/ticket", (TicketRequest request, CupsPrinterService printer) =>
{
    if (request.Items.Count == 0)
    {
        return Results.BadRequest(new { error = "Ticket must contain items" });
    }
    if (request.Items.Count > MaxTicketItems)
    {
        return Results.BadRequest(new { error = $"Too many items (max {MaxTicketItems})" });
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

public partial class Program { }
