using System.Collections.Concurrent;
using System.Drawing;
using System.Drawing.Printing;
using System.Runtime.InteropServices;
using BarcodeLib;
using BidiReshapeSharp;
using PrintServer.Linux.Localization;
using PrintServer.Linux.Models;
using SkiaSharp;
using SkiaSharp.HarfBuzz;
using Svg.Skia;

namespace PrintServer.Linux.Services;

public sealed class CupsPrinterService : IDisposable
{
    private readonly SvgValidator _svgValidator = new();
    private readonly ICupsNative _cups;
    private readonly ConcurrentDictionary<(string family, bool bold, SKFontStyleWidth width, SKFontStyleSlant slant, SKFontStyleWeight weight), SKTypeface> _fontCache = new();
    private bool _disposed;

    public CupsPrinterService() : this(CupsNative.Instance) { }

    internal CupsPrinterService(ICupsNative cups)
    {
        _cups = cups;
    }

    private SKTypeface GetTypeface(string family, bool bold, SKFontStyleWidth width = SKFontStyleWidth.Normal, SKFontStyleSlant slant = SKFontStyleSlant.Upright, SKFontStyleWeight? weight = null)
    {
        var effectiveWeight = weight ?? (bold ? SKFontStyleWeight.Bold : SKFontStyleWeight.Normal);
        return _fontCache.GetOrAdd((family, bold, width, slant, effectiveWeight), static key =>
        {
            var (family, bold, width, slant, weight) = key;
            return SKTypeface.FromFamilyName(family, weight, width, slant)
                   ?? SKTypeface.Default; // Don't cache Default; return fresh reference each time
        });
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        foreach (var tf in _fontCache.Values)
            tf.Dispose();
        _fontCache.Clear();
    }

    // ===== CUPS NATIVE INTEROP =====
    internal interface ICupsNative
    {
        int GetDests(out IntPtr dests);
        void FreeDests(int numDests, IntPtr dests);
        IntPtr GetDefault();
        int PrintFile(string printer, string filename, string title, int numOptions, IntPtr options);
    }

    internal sealed class CupsNative : ICupsNative
    {
        internal static readonly CupsNative Instance = new();

        private CupsNative() { }

        public int GetDests(out IntPtr dests) => CupsGetDests(out dests);

        public void FreeDests(int numDests, IntPtr dests) => CupsFreeDests(numDests, dests);

        public IntPtr GetDefault() => CupsGetDefault();

        public int PrintFile(string printer, string filename, string title, int numOptions, IntPtr options) =>
            CupsPrintFile(printer, filename, title, numOptions, options);

        [DllImport("cups", EntryPoint = "cupsGetDests", CallingConvention = CallingConvention.Cdecl)]
        private static extern int CupsGetDests(out IntPtr dests);

        [DllImport("cups", EntryPoint = "cupsFreeDests", CallingConvention = CallingConvention.Cdecl)]
        private static extern void CupsFreeDests(int numDests, IntPtr dests);

