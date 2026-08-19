using PrintServer.Models;
using PrintServer.Services;
using SkiaSharp;
using Xunit;

namespace PrintServer.Tests;

public sealed class SalesExportServiceTests
{
    private readonly SalesExportService _service = new();

    private static SalesExportRequest BuildRequest(string dir, bool isRtl = false) => new()
    {
        StoreName = "My Store",
        StoreAddress = "12 Main St",
        StorePhone = "0100000000",
        Title = "Sales Export - Month 8/2026",
        PeriodStart = "1/8/2026",
        PeriodEnd = "31/8/2026",
        IsRtl = isRtl,
        OutputDirectory = dir,
        Rows =
        [
            new SalesExportRow
            {
                Type = "sale",
                Id = "ORD-001",
                Date = "15/8/2026",
                Cashier = "cashier1",
                DiscountPercent = 10,
                TaxPercent = 14,
                DiscountPiastres = 250,
                TaxPiastres = 350,
                AmountPiastres = 2500,
                TotalPiastres = 2600,
                Items =
                [
                    new SalesExportItem { Name = "Pepsi", Quantity = 2, PricePiastres = 500 },
                    new SalesExportItem { Name = "Water", Quantity = 1, PricePiastres = 500 },
                ],
            },
            new SalesExportRow
            {
                Type = "expense",
                Id = "EXP-123",
                Date = "16/8/2026",
                Cashier = "cashier1",
                AmountPiastres = 1500,
                TotalPiastres = 1500,
                Items =
                [
                    new SalesExportItem { Name = "Bread", Quantity = 1, PricePiastres = 1500 },
                ],
            },
        ],
    };

    [Fact]
    public async Task SaveSalesExportPdfAsync_CreatesPdfFile_WithPdfMagicHeader()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"sales_export_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = BuildRequest(dir);

            var path = await _service.SaveSalesExportPdfAsync(request);

            Assert.NotNull(path);
            Assert.True(File.Exists(path!), $"expected PDF at {path}");
            var bytes = await File.ReadAllBytesAsync(path!);
            Assert.True(bytes.Length > 1000, "PDF should not be tiny");
            // %PDF- magic header (0x25 '%' 0x50 'P' 0x44 'D' 0x46 'F' 0x2D '-').
            Assert.Equal([0x25, 0x50, 0x44, 0x46, 0x2D], bytes.Take(5));
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public void WrapText_BreaksOnWordBoundaries()
    {
        using var paint = new SKPaint
        {
            Typeface = SKTypeface.FromFamilyName("Arial"),
            TextSize = 9.5f,
            IsAntialias = true,
        };
        var fit = paint.MeasureText("short");
        var wrapped = SalesExportService.WrapText("short word", paint, isRtl: false, fit);
        Assert.Equal(2, wrapped.Count);
        Assert.Equal("short", wrapped[0]);
        Assert.Equal("word", wrapped[1]);
    }

    [Fact]
    public async Task SaveSalesExportPdfAsync_IsRtlArabic_RendersFileWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"sales_export_ar_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = BuildRequest(dir, isRtl: true);
            request.StoreName = "متجر التجربة";
            request.Rows[0].Id = "ORD-001";
            request.Rows[0].Items[0].Name = "قهوة عربية";
            request.Rows[0].Cashier = "أحمد";

            var path = await _service.SaveSalesExportPdfAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
            var bytes = await File.ReadAllBytesAsync(path!);
            Assert.Equal([0x25, 0x50, 0x44, 0x46, 0x2D], bytes.Take(5));
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task SaveSalesExportPdfAsync_EmptyItems_RendersFileWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"sales_export_empty_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = BuildRequest(dir);
            request.Rows[0].Items = [];

            var path = await _service.SaveSalesExportPdfAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
            var bytes = await File.ReadAllBytesAsync(path!);
            Assert.Equal([0x25, 0x50, 0x44, 0x46, 0x2D], bytes.Take(5));
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task SaveSalesExportPdfAsync_NoOutputDirectory_ReturnsNull()
    {
        var request = BuildRequest(string.Empty);

        var path = await _service.SaveSalesExportPdfAsync(request);

        Assert.Null(path);
    }

    [Fact]
    public async Task SaveSalesExportPdfAsync_ManyRows_RendersMultiPagePdf()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"sales_export_many_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = BuildRequest(dir);
            for (var i = 0; i < 60; i++)
            {
                request.Rows.Add(new SalesExportRow
                {
                    Type = "sale",
                    Id = $"ORD-{i:000}",
                    Date = "15/8/2026",
                    Cashier = "cashier1",
                    AmountPiastres = 1000,
                    TotalPiastres = 1000,
                    Items =
                    [
                        new SalesExportItem { Name = "Item", Quantity = 1, PricePiastres = 1000 },
                    ],
                });
            }

            var path = await _service.SaveSalesExportPdfAsync(request);

            Assert.NotNull(path);
            var bytes = await File.ReadAllBytesAsync(path!);
            Assert.True(bytes.Length > 1000);
            // 62 data rows at ~25pt each cannot fit a single A4 landscape
            // page (content height ~505pt): the renderer must paginate.
            var ascii = System.Text.Encoding.ASCII.GetString(bytes);
            var pageCount = System.Text.RegularExpressions.Regex.Matches(
                ascii, @"/Type /Page\b").Count;
            Assert.True(pageCount >= 2, $"expected multiple pages, got {pageCount}");
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }
}