using PrintServer.Models;
using PrintServer.Services;
using Xunit;

namespace PrintServer.Tests;

public sealed class ImageExportServiceTests
{
    private readonly ImageExportService _service = new();

    [Fact]
    public async Task SaveReceiptAsPngAsync_OverwritesExistingFile_NoStaleTrailingBytes()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"png_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = new ReceiptRequest
            {
                StoreName = "Test",
                Items = [new ReceiptItem { Name = "Item", Quantity = 1, UnitPricePiastres = 1000, TotalPiastres = 1000 }],
                SubtotalPiastres = 1000,
                TotalPiastres = 1000,
                CreatedAt = DateTime.Now,
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
            };

            var firstPath = await _service.SaveReceiptAsPngAsync(request);
            Assert.NotNull(firstPath);
            var firstLen = new FileInfo(firstPath!).Length;

            var request2 = new ReceiptRequest
            {
                StoreName = "Short",
                Items = [],
                SubtotalPiastres = 0,
                TotalPiastres = 0,
                CreatedAt = DateTime.Now,
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
            };

            var secondPath = await _service.SaveReceiptAsPngAsync(request2);
            Assert.NotNull(secondPath);
            var secondLen = new FileInfo(secondPath!).Length;

            Assert.True(secondLen > 0, "Second file should not be empty");
            Assert.True(secondLen < firstLen,
                "Second (shorter) file must be strictly smaller — no trailing bytes from first write");
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task SaveReceiptAsPngAsync_WithValidLogoSvg_RendersWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"png_logo_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var logoBase64 = Convert.ToBase64String(
                System.Text.Encoding.UTF8.GetBytes(
                    """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#ff0000"/></svg>"""));

            var request = new ReceiptRequest
            {
                StoreName = "Test",
                Items = [],
                CreatedAt = DateTime.Now,
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                LogoSvgData = logoBase64,
            };

            var path = await _service.SaveReceiptAsPngAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task SaveReceiptAsPngAsync_WithScriptSvg_SkipsLogoWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"png_badlogo_test_{Guid.NewGuid():N}");
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
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                LogoSvgData = logoBase64,
            };

            var path = await _service.SaveReceiptAsPngAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }
}