        [DllImport("cups", EntryPoint = "cupsGetDefault", CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr CupsGetDefault();

        [DllImport("cups", EntryPoint = "cupsPrintFile", CallingConvention = CallingConvention.Cdecl)]
        private static extern int CupsPrintFile(string printer, string filename, string title, int numOptions, IntPtr options);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct CupsDest
    {
        public IntPtr Name;
        public IntPtr Instance;
        public int IsDefault;
        public int NumOptions;
        public IntPtr Options;
    }

    // ===== PUBLIC API =====

    public List<string> GetInstalledPrinters()
    {
        var printers = new List<string>();
        int numDests = _cups.GetDests(out IntPtr destsPtr);
        try
        {
            for (int i = 0; i < numDests; i++)
            {
                var destPtr = IntPtr.Add(destsPtr, i * Marshal.SizeOf<CupsDest>());
                var dest = Marshal.PtrToStructure<CupsDest>(destPtr);
                var name = Marshal.PtrToStringAnsi(dest.Name);
                if (!string.IsNullOrEmpty(name))
                    printers.Add(name);
            }
        }
        finally
        {
            _cups.FreeDests(numDests, destsPtr);
        }
        return printers;
    }

    public string? GetDefaultPrinter()
    {
        var defaultPtr = _cups.GetDefault();
        if (defaultPtr == IntPtr.Zero) return null;
        return Marshal.PtrToStringAnsi(defaultPtr);
    }

    // ===== RECEIPT PRINTING (CUPS RAW) =====

    public bool PrintReceipt(ReceiptRequest request)
    {
        var printerName = ResolvePrinterName(request.PrinterName);
        if (printerName == null) return false;

        using var bitmap = RenderReceiptToBitmap(request);
        using var stream = new MemoryStream();
        bitmap.Encode(SKEncodedImageFormat.Png, 100).SaveTo(stream);
        var pngBytes = stream.ToArray();

        return PrintRaw(printerName, pngBytes, $"Receipt_{DateTime.Now:yyyyMMddHHmmss}");
    }

    public string? PrintReceiptToFile(ReceiptRequest request)
    {
        if (!request.PrintToFile || string.IsNullOrWhiteSpace(request.PrintFileName))
            return null;

        var dir = Path.GetDirectoryName(request.PrintFileName);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        // For "Print to File" on Linux: generate PDF via InvoiceService
        // This is handled by the endpoint which calls InvoiceService directly
        return null;
    }

    // ===== BARCODE PRINTING =====

    public async Task<bool> PrintBarcodeAsync(BarcodeRequest request)
    {
        return await Task.Run(() =>
        {
            var printerName = ResolvePrinterName(request.PrinterName);
            if (printerName == null) return false;

            using var barcodeBitmap = GenerateBarcodeImage(request.BarcodeData);
            using var skBitmap = BitmapToSKBitmap(barcodeBitmap);
            using var stream = new MemoryStream();
            skBitmap.Encode(SKEncodedImageFormat.Png, 100).SaveTo(stream);
            var pngBytes = stream.ToArray();

            return PrintRaw(printerName, pngBytes, $"Barcode_{request.BarcodeData}");
        });
    }

    // ===== KITCHEN/BAR/SHISHA TICKETS =====

    public bool PrintTicket(TicketRequest request)
    {
        var printerName = ResolvePrinterName(request.PrinterName);
        if (printerName == null) return false;

        using var bitmap = RenderTicketToBitmap(request);
        using var stream = new MemoryStream();
        bitmap.Encode(SKEncodedImageFormat.Png, 100).SaveTo(stream);
        var pngBytes = stream.ToArray();

        return PrintRaw(printerName, pngBytes, $"Ticket_{request.OrderNumber}");
    }

    // ===== CUPS RAW PRINT HELPER =====

    private bool PrintRaw(string printerName, byte[] data, string jobTitle)
    {
        var tempFile = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName() + ".png");
        try
        {
            File.WriteAllBytes(tempFile, data);
            int jobId = _cups.PrintFile(printerName, tempFile, jobTitle, 0, IntPtr.Zero);
            return jobId > 0;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[CupsPrinterService] PrintRaw failed: {ex}");
            return false;
        }
        finally
        {
            try { File.Delete(tempFile); } catch { }
        }
    }

    // ===== RENDERING (Ported from Windows ImageExportService) =====

    private const float Width = 384;
    private const float Margin = 20;

    private SKBitmap RenderReceiptToBitmap(ReceiptRequest request)
    {
        var height = CalculateHeight(request);

        using var surface = SKSurface.Create(new SKImageInfo((int)Width, (int)height));
        var canvas = surface.Canvas;
        canvas.Clear(SKColors.White);

        DrawReceipt(canvas, request);

        using var image = surface.Snapshot();
        return SKBitmap.FromImage(image);
    }

    private float CalculateHeight(ReceiptRequest request)
    {
        const float maxBitmapHeightPx = 60000f;
        float h = 0;

        if (!string.IsNullOrWhiteSpace(request.LogoSvgData))
            h += MeasureLogoHeight(request.LogoSvgData) + 8;

        h += 32; // Header
        h += 16; // Dashed divider

        if (!string.IsNullOrWhiteSpace(request.OrderNumber))
            h += 24;
        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            h += 24;
        if (!string.IsNullOrWhiteSpace(request.StorePhone))
            h += 24;
        if (!string.IsNullOrWhiteSpace(request.UserName))
            h += 24;
        h += 24; // Date

        if (!string.IsNullOrWhiteSpace(request.PaymentType))
            h += 24;

        h += 16; // Dashed divider
        h += 24; // Table headers
        h += 16; // Dashed divider

        h += request.Items.Count * 40f; // Items with dividers

        var hasSubtotal = request.TaxPiastres > 0 || request.DiscountPiastres > 0;
        var hasTax = request.TaxPiastres > 0;
        var hasDiscount = request.DiscountPiastres > 0;
        if (hasSubtotal) h += 24;
        if (hasTax) h += 24;
        if (hasDiscount) h += 24;

        h += 32; // Total
        h += 16; // Dashed divider

        if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
            h += 30;

        h += 24; // UUID

        return Math.Min(h + Margin, maxBitmapHeightPx);
    }

    private void DrawReceipt(SKCanvas canvas, ReceiptRequest request)
    {
        using var dashPaint = new SKPaint
        {
            Color = SKColors.Gray,
            StrokeWidth = 1,
            Style = SKPaintStyle.Stroke,
            PathEffect = SKPathEffect.CreateDash(new[] { 4f, 4f }, 0),
            IsAntialias = true,
        };

        var isRtl = request.IsRtl;

        // Fonts are cached per (family, bold, weight) and disposed on service shutdown.
        // Consolas originally used SemiBold weight; Segoe UI uses Bold.
        var arTypeface = isRtl ? LoadArabicTypeface() : null;
        var enBoldTypeface = GetTypeface("Consolas", true, weight: SKFontStyleWeight.SemiBold);
        var enNormalTypeface = GetTypeface("Consolas", false);
        using var shaper = isRtl && arTypeface != null ? new SKShaper(arTypeface) : null;

        SKTypeface boldTypeface = isRtl && arTypeface != null ? arTypeface : enBoldTypeface;
        SKTypeface normalTypeface = isRtl && arTypeface != null ? arTypeface : enNormalTypeface;

        var labelX = isRtl ? Width - Margin : Margin;

        float y = Margin;

        // ---- Logo ----
        if (!string.IsNullOrWhiteSpace(request.LogoSvgData))
        {
            DrawLogo(canvas, request.LogoSvgData, ref y);
        }

        // ---- Header ----
        using var headerPaint = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 18,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Center,
        };
        var headerText = ReceiptLabels.Format(ReceiptLabels.Welcome, isRtl, request.StoreName);
        TextDraw.DrawText(canvas, shaper, isRtl, headerText, headerPaint, Width / 2f, y + headerPaint.TextSize,
            RtlAlign.Center);
        y += 28;

        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Metadata ----
        using var metaPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 11,
            Color = SKColors.DimGray,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        var metaLineHeight = 22f;

        if (!string.IsNullOrWhiteSpace(request.OrderNumber))
        {
            var ordLabel = ReceiptLabels.Label(ReceiptLabels.OrderNumber, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, ordLabel, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var ordLabelW = TextDraw.MeasureVisual(ordLabel, metaPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, request.OrderNumber, metaPaint,
                isRtl ? labelX - ordLabelW - 4f : labelX + ordLabelW + 4f, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
        {
            var addressLabel = ReceiptLabels.Label(ReceiptLabels.Address, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, addressLabel, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var addressLabelW = TextDraw.MeasureVisual(addressLabel, metaPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, request.StoreAddress, metaPaint,
                isRtl ? labelX - addressLabelW - 4f : labelX + addressLabelW + 4f, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        if (!string.IsNullOrWhiteSpace(request.StorePhone))
        {
            var phoneLabel = ReceiptLabels.Label(ReceiptLabels.Phone, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, phoneLabel, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var phoneLabelW = TextDraw.MeasureVisual(phoneLabel, metaPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, request.StorePhone, metaPaint,
                isRtl ? labelX - phoneLabelW - 4f : labelX + phoneLabelW + 4f, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        if (!string.IsNullOrWhiteSpace(request.UserName))
        {
            var shiftTime = ParseDateTime(request.ShiftStartedAt);
            var timeStr = shiftTime.HasValue
                ? shiftTime.Value.ToString("h:mm tt", System.Globalization.CultureInfo.InvariantCulture)
                : "";
            var shiftLabel = ReceiptLabels.Label(ReceiptLabels.Shift, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, shiftLabel, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var shiftLabelW = TextDraw.MeasureVisual(shiftLabel, metaPaint, isRtl);
            var shiftNameX = isRtl ? labelX - shiftLabelW - 4f : labelX + shiftLabelW + 4f;
            TextDraw.DrawText(canvas, shaper, isRtl, request.UserName, metaPaint, shiftNameX,
                y + metaPaint.TextSize, isRtl ? RtlAlign.Right : RtlAlign.Left);
            if (!string.IsNullOrWhiteSpace(timeStr))
            {
                var shiftNameW = TextDraw.MeasureVisual(request.UserName, metaPaint, isRtl);
                TextDraw.DrawText(canvas, shaper, isRtl, timeStr, metaPaint,
                    isRtl ? shiftNameX - shiftNameW - 4f : shiftNameX + shiftNameW + 4f,
                    y + metaPaint.TextSize, isRtl ? RtlAlign.Right : RtlAlign.Left);
            }
            y += metaLineHeight;
        }

        var dateLabel = ReceiptLabels.Label(ReceiptLabels.Date, isRtl);
        var dateValue = request.CreatedAt.ToString("yyyy-MM-dd h:mm tt", System.Globalization.CultureInfo.InvariantCulture);
        TextDraw.DrawText(canvas, shaper, isRtl, dateLabel, metaPaint, labelX, y + metaPaint.TextSize,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        var dateLabelW = TextDraw.MeasureVisual(dateLabel, metaPaint, isRtl);
        TextDraw.DrawText(canvas, shaper, isRtl, dateValue, metaPaint,
            isRtl ? labelX - dateLabelW - 4f : labelX + dateLabelW + 4f, y + metaPaint.TextSize,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        y += metaLineHeight;

        if (!string.IsNullOrWhiteSpace(request.PaymentType))
        {
            var paymentLabel = ReceiptLabels.Label(ReceiptLabels.PaymentTypeLabel, isRtl);
            var paymentValue = ReceiptLabels.PaymentType(request.PaymentType, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, paymentLabel, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var paymentLabelW = TextDraw.MeasureVisual(paymentLabel, metaPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, paymentValue, metaPaint,
                isRtl ? labelX - paymentLabelW - 4f : labelX + paymentLabelW + 4f, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Table headers ----
        var col1X = Margin;
        var col2X = Width / 2f;
        var col3X = Width - Margin;

        using var leftBold = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 11,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        using var rightBold = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 11,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = isRtl ? SKTextAlign.Left : SKTextAlign.Right,
        };

        var itemDescHeader = ReceiptLabels.Get(ReceiptLabels.ItemDescription, isRtl);
        var priceHeader = ReceiptLabels.Get(ReceiptLabels.Price, isRtl);
        var totalHeader = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);
        if (isRtl)
        {
            TextDraw.DrawText(canvas, shaper, isRtl, itemDescHeader, leftBold, col3X, y + 11, RtlAlign.Right);
        }
        else
        {
            TextDraw.DrawText(canvas, shaper, isRtl, itemDescHeader, leftBold, col1X, y + 11, RtlAlign.Left);
        }

        TextDraw.DrawText(canvas, shaper, isRtl, priceHeader, leftBold, col2X, y + 11, RtlAlign.Center);
        TextDraw.DrawText(canvas, shaper, isRtl, totalHeader, rightBold, isRtl ? col1X : col3X, y + 11,
            isRtl ? RtlAlign.Left : RtlAlign.Right);
        y += 22;

        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Items ----
        using var itemLeftPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 12,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        using var itemRightPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 12,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = isRtl ? SKTextAlign.Left : SKTextAlign.Right,
        };
        using var itemCenterPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 12,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = isRtl ? SKTextAlign.Left : SKTextAlign.Center,
        };

        foreach (var item in request.Items)
        {
            var desc = $"{item.Name} x{item.Quantity}";
            var unitPrice = ReceiptLabels.FormatCurrency(item.UnitPricePiastres, isRtl);
            var totalPrice = ReceiptLabels.FormatCurrency(item.TotalPiastres, isRtl);

            TextDraw.DrawText(canvas, shaper, isRtl, desc, itemLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            TextDraw.DrawText(canvas, shaper, isRtl, unitPrice, itemCenterPaint, col2X, y + 12, RtlAlign.Center);
            TextDraw.DrawText(canvas, shaper, isRtl, totalPrice, itemRightPaint, isRtl ? col1X : col3X, y + 12,
                isRtl ? RtlAlign.Left : RtlAlign.Right);
            y += 24;

            DrawDashedLine(canvas, y, dashPaint);
            y += 14;
        }

        // ---- Calculations ----
        var hasTax = request.TaxPiastres > 0;
        var hasDiscount = request.DiscountPiastres > 0;
        var showSubtotal = hasTax || hasDiscount;

        using var financeLeftPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 12,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        using var financeRightPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 12,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = isRtl ? SKTextAlign.Left : SKTextAlign.Right,
        };

        if (showSubtotal)
        {
            var subtotalLabel = ReceiptLabels.Get(ReceiptLabels.Subtotal, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, subtotalLabel, financeLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            TextDraw.DrawText(canvas, shaper, isRtl,
                ReceiptLabels.FormatCurrency(request.SubtotalPiastres, isRtl),
                financeRightPaint, isRtl ? col1X : col3X, y + 12, isRtl ? RtlAlign.Left : RtlAlign.Right);
            y += 24;
        }

        if (hasTax)
        {
            var taxLabel = ReceiptLabels.Label(ReceiptLabels.Tax, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, taxLabel, financeLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var taxLabelW = TextDraw.MeasureVisual(taxLabel, financeLeftPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl,
                string.Format("({0}%)", request.TaxPercent), financeLeftPaint,
                isRtl ? col3X - taxLabelW - 4f : col1X + taxLabelW + 4f, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            TextDraw.DrawText(canvas, shaper, isRtl,
                "+" + ReceiptLabels.FormatCurrency(request.TaxPiastres, isRtl),
                financeRightPaint, isRtl ? col1X : col3X, y + 12, isRtl ? RtlAlign.Left : RtlAlign.Right);
            y += 24;
        }

        if (hasDiscount)
        {
            var discountLabel = ReceiptLabels.Label(ReceiptLabels.Discount, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, discountLabel, financeLeftPaint, isRtl ? col3X : col1X,
                y + 12, isRtl ? RtlAlign.Right : RtlAlign.Left);
            var discountLabelW = TextDraw.MeasureVisual(discountLabel, financeLeftPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl,
                string.Format("({0}%)", request.DiscountPercent), financeLeftPaint,
                isRtl ? col3X - discountLabelW - 4f : col1X + discountLabelW + 4f, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            TextDraw.DrawText(canvas, shaper, isRtl,
                "-" + ReceiptLabels.FormatCurrency(request.DiscountPiastres, isRtl),
                financeRightPaint, isRtl ? col1X : col3X, y + 12, isRtl ? RtlAlign.Left : RtlAlign.Right);
            y += 24;
        }

        // ---- Total ----
        using var totalLeftPaint = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 14,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        using var totalRightPaint = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 14,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = isRtl ? SKTextAlign.Left : SKTextAlign.Right,
        };
        var totalLabel = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);
        TextDraw.DrawText(canvas, shaper, isRtl, totalLabel, totalLeftPaint, isRtl ? col3X : col1X, y + 14,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        TextDraw.DrawText(canvas, shaper, isRtl,
            ReceiptLabels.FormatCurrency(request.TotalPiastres, isRtl),
            totalRightPaint, isRtl ? col1X : col3X, y + 14, isRtl ? RtlAlign.Left : RtlAlign.Right);
        y += 30;

        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Footer ----
        using var footnotePaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 11,
            Color = SKColors.Gray,
            IsAntialias = true,
            TextAlign = SKTextAlign.Center,
        };
        if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
        {
            TextDraw.DrawText(canvas, shaper, isRtl, request.ReceiptFootnote, footnotePaint, Width / 2f, y + 11,
                RtlAlign.Center);
            y += 26;
        }

        // UUID
        if (!string.IsNullOrWhiteSpace(request.ReceiptUuid))
        {
            using var uuidPaint = new SKPaint
            {
                Typeface = normalTypeface,
                TextSize = 10,
                Color = SKColors.Gray,
                IsAntialias = true,
                TextAlign = SKTextAlign.Left,
            };
            var uuidLabel = ReceiptLabels.Label(ReceiptLabels.ReceiptUuid, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, uuidLabel, uuidPaint, isRtl ? col3X : Margin, y + 10,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var uuidLabelW = TextDraw.MeasureVisual(uuidLabel, uuidPaint, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, request.ReceiptUuid, uuidPaint,
                isRtl ? col3X - uuidLabelW - 4f : Margin + uuidLabelW + 4f, y + 10,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
        }
    }

    private SKBitmap RenderTicketToBitmap(TicketRequest request)
    {
        const float ticketWidth = 384;

        using var surface = SKSurface.Create(new SKImageInfo((int)ticketWidth, (int)CalculateTicketHeight(request)));
        var canvas = surface.Canvas;
        canvas.Clear(SKColors.White);

        DrawTicket(canvas, request);

        using var image = surface.Snapshot();
        return SKBitmap.FromImage(image);
    }

    private float CalculateTicketHeight(TicketRequest request)
    {
        const float ticketMargin = 20;
        const float maxBitmapHeightPx = 60000f;
        float h = 0;
        h += 30; // Store name
        if (!string.IsNullOrWhiteSpace(request.Category))
            h += 26;
        h += 12; // Divider
        h += 22; // Table/zone
        if (request.RoundNumber > 0)
            h += 20;
        if (!string.IsNullOrWhiteSpace(request.OrderNumber))
            h += 20;
        h += 20; // Fired time
        h += 12; // Divider
        h += request.Items.Count * 22; // Items
        return Math.Min(h + ticketMargin, maxBitmapHeightPx);
    }

    private void DrawTicket(SKCanvas canvas, TicketRequest request)
    {
        const float ticketWidth = 384;
        const float ticketMargin = 20;
        var isRtl = request.IsRtl;
        var centerX = ticketWidth / 2f;

        // Fonts are cached per (family, bold, weight) and disposed on service shutdown.
        // Consolas originally used SemiBold weight.
        var arTypeface = isRtl ? LoadArabicTypeface() : null;
        var consolas = GetTypeface("Consolas", false);
        var consolasBold = GetTypeface("Consolas", true, weight: SKFontStyleWeight.SemiBold);
        using var shaper = isRtl && arTypeface != null ? new SKShaper(arTypeface) : null;

        var fontFamily = isRtl && arTypeface != null ? arTypeface : consolas;

        using var bold16 = new SKPaint { Typeface = consolasBold, TextSize = 16, Color = SKColors.Black, IsAntialias = true, TextAlign = SKTextAlign.Center };
        using var bold12 = new SKPaint { Typeface = consolasBold, TextSize = 12, Color = SKColors.Black, IsAntialias = true, TextAlign = SKTextAlign.Center };
        using var bold10 = new SKPaint { Typeface = consolasBold, TextSize = 10, Color = SKColors.Black, IsAntialias = true, TextAlign = SKTextAlign.Left };
        using var normal10 = new SKPaint { Typeface = consolas, TextSize = 10, Color = SKColors.Black, IsAntialias = true, TextAlign = SKTextAlign.Left };
        using var grayBrush = new SKPaint { Typeface = consolas, TextSize = 10, Color = SKColors.DimGray, IsAntialias = true, TextAlign = SKTextAlign.Left };
        using var dashPaint = new SKPaint { Color = SKColors.Gray, StrokeWidth = 1, Style = SKPaintStyle.Stroke, PathEffect = SKPathEffect.CreateDash(new[] { 4f, 4f }, 0), IsAntialias = true };
        using var centerFmt = new SKPaint { Typeface = consolasBold, TextSize = 10, Color = SKColors.Black, IsAntialias = true, TextAlign = SKTextAlign.Center };

        float y = ticketMargin;

        if (!string.IsNullOrWhiteSpace(request.StoreName))
        {
            TextDraw.DrawText(canvas, shaper, isRtl, request.StoreName, bold16, centerX, y + 16, RtlAlign.Center);
            y += 30;
        }

        if (!string.IsNullOrWhiteSpace(request.Category))
        {
            TextDraw.DrawText(canvas, shaper, isRtl, request.Category.ToUpperInvariant(), bold12, centerX, y + 12, RtlAlign.Center);
            y += 26;
        }

        DrawDashedLine(canvas, y, dashPaint);
        y += 12;

        var location = string.IsNullOrWhiteSpace(request.ZoneName)
            ? request.TableName
            : $"{request.TableName} / {request.ZoneName}";
        TextDraw.DrawText(canvas, shaper, isRtl, location, bold12, ticketMargin, y + 12, RtlAlign.Left);
        y += 22;

        if (request.RoundNumber > 0)
        {
            var roundLabel = ReceiptLabels.Format(ReceiptLabels.Round, isRtl, request.RoundNumber);
            DrawTicketMeta(canvas, roundLabel, normal10, grayBrush, ticketMargin, ticketWidth, y, isRtl);
            y += 20;
        }
        if (!string.IsNullOrWhiteSpace(request.OrderNumber))
        {
            var orderLabel = ReceiptLabels.Format(ReceiptLabels.Order, isRtl, request.OrderNumber);
            DrawTicketMeta(canvas, orderLabel, normal10, grayBrush, ticketMargin, ticketWidth, y, isRtl);
            y += 20;
        }
        var firedLabel = ReceiptLabels.Format(ReceiptLabels.Fired, isRtl, request.CreatedAt.ToString("HH:mm"));
        DrawTicketMeta(canvas, firedLabel, normal10, grayBrush, ticketMargin, ticketWidth, y, isRtl);
        y += 20;

        DrawDashedLine(canvas, y, dashPaint);
        y += 12;

        foreach (var item in request.Items)
        {
            TextDraw.DrawText(canvas, shaper, isRtl, $"{item.Quantity} x {item.Name}", bold10, ticketMargin, y + 10, RtlAlign.Left);
            y += 22;
        }
    }

    private static void DrawTicketMeta(SKCanvas canvas, string text, SKPaint font, SKPaint brush,
        float margin, float pageWidth, float y, bool isRtl)
    {
        if (isRtl)
        {
            TextDraw.DrawText(canvas, null, true, text, font, pageWidth - margin, y, RtlAlign.Right);
        }
        else
        {
            TextDraw.DrawText(canvas, null, false, text, font, margin, y, RtlAlign.Left);
        }
    }

    private void DrawLogo(SKCanvas canvas, string logoSvgData, ref float y)
    {
        if (string.IsNullOrWhiteSpace(logoSvgData))
            return;

        if (!_svgValidator.Validate(logoSvgData).Valid)
            throw new LogoRenderException("logo SVG failed validation");

        byte[] svgBytes;
        try
        {
            svgBytes = Convert.FromBase64String(logoSvgData);
        }
        catch (FormatException ex)
        {
            throw new LogoRenderException("logo is not valid base64", ex);
        }

        if (svgBytes.Length > 5 * 1024 * 1024)
            throw new LogoRenderException("logo exceeds 5MB");

        try
        {
            var svg = new SKSvg();
            using var svgStream = new MemoryStream(svgBytes);
            svg.Load(svgStream);

            if (svg.Picture == null)
                throw new LogoRenderException("logo SVG produced no picture");

            var cullRect = svg.Picture.CullRect;
            if (!float.IsFinite(cullRect.Width) || !float.IsFinite(cullRect.Height) ||
                cullRect.Width <= 0 || cullRect.Height <= 0)
                throw new LogoRenderException(
                    "logo SVG has no intrinsic size (add width/height or viewBox)");

            const float logoMaxSize = 48f;
            var scale = logoMaxSize / Math.Max(cullRect.Width, cullRect.Height);
            var logoW = cullRect.Width * scale;
            var logoH = cullRect.Height * scale;
            var logoX = (Width - logoW) / 2f;

            canvas.Save();
            canvas.Translate(logoX, y);
            canvas.Scale(scale, scale);
            canvas.DrawPicture(svg.Picture, 0, 0, new SKPaint { FilterQuality = SKFilterQuality.Low });
            canvas.Restore();

            y += logoH + 8;
        }
        catch (LogoRenderException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new LogoRenderException($"logo SVG render failed: {ex.Message}", ex);
        }
    }

    private float MeasureLogoHeight(string logoSvgData)
    {
        try
        {
            if (!_svgValidator.Validate(logoSvgData).Valid)
                return 0;

            var svgBytes = Convert.FromBase64String(logoSvgData);
            if (svgBytes.Length > 5 * 1024 * 1024)
                return 0;

            using var svg = new SKSvg();
            using var svgStream = new MemoryStream(svgBytes);
            svg.Load(svgStream);

            if (svg.Picture == null)
                return 0;

            var cullRect = svg.Picture.CullRect;
            if (!float.IsFinite(cullRect.Width) || !float.IsFinite(cullRect.Height) ||
                cullRect.Width <= 0 || cullRect.Height <= 0)
                return 0;

            const float logoMaxSize = 48f;
            var scale = logoMaxSize / Math.Max(cullRect.Width, cullRect.Height);
            return cullRect.Height * scale;
        }
        catch
        {
            return 0;
        }
    }

    private static void DrawDashedLine(SKCanvas canvas, float y, SKPaint dashPaint)
    {
        canvas.DrawLine(Margin, y, Width - Margin, y, dashPaint);
    }

    private static DateTime? ParseDateTime(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        if (DateTime.TryParse(value, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out var dt))
            return dt;

        return null;
    }

    private static SKTypeface LoadArabicTypeface()
    {
        var fontPath = Path.Combine(AppContext.BaseDirectory, "Assets", "NotoNaskhArabic.ttf");
        if (File.Exists(fontPath))
        {
            using var stream = File.OpenRead(fontPath);
            using var data = SKData.Create(stream);
            var typeface = SKTypeface.FromData(data);
            if (typeface != null)
                return typeface;
        }
        return SKTypeface.FromFamilyName("Segoe UI") ?? SKTypeface.Default;
    }

    private Image GenerateBarcodeImage(string barcodeData)
    {
        var b = new BarcodeLib.Barcode
        {
            IncludeLabel = false,
            Alignment = BarcodeLib.AlignmentPositions.CENTER,
            Width = 200,
            Height = 53,
        };
        return b.Encode(BarcodeLib.TYPE.CODE128, barcodeData);
    }

    private SKBitmap BitmapToSKBitmap(Image gdiBitmap)
    {
        using var ms = new MemoryStream();
        gdiBitmap.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
        ms.Position = 0;
        using var skData = SKData.Create(ms);
        var codec = SKCodec.Create(skData);
        var info = codec.Info;
        var bitmap = new SKBitmap(info.Width, info.Height);
        codec.GetPixels(bitmap.Info, bitmap.GetPixels());
        return bitmap;
    }

    internal string? ResolvePrinterName(string? preferred)
    {
        var printers = GetInstalledPrinters();

        if (!string.IsNullOrWhiteSpace(preferred))
        {
            var match = printers.FirstOrDefault(p =>
                p.Equals(preferred, StringComparison.OrdinalIgnoreCase));
            if (match != null) return match;
        }

        var defaultPrinter = GetDefaultPrinter();
        if (!string.IsNullOrWhiteSpace(defaultPrinter) && printers.Contains(defaultPrinter))
            return defaultPrinter;

        return printers.FirstOrDefault();
    }
}

public enum RtlAlign
{
    Left,
    Right,
    Center
}

public static class TextDraw
{
    /// <summary>X position for text whose visual width is w: Right ends at x,
    /// Center straddles x, Left starts at x.</summary>
    public static float FromWidth(float x, float w, RtlAlign align) => align switch
    {
        RtlAlign.Right => x - w,
        RtlAlign.Center => x - w / 2f,
        _ => x,
    };

    public static bool ContainsArabic(string text)
    {
        foreach (var ch in text)
        {
            var c = (int)ch;
            if ((c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F) ||
                (c >= 0x0870 && c <= 0x089F) || (c >= 0x08A0 && c <= 0x08FF) ||
                (c >= 0xFB50 && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF))
                return true;
        }
        return false;
    }

    public static float MeasureVisual(string text, SKPaint paint, bool isRtl)
    {
        if (!isRtl || !ContainsArabic(text)) return paint.MeasureText(text);
        try { return paint.MeasureText(BidiReshape.ProcessString(text)); }
        catch { return paint.MeasureText(text); }
    }

    public static void DrawText(
        SKCanvas canvas, SKShaper? shaper, bool isRtl, string text,
        SKPaint paint, float x, float y, RtlAlign align)
    {
        paint.TextAlign = SKTextAlign.Left;

        if (!isRtl || !ContainsArabic(text))
        {
            canvas.DrawText(text, FromWidth(x, paint.MeasureText(text), align), y, paint);
            return;
        }

        string? visual = null;
        try { visual = BidiReshape.ProcessString(text); }
        catch { /* fall through to HarfBuzz path below */ }

        if (!string.IsNullOrEmpty(visual))
        {
            canvas.DrawText(visual, FromWidth(x, paint.MeasureText(visual), align), y, paint);
            return;
        }

        if (shaper == null)
        {
            canvas.DrawText(text, FromWidth(x, paint.MeasureText(text), align), y, paint);
            return;
        }

        var shaped = shaper.Shape(text, paint);
        if (shaped.Codepoints.Length == 0)
        {
            canvas.DrawText(text, FromWidth(x, paint.MeasureText(text), align), y, paint);
            return;
        }

        var glyphs = new ushort[shaped.Codepoints.Length];
        for (var i = 0; i < glyphs.Length; i++)
            glyphs[i] = (ushort)shaped.Codepoints[i];

        using var builder = new SKTextBlobBuilder();
        builder.AddPositionedRun(paint, glyphs, shaped.Points);
        using var blob = builder.Build();
        canvas.DrawText(blob, FromWidth(x, blob.Bounds.Width, align), y, paint);
    }
}

public class LogoRenderException : Exception
{
    public LogoRenderException(string message) : base(message) { }
    public LogoRenderException(string message, Exception inner) : base(message, inner) { }
}