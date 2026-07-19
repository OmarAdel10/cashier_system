using PrintServer.Models;
using PrintServer.Services;
using Xunit;

namespace PrintServer.Tests;

public sealed class FinancialVisibilityTests : IDisposable
{
    private readonly ImageExportService _service = new();
    private readonly string _tempDir;

    public FinancialVisibilityTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"PrintServerTests_{Guid.NewGuid()}");
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    private ReceiptRequest MakeRequest(int tax, int discount) => new()
    {
        StoreName = "Test Store",
        Items = [new ReceiptItem { Name = "Item", Quantity = 1, UnitPricePiastres = 1000 }],
        SubtotalPiastres = 1000,
        DiscountPiastres = discount,
        TaxPiastres = tax,
        TaxPercent = 14,
        TotalPiastres = 1000 + tax - discount,
        SaveAsPng = true,
        OutputDirectory = _tempDir,
    };

    [Fact]
    public async Task Png_Saved_When_SaveAsPngTrue()
    {
        var request = MakeRequest(0, 0);
        var result = await _service.SaveReceiptAsPngAsync(request);

        Assert.NotNull(result);
        Assert.True(File.Exists(result));
    }

    [Fact]
    public async Task Returns_Null_When_SaveAsPngFalse()
    {
        var request = MakeRequest(0, 0);
        request.SaveAsPng = false;
        var result = await _service.SaveReceiptAsPngAsync(request);

        Assert.Null(result);
    }

    [Fact]
    public async Task Returns_Null_When_OutputDirectory_Empty()
    {
        var request = MakeRequest(0, 0);
        request.OutputDirectory = null;
        var result = await _service.SaveReceiptAsPngAsync(request);

        Assert.Null(result);
    }

    [Fact]
    public async Task Directory_Created_When_NotExists()
    {
        var nonExistent = Path.Combine(_tempDir, "sub", "nested");
        var request = MakeRequest(0, 0);
        request.OutputDirectory = nonExistent;

        var result = await _service.SaveReceiptAsPngAsync(request);

        Assert.NotNull(result);
        Assert.True(Directory.Exists(nonExistent));
        Assert.True(File.Exists(result));
    }

    [Fact]
    public async Task Png_Generated_For_Each_Condition()
    {
        // Tax > 0, Discount > 0 — all rows visible
        var r1 = await _service.SaveReceiptAsPngAsync(MakeRequest(140, 50));
        Assert.NotNull(r1);

        // Tax = 0, Discount = 0 — only total visible
        var r2 = await _service.SaveReceiptAsPngAsync(MakeRequest(0, 0));
        Assert.NotNull(r2);

        // Tax = 0, Discount > 0 — subtotal + discount visible
        var r3 = await _service.SaveReceiptAsPngAsync(MakeRequest(0, 50));
        Assert.NotNull(r3);

        // Tax > 0, Discount = 0 — subtotal + tax visible
        var r4 = await _service.SaveReceiptAsPngAsync(MakeRequest(140, 0));
        Assert.NotNull(r4);
    }

    [Fact]
    public async Task FileName_Follows_Expected_Pattern()
    {
        var request = MakeRequest(0, 0);
        var result = await _service.SaveReceiptAsPngAsync(request);

        Assert.NotNull(result);
        var name = Path.GetFileName(result);
        Assert.StartsWith("receipt_", name);
        Assert.EndsWith(".png", name);
    }
}
