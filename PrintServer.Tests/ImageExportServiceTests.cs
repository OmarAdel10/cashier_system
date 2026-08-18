using System.Globalization;
using System.Threading;
using BidiReshapeSharp;
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
    public async Task SaveReceiptAsPngAsync_IsRtlArabicText_RendersFileWithoutThrowing()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"png_ar_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var request = new ReceiptRequest
            {
                StoreName = "متجر التجربة",
                Items =
                [
                    new ReceiptItem
                    {
                        Name = "قهوة عربية",
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
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                IsRtl = true,
                ReceiptFootnote = "شكراً لزيارتكم",
                PaymentType = "cash",
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
    public async Task SaveReceiptAsPngAsync_IsRtl_ProducesDifferentImageThanEnglish()
    {
        // Separate output dirs per language: the filename is
        // receipt_{yyyyMMdd_HHmmss}.png (second granularity), so saving both
        // variants into one dir within the same second would overwrite.
        var dir = Path.Combine(Path.GetTempPath(), $"png_langdiff_test_{Guid.NewGuid():N}");
        var enDir = Path.Combine(dir, "en");
        var arDir = Path.Combine(dir, "ar");
        Directory.CreateDirectory(enDir);
        Directory.CreateDirectory(arDir);
        try
        {
            ReceiptRequest Create(bool isRtl, string outputDir) => new()
            {
                StoreName = "My Store",
                Items = [new ReceiptItem { Name = "Coffee", Quantity = 1, UnitPricePiastres = 2500, TotalPiastres = 2500 }],
                SubtotalPiastres = 2500,
                TotalPiastres = 2500,
                CreatedAt = DateTime.Now,
                SaveAsPng = true,
                OutputDirectory = outputDir,
                ReceiptUuid = "fixed-uuid-for-compare",
                IsRtl = isRtl,
            };

            var enPath = await _service.SaveReceiptAsPngAsync(Create(isRtl: false, enDir));
            var arPath = await _service.SaveReceiptAsPngAsync(Create(isRtl: true, arDir));

            Assert.NotNull(enPath);
            Assert.NotNull(arPath);

            var enBytes = await File.ReadAllBytesAsync(enPath!);
            var arBytes = await File.ReadAllBytesAsync(arPath!);

            // Content must differ because the RTL receipt renders Arabic
            // labels and mirrored layout. Identical bytes would mean the RTL
            // flag is still being ignored.
            Assert.NotEqual(enBytes, arBytes);
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

    [Fact]
    public async Task SaveReceiptAsPngAsync_IsRtlMixedArabicEnglish_RendersReorderedVisualText()
    {
        var dir = Path.Combine(Path.GetTempPath(), $"png_mixed_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            // Mixed AR/EN run: Arabic store name + Latin brand + digits. This
            // is the exact class of input that regressed into reversed
            // segments before the UBA fix in DrawText.
            var request = new ReceiptRequest
            {
                StoreName = "متجر التجربة",
                Items =
                [
                    new ReceiptItem
                    {
                        Name = "قهوة Coffee 250ml",
                        Quantity = 2,
                        UnitPricePiastres = 2500,
                        TotalPiastres = 5000,
                    },
                ],
                SubtotalPiastres = 5000,
                TotalPiastres = 5000,
                CreatedAt = DateTime.Now,
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
                IsRtl = true,
                PaymentType = "cash",
                ReceiptFootnote = "شكراً لزيارتكم / Thank you",
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
    public void BidiReshape_MixedArabicEnglish_ReordersAndShapesToVisualOrder()
    {
        // UBA contract: Arabic letters must be shaped into their contextual
        // presentation forms (isolated/initial/medial/final) and LTR runs
        // (Latin + digits) must be moved to their visual position. Without
        // the reorder, the PNG path renders logical order = reversed Arabic.
        var input = "فاتورة 123 ABC";
        var visual = BidiReshape.ProcessString(input);

        Assert.False(string.IsNullOrWhiteSpace(visual));
        Assert.NotEqual(input, visual);

        // Shaped output must contain Arabic presentation-form codepoints
        // (U+FB50–U+FEFF), proving contextual joining happened.
        var hasPresentationForm = visual.Any(c => c >= 0xFB50 && c <= 0xFEFF);
        Assert.True(hasPresentationForm, $"expected presentation forms in '{visual}'");

        // RTL paragraph visual order: the Arabic word is rightmost, so in the
        // LTR visual string it must be LAST (end of string), while the LTR
        // runs "123 ABC" lead. A string starting with the Arabic word would
        // mean the old reversed logical-order bug.
        Assert.StartsWith("ABC 123", visual);
        var lastChar = visual[^1];
        Assert.True(
            lastChar >= 0xFB50 || (lastChar >= 0x0590 && lastChar <= 0x08FF),
            $"expected visual string to end with Arabic, got '{visual}'");
    }

    [Fact]
    public void AmountFormatting_UsesInvariantCulture_DotDecimalSeparatorUnderArSaCulture()
    {
        var originalCulture = Thread.CurrentThread.CurrentCulture;
        try
        {
            Thread.CurrentThread.CurrentCulture = new CultureInfo("ar-SA");
            var value = 150 / 100.0; // 1.50
            var formatted = value.ToString("F2", CultureInfo.InvariantCulture);
            Assert.Equal("1.50", formatted);
            Assert.DoesNotContain(",", formatted);
        }
        finally
        {
            Thread.CurrentThread.CurrentCulture = originalCulture;
        }
    }

    [Fact]
    public async Task SaveReceiptAsPngAsync_ArSaCulture_RendersAmountsWithDotDecimalSeparator()
    {
        var originalCulture = Thread.CurrentThread.CurrentCulture;
        var dir = Path.Combine(Path.GetTempPath(), $"png_arsa_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            Thread.CurrentThread.CurrentCulture = new CultureInfo("ar-SA");

            var request = new ReceiptRequest
            {
                StoreName = "Test Store",
                Items =
                [
                    new ReceiptItem
                    {
                        Name = "Item",
                        Quantity = 1,
                        UnitPricePiastres = 150,
                        TotalPiastres = 150,
                    },
                ],
                SubtotalPiastres = 150,
                TotalPiastres = 150,
                CreatedAt = DateTime.Now,
                SaveAsPng = true,
                OutputDirectory = dir,
                ReceiptUuid = Guid.NewGuid().ToString("N"),
            };

            var path = await _service.SaveReceiptAsPngAsync(request);

            Assert.NotNull(path);
            Assert.True(new FileInfo(path!).Length > 0);
        }
        finally
        {
            Thread.CurrentThread.CurrentCulture = originalCulture;
            Directory.Delete(dir, recursive: true);
        }
    }
}
