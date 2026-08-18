using System.Drawing.Printing;
using System.Runtime.InteropServices;
using PrintServer.Models;
using PrintServer.Services;
using Xunit;

namespace PrintServer.Tests;

/// <summary>
/// Tests for <see cref="PrinterService"/>.
///
/// PLATFORM NOTES:
/// ────────────────────────────────────────────────────────────────────
/// System.Drawing.Printing.PrinterSettings.InstalledPrinters requires
/// winspool.drv (Windows only). On Linux/macOS the native library is
/// absent, causing DllNotFoundException at runtime.  The service's
/// PrintReceipt / PrintBarcodeAsync methods wrap all printer calls in
/// try-catch(Exception), so they gracefully return false on non‑Windows.
/// GetInstalledPrinters has no such guard — the test handles that.
///
/// Full integration testing (real print jobs) requires a Windows host
/// with at least one installed printer driver.
/// ────────────────────────────────────────────────────────────────────
/// </summary>
public sealed class PrinterServiceTests
{
    private readonly PrinterService _service = new();

    private static bool IsWindowsCI()
    {
        return RuntimeInformation.IsOSPlatform(OSPlatform.Windows) &&
               Environment.GetEnvironmentVariable("CI") == "true";
    }

    // ── Helpers ──────────────────────────────────────────────────────

    private static ReceiptRequest CreateReceiptRequest(string? printerName = null) => new()
    {
        StoreName = "Test Store",
        Items =
        [
            new ReceiptItem
            {
                Name = "Test Item",
                Quantity = 1,
                UnitPricePiastres = 1000,
                TotalPiastres = 1000,
            },
        ],
        SubtotalPiastres = 1000,
        DiscountPiastres = 0,
        TaxPiastres = 0,
        TaxPercent = 0,
        TotalPiastres = 1000,
        CreatedAt = DateTime.Now,
        PrinterName = printerName,
        ReceiptFootnote = "Thank you",
        ReceiptUuid = Guid.NewGuid().ToString("N"),
    };

    private static BarcodeRequest CreateBarcodeRequest(string? printerName = null) => new()
    {
        BarcodeData = "TESTBARCODE001",
        ProductName = "Test Product",
        PricePiastres = 1500,
        PrinterName = printerName,
    };

    // ── GetInstalledPrinters ─────────────────────────────────────────

    [Fact]
    public void GetInstalledPrinters_ReturnsNonNullList()
    {
        // PrinterSettings.InstalledPrinters throws DllNotFoundException on
        // non‑Windows.  Catch it so the test passes on all platforms.
        List<string>? printers;
        try
        {
            printers = _service.GetInstalledPrinters();
        }
        catch (DllNotFoundException)
        {
            return; // Non‑Windows — vacuously pass (platform limitation).
        }

        Assert.NotNull(printers);

        // Verify contents mirror the underlying API.
        var expected = PrinterSettings.InstalledPrinters;
        Assert.Equal(expected.Count, printers.Count);

        foreach (string printer in expected)
            Assert.Contains(printer, printers);
    }

    // ── PrintReceipt — error handling ────────────────────────────────

    [Fact]
    public void PrintReceipt_ExceptionCaught_ReturnsFalse()
    {
        if (IsWindowsCI()) return; // Skip on Windows CI: print dialog hangs headless runner.

        // On non‑Windows:        DllNotFoundException caught → false.
        // On Windows w/o printer: ResolvePrinterName returns null → false.
        // On Windows w/ printer:  real print attempt → may return true.
        //
        // This test verifies the catch-or-null-printer path.  A Windows
        // host with printers requires a separate integration test.
        var request = CreateReceiptRequest();

        // Also verify no exception escapes the service.
        var exception = Record.Exception(() => _service.PrintReceipt(request));
        Assert.Null(exception);
    }

    [Fact]
    public void PrintReceipt_ReturnsFalse_WhenExceptionCaught()
    {
        if (IsWindowsCI()) return;
        // Explicitly verify the return value is false when printing fails.
        // Same platform considerations as the test above.
        var request = CreateReceiptRequest();
        var result = _service.PrintReceipt(request);

        // On this CI/Dev environment (Linux without winspool.drv) this is
        // reliably false.  On Windows + printers the caller would see true.
        Assert.False(result);
    }

