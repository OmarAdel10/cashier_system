using PrintServer.Models;
using PrintServer.Services;
using Xunit;

namespace PrintServer.Tests;

public sealed class InvoiceServiceTests
{
    private readonly InvoiceService _service = new();

    [Fact]
    public async Task SaveInvoicePdfAsync_CreatesPdfFile_WithPdfMagicHeader()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"invoice_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = new ReceiptRequest
            {
                StoreName = "My Store",
                StoreAddress = "12 Main St",
                StorePhone = "0100000000",
                OrderNumber = "123",
                Items =
                [
                    new ReceiptItem
                    {
                        Name = "Coffee",
                        Barcode = "SKU-001",
                        Quantity = 2,
                        UnitPricePiastres = 2500,
                        TotalPiastres = 5000,
                    },
                ],
                SubtotalPiastres = 5000,
                TotalPiastres = 5000,
                CreatedAt = DateTime.Now,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                ReceiptFootnote = "Thank you",
            };

            var path = await _service.SaveInvoicePdfAsync(request);

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
    public async Task SaveInvoicePdfAsync_IsRtlArabic_RendersFileWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"invoice_ar_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = new ReceiptRequest
            {
                StoreName = "متجر التجربة",
                StoreAddress = "شارع النيل",
                StorePhone = "0100000000",
                OrderNumber = "45",
                Items =
                [
                    new ReceiptItem
                    {
                        Name = "قهوة عربية",
                        Barcode = "SKU-AR-1",
                        Quantity = 2,
                        UnitPricePiastres = 2500,
                        TotalPiastres = 5000,
                    },
                ],
                SubtotalPiastres = 5000,
                TaxPiastres = 700,
                TaxPercent = 14,
                TotalPiastres = 5700,
                CreatedAt = DateTime.Now,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                IsRtl = true,
                ReceiptFootnote = "شكراً لتعاملكم معنا",
            };

            var path = await _service.SaveInvoicePdfAsync(request);

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
    public async Task SaveInvoicePdfAsync_NoOutputDirectory_ReturnsNull()
    {
        var request = new ReceiptRequest
        {
            StoreName = "Test",
            Items = [],
            CreatedAt = DateTime.Now,
            TotalPiastres = 0,
        };

        var path = await _service.SaveInvoicePdfAsync(request);

        Assert.Null(path);
    }

    [Fact]
    public async Task SaveInvoicePdfAsync_DiscountedLineItem_WithStrikeOriginal_RendersWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"invoice_disc_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            // Line total (2000) differs from unit price x qty (1000 x 3 = 3000):
            // exercises the per-item discount strike-through path.
            var request = new ReceiptRequest
            {
                StoreName = "Test",
                Items =
                [
                    new ReceiptItem
                    {
                        Name = "Item",
                        Quantity = 3,
                        UnitPricePiastres = 1000,
                        TotalPiastres = 2000,
                    },
                ],
                SubtotalPiastres = 3000,
                DiscountPiastres = 1000,
                DiscountPercent = 33,
                TotalPiastres = 2000,
                CreatedAt = DateTime.Now,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
            };

            var path = await _service.SaveInvoicePdfAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task SaveInvoicePdfAsync_WithValidLogoSvg_RendersWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"invoice_logo_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var logoBase64 = Convert.ToBase64String(
                System.Text.Encoding.UTF8.GetBytes(
                    """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#1c6ea4"/></svg>"""));

            var request = new ReceiptRequest
            {
                StoreName = "Test",
                Items = [],
                CreatedAt = DateTime.Now,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                LogoSvgData = logoBase64,
            };

            var path = await _service.SaveInvoicePdfAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task SaveInvoicePdfAsync_WithScriptSvg_ThrowsLogoRenderException()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"invoice_badlogo_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var logoBase64 = Convert.ToBase64String(
                System.Text.Encoding.UTF8.GetBytes(
                    """<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>"""));

            var request = new ReceiptRequest
            {
                StoreName = "Test",
                Items = [],
                CreatedAt = DateTime.Now,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                LogoSvgData = logoBase64,
            };

            await Assert.ThrowsAsync<LogoRenderException>(
                () => _service.SaveInvoicePdfAsync(request));
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }
}