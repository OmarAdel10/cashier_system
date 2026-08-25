using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using PrintServer.Linux.Services;
using PrintServer.Linux.Tests.Mocks;
using System.Net.Http.Json;
using Xunit;

namespace PrintServer.Linux.Tests;

public sealed class EndpointContractTests
{
    private static WebApplicationFactory<global::Program> CreateFactory(MockCupsClient mock)
        => new WebApplicationFactory<global::Program>().WithWebHostBuilder(builder =>
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<CupsPrinterService>();
                services.AddSingleton(new CupsPrinterService(mock));
            }));

    private static string TempDir() =>
        Path.Combine(Path.GetTempPath(), $"contract_{Guid.NewGuid():N}");

    private const string ValidSvg =
        """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#00ff00"/></svg>""";

    [Fact]
    public async Task LocalPrinters_ReturnsCupsPrinterNamesArray()
    {
        var mock = new Mocks.MockCupsClient();
        mock.Printers.Add("ThermalReceipt");
        mock.Printers.Add("KitchenPrinter");
        using var factory = CreateFactory(mock);

        var client = factory.CreateClient();
        var response = await client.GetAsync("/api/printing/local-printers");

        response.EnsureSuccessStatusCode();
        var printers = await response.Content.ReadFromJsonAsync<string[]>();
        Assert.Equal(new[] { "ThermalReceipt", "KitchenPrinter" }, printers);
    }

    [Fact]
    public async Task ValidateSvg_ValidSvg_ReturnsValidTrueWithEmptyErrors()
    {
        using var factory = CreateFactory(new Mocks.MockCupsClient());
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/printing/validate-svg",
            new { data = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(ValidSvg)) });

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.True(json.GetProperty("valid").GetBoolean());
        Assert.Empty(json.GetProperty("errors").EnumerateArray());
    }

    [Fact]
    public async Task ValidateSvg_ScriptSvg_ReturnsValidFalseWithErrors()
    {
        using var factory = CreateFactory(new Mocks.MockCupsClient());
        var client = factory.CreateClient();

        var malicious =
            """<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>""";
        var response = await client.PostAsJsonAsync("/api/printing/validate-svg",
            new { data = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(malicious)) });

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.False(json.GetProperty("valid").GetBoolean());
        Assert.NotEmpty(json.GetProperty("errors").EnumerateArray());
    }

    [Fact]
    public async Task SavePng_MissingOutputDirectory_Returns400()
    {
        using var factory = CreateFactory(new Mocks.MockCupsClient());
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/printing/save-png",
            new { store_name = "Test", items = Array.Empty<object>(), created_at = DateTime.Now, save_as_png = true });

        Assert.Equal(System.Net.HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.False(string.IsNullOrWhiteSpace(json.GetProperty("error").GetString()));
    }

    [Fact]
    public async Task Ticket_EmptyItems_Returns400()
    {
        using var factory = CreateFactory(new Mocks.MockCupsClient());
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/printing/ticket",
            new { store_name = "Test", items = Array.Empty<object>(), created_at = DateTime.Now });

        Assert.Equal(System.Net.HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.Contains("items", json.GetProperty("error").GetString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Barcode_DataOver80Chars_Returns400WithErrors()
    {
        var mock = new Mocks.MockCupsClient();
        mock.Printers.Add("ThermalReceipt");
        using var factory = CreateFactory(mock);
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/printing/barcode",
            new { barcodeData = new string('X', 81), printerName = "ThermalReceipt", isRtl = false });

        Assert.Equal(System.Net.HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.NotEmpty(json.GetProperty("errors").EnumerateArray());
        Assert.Empty(mock.PrintCalls);
    }

    [Fact]
    public async Task Receipt_PrintToFile_WritesPdfIntoPrintFileNameDirectory()
    {
        var dir = TempDir();
        Directory.CreateDirectory(dir);
        var mock = new Mocks.MockCupsClient { DefaultPrinter = "ThermalReceipt" };
        mock.Printers.Add("ThermalReceipt");
        using var factory = CreateFactory(mock);
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/printing/receipt",
            new
            {
                store_name = "Test Store",
                items = new[] { new { name = "Coffee", quantity = 2, unit_price_piastres = 2500, total_piastres = 5000 } },
                subtotal_piastres = 5000,
                total_piastres = 5000,
                created_at = DateTime.Now,
                print_to_file = true,
                print_file_name = Path.Combine(dir, "inv.pdf"),
            });

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        var pdfPath = json.GetProperty("pdfPath").GetString();
        Assert.False(string.IsNullOrWhiteSpace(pdfPath));
        Assert.True(File.Exists(pdfPath!), $"expected PDF at {pdfPath}");
        Assert.StartsWith(dir, pdfPath);
        Assert.Equal([0x25, 0x50, 0x44, 0x46, 0x2D], (await File.ReadAllBytesAsync(pdfPath!)).Take(5));
        Directory.Delete(dir, recursive: true);
    }
}