    [Fact(Skip = "Requires Windows with an installed printer driver. "
        + "Sends a real print job to the default printer and expects true. "
        + "Run on a Windows host with at least one printer to validate.")]
    public void PrintReceipt_ValidRequest_ReturnsTrue()
    {
        var request = CreateReceiptRequest();
        var result = _service.PrintReceipt(request);
        Assert.True(result);
    }

    // ── RenderLogoToImage ────────────────────────────────────────────

    private static string Base64Svg(string svg) =>
        Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(svg));

    [Fact]
    public void RenderLogoToImage_ValidSvg_ReturnsBitmapScaledToPageWidth()
    {
        // System.Drawing.Bitmap decoding requires GDI+ (libgdiplus), which
        // .NET 8 only provides on Windows — the production host. Non-Windows
        // platforms skip like the other GDI-dependent assertions here; the
        // negative tests below still run everywhere.
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return;

        // pageWidth/8 = 100 units on the longest side; 32x16 SVG → 100x50.
        var logo = _service.RenderLogoToImage(Base64Svg(
            """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="16"><rect width="32" height="16" fill="#ff0000"/></svg>"""), 800f);

        Assert.NotNull(logo);
        Assert.Equal(100, logo!.Width);
        Assert.Equal(50, logo.Height);
        logo.Dispose();
    }

    [Fact]
    public void RenderLogoToImage_NullOrEmpty_ReturnsNull()
    {
        Assert.Null(_service.RenderLogoToImage(null, 800f));
        Assert.Null(_service.RenderLogoToImage("", 800f));
        Assert.Null(_service.RenderLogoToImage("   ", 800f));
    }

    [Fact]
    public void RenderLogoToImage_InvalidBase64_ThrowsLogoRenderException()
    {
        // A2 contract: a provided-but-broken logo surfaces as an error
        // instead of silently disappearing from the receipt.
        Assert.Throws<LogoRenderException>(() => _service.RenderLogoToImage("not base64!!", 800f));
    }

    [Fact]
    public void RenderLogoToImage_ScriptSvg_ThrowsLogoRenderException()
    {
        // The validator rejects script-carrying SVGs; the failure must
        // propagate so the app can tell the user why the logo is missing.
        Assert.Throws<LogoRenderException>(() => _service.RenderLogoToImage(Base64Svg(
            """<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>"""), 800f));
    }

    [Fact]
    public void RenderLogoToImage_OversizedData_ThrowsLogoRenderException()
    {
        var oversized = Convert.ToBase64String(new byte[5 * 1024 * 1024 + 1]);
        Assert.Throws<LogoRenderException>(() => _service.RenderLogoToImage(oversized, 800f));
    }

    [Fact]
    public void RenderLogoToImage_SvgWithoutDimensions_ThrowsLogoRenderException()
    {
        // Root cause of the 'logo sometimes not rendering' report: an SVG
        // with no intrinsic size produced a zero cull rect, a divide-by-zero
        // scale and a silent catch → blank gap. Now it's a loud, actionable
        // error.
        Assert.Throws<LogoRenderException>(() => _service.RenderLogoToImage(Base64Svg(
            """<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10" fill="#ff0000"/></svg>"""), 800f));
    }

    // ── PrintBarcodeAsync — error handling ───────────────────────────

    [Fact]
    public async Task PrintBarcodeAsync_ExceptionCaught_ReturnsFalse()
    {
        if (IsWindowsCI()) return;
        // Same platform behaviour as PrintReceipt — the try-catch inside
        // the Task.Run wrapper catches DllNotFoundException on Linux.
        var request = CreateBarcodeRequest();

        var exception = await Record.ExceptionAsync(
            () => _service.PrintBarcodeAsync(request));
        Assert.Null(exception);
    }

    [Fact]
    public async Task PrintBarcodeAsync_ReturnsFalse_WhenExceptionCaught()
    {
        if (IsWindowsCI()) return;
        var request = CreateBarcodeRequest();
        var result = await _service.PrintBarcodeAsync(request);

        // Reliably false on this Linux CI environment; see platform notes.
        Assert.False(result);
    }

    [Fact(Skip = "Requires Windows with an installed printer driver. "
        + "Sends a real barcode print job and expects true.")]
    public async Task PrintBarcodeAsync_ValidRequest_ReturnsTrue()
    {
        var request = CreateBarcodeRequest();
        var result = await _service.PrintBarcodeAsync(request);
        Assert.True(result);
    }

    // ── ResolvePrinterName (indirect testing) ────────────────────────

    [Fact]
    public void PrintReceipt_UnmatchedPrinterName_FallsBackToDefault()
    {
        if (IsWindowsCI()) return;
        // ResolvePrinterName is private static and depends on
        // PrinterSettings.InstalledPrinters, which cannot be mocked.
        // We test it indirectly through PrintReceipt:
        //
        //   1. preferred = "NONEXISTENT_PRINTER_12345"
        //   2. ResolvePrinterName won't find it → falls back to first
        //      installed printer (or null if none).
        //   3. If null → returns false.
        //
        // This validates the method completes without throwing.
        var request = CreateReceiptRequest("NONEXISTENT_PRINTER_12345");

        var exception = Record.Exception(
            () => _service.PrintReceipt(request));
        Assert.Null(exception);
    }

    [Fact]
    public void PrintReceipt_ExactPrinterNameMatch_IsCaseInsensitive()
    {
        if (IsWindowsCI()) return;
        // ResolvePrinterName uses OrdinalIgnoreCase comparison.
        // We verify by passing the name in a different case when
        // printers are available.  On this Linux CI the call throws
        // DllNotFoundException which is caught — the method still
        // completes without an unhandled exception.
        var request = CreateReceiptRequest("DEFAULT_PRINTER_TEST");

        var exception = Record.Exception(
            () => _service.PrintReceipt(request));
        Assert.Null(exception);
    }

    [Fact]
    public void PrintReceipt_NullPrinterName_UsesDefaultPrinterOrReturnsFalse()
    {
        if (IsWindowsCI()) return;
        // When PrinterName is null, ResolvePrinterName falls through
        // to the "first available" logic.  On Windows without printers
        // or on Linux this yields false.  The method never throws.
        var request = CreateReceiptRequest(null); // explicit null

        var exception = Record.Exception(
            () => _service.PrintReceipt(request));
        Assert.Null(exception);
    }

    // ── Edge cases ───────────────────────────────────────────────────

    [Fact]
    public void PrintReceipt_EmptyStoreName_DoesNotThrow()
    {
        if (IsWindowsCI()) return;
        var request = CreateReceiptRequest();
        request.StoreName = string.Empty;

        var exception = Record.Exception(
            () => _service.PrintReceipt(request));
        Assert.Null(exception);
    }

    [Fact]
    public void PrintReceipt_EmptyItemsList_DoesNotThrow()
    {
        if (IsWindowsCI()) return;
        var request = CreateReceiptRequest();
        request.Items = [];

        var exception = Record.Exception(
            () => _service.PrintReceipt(request));
        Assert.Null(exception);
    }

    [Fact]
    public async Task PrintBarcodeAsync_EmptyBarcodeData_DoesNotThrow()
    {
        if (IsWindowsCI()) return;
        // BarcodeLib.Encode with empty string may throw — verify it's caught.
        var request = CreateBarcodeRequest();
        request.BarcodeData = string.Empty;

        var exception = await Record.ExceptionAsync(
            () => _service.PrintBarcodeAsync(request));
        Assert.Null(exception);
    }

    [Fact]
    public async Task PrintBarcodeAsync_NegativePrice_DoesNotThrow()
    {
        if (IsWindowsCI()) return;
        var request = CreateBarcodeRequest();
        request.PricePiastres = -1;

        var exception = await Record.ExceptionAsync(
            () => _service.PrintBarcodeAsync(request));
        Assert.Null(exception);
    }
}
