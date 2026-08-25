using System.Drawing;
using System.Drawing.Printing;
using System.Xml;
using System.Xml.Linq;
using BarcodeLib;
using PrintServer.Localization;
using PrintServer.Models;
using SkiaSharp;
using Svg.Skia;

namespace PrintServer.Services;

public sealed class PrinterService
{
    private readonly SvgValidator _svgValidator = new();

    public List<string> GetInstalledPrinters()
    {
        var printers = new List<string>();
        foreach (string printer in PrinterSettings.InstalledPrinters)
        {
            printers.Add(printer);
        }
        return printers;
    }

    public bool PrintReceipt(ReceiptRequest request)
    {
        // Device print path; PrintReceiptCore returns "" on success, null on
        // failure (LogoRenderException propagates).
        return PrintReceiptCore(request, printFileName: null) is not null;
    }

    /// <summary>
    /// Prints the receipt silently to a file (e.g. 'Microsoft Print As PDF'
    /// via GDI+ PrintToFile), bypassing the printer dialog. Returns the
    /// written file path on success, null on failure.
    /// </summary>
    public string? PrintReceiptToFile(ReceiptRequest request)
    {
        if (!request.PrintToFile || string.IsNullOrWhiteSpace(request.PrintFileName))
            return null;

        var dir = Path.GetDirectoryName(request.PrintFileName);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        return PrintReceiptCore(request, printFileName: request.PrintFileName);
    }

    private string? PrintReceiptCore(ReceiptRequest request, string? printFileName)
    {
        try
        {
            var printerName = ResolvePrinterName(request.PrinterName);
            if (printerName == null) return null;

            using var printDoc = new PrintDocument
            {
                PrinterSettings = new PrinterSettings { PrinterName = printerName },
                DocumentName = $"Receipt_{DateTime.Now:yyyyMMddHHmmss}",
            };

            if (printFileName != null)
            {
                printDoc.PrinterSettings.PrintToFile = true;
                printDoc.PrinterSettings.PrintFileName = printFileName;
            }

            printDoc.PrintPage += (sender, e) =>
            {
                const float margin = 10f;
                var pageWidth = e.PageBounds.Width;
                var usableWidth = pageWidth - 2 * margin;
                var col1X = margin;
                var col2X = pageWidth / 2f;
                var col3X = pageWidth - margin;

                var isRtl = request.IsRtl;

                // Arabic receipts: Arial (full Arabic glyphs on Windows) with
                // GDI+ shaping; layout mirrors columns so labels sit on the
                // right and amounts on the left.
                var fontFamily = isRtl ? "Arial" : "Consolas";

                var y = margin;

                using var bold12 = new Font(fontFamily, 12, FontStyle.Bold);
                using var bold11 = new Font(fontFamily, 11, FontStyle.Bold);
                using var normal10 = new Font(fontFamily, 10);
                using var small9 = new Font(fontFamily, 9);
                using var grayBrush = new SolidBrush(Color.DimGray);
                using var darkGray = new SolidBrush(Color.FromArgb(80, 80, 80));
                using var dashPen = new Pen(Color.Gray, 1) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dash };

                var g = e.Graphics!;

                // ---- Logo ----
                using (var logo = RenderLogoToImage(request.LogoSvgData, pageWidth))
                {
                    if (logo != null)
                    {
                        var logoX = (pageWidth - logo.Width) / 2f;
                        g.DrawImage(logo, logoX, y, logo.Width, logo.Height);
                        y += logo.Height + 8;
                    }
                }

                // ---- Header: "Welcome to {StoreName}" (centered) ----
                using var centerFmt = new StringFormat { Alignment = StringAlignment.Center };
                var headerText = ReceiptLabels.Format(ReceiptLabels.Welcome, isRtl, request.StoreName);
                g.DrawString(headerText, bold12, Brushes.Black, pageWidth / 2f, y, centerFmt);
                y += 26;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // RTL text anchors right edge; LTR anchors left edge.
                var labelX = isRtl ? col3X : col1X;
                using var labelFmt = isRtl
                    ? new StringFormat { Alignment = StringAlignment.Far }
                    : new StringFormat { Alignment = StringAlignment.Near };

                // ---- Metadata ----
                if (!string.IsNullOrWhiteSpace(request.OrderNumber))
                {
                    var ordText = ReceiptLabels.Format(ReceiptLabels.OrderNumber, isRtl, request.OrderNumber);
                    g.DrawString(ordText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.StoreAddress))
                {
                    var addressText = ReceiptLabels.Format(ReceiptLabels.Address, isRtl, request.StoreAddress);
                    g.DrawString(addressText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.StorePhone))
                {
                    var phoneText = ReceiptLabels.Format(ReceiptLabels.Phone, isRtl, request.StorePhone);
                    g.DrawString(phoneText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.UserName))
                {
                    var timeStr = ParseShiftTime(request.ShiftStartedAt);
                    var shiftText = string.IsNullOrWhiteSpace(timeStr)
                        ? ReceiptLabels.Format(ReceiptLabels.Shift, isRtl, request.UserName)
                        : ReceiptLabels.Format(ReceiptLabels.Shift, isRtl, $"{request.UserName} {timeStr}");
                    g.DrawString(shiftText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                var dateText = ReceiptLabels.Format(ReceiptLabels.Date, isRtl,
                    request.CreatedAt.ToString("yyyy-MM-dd HH:mm"));
                g.DrawString(dateText, normal10, grayBrush, labelX, y, labelFmt);
                y += 20;

                if (!string.IsNullOrWhiteSpace(request.PaymentType))
                {
                    var paymentText = ReceiptLabels.Format(ReceiptLabels.PaymentTypeLabel, isRtl,
                        ReceiptLabels.PaymentType(request.PaymentType, isRtl));
                    g.DrawString(paymentText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Table headers (mirrored for RTL) ----
                using var rightFmt = new StringFormat { Alignment = StringAlignment.Far };
                using var centerFmt2 = new StringFormat { Alignment = StringAlignment.Center };
                using var leftFmt = new StringFormat { Alignment = StringAlignment.Near };
                var itemDescHeader = ReceiptLabels.Get(ReceiptLabels.ItemDescription, isRtl);
                var priceHeader = ReceiptLabels.Get(ReceiptLabels.Price, isRtl);
                var totalHeader = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);
                g.DrawString(itemDescHeader, bold11, Brushes.Black, isRtl ? col3X : col1X, y,
                    isRtl ? rightFmt : leftFmt);
                g.DrawString(priceHeader, bold11, Brushes.Black, col2X, y, centerFmt2);
                g.DrawString(totalHeader, bold11, Brushes.Black, isRtl ? col1X : col3X, y,
                    isRtl ? leftFmt : rightFmt);
                y += 20;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Items (mirrored for RTL) ----
                foreach (var item in request.Items)
                {
                    var desc = $"{item.Name} x{item.Quantity}";
                    var unitPrice = $"{(item.UnitPricePiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}";
                    var totalPrice = $"{(item.TotalPiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}";

                    g.DrawString(desc, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString(unitPrice, normal10, Brushes.Black, col2X, y, centerFmt2);
                    g.DrawString(totalPrice, normal10, Brushes.Black, isRtl ? col1X : col3X, y,
                        isRtl ? leftFmt : rightFmt);
                    y += 22;

                    g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                    y += 12;
                }

                // ---- Calculations (mirrored for RTL) ----
                var hasTax = request.TaxPiastres > 0;
                var hasDiscount = request.DiscountPiastres > 0;
                var showSubtotal = hasTax || hasDiscount;

                if (showSubtotal)
                {
                    var subtotalLabel = ReceiptLabels.Get(ReceiptLabels.Subtotal, isRtl);
                    g.DrawString(subtotalLabel, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString($"{(request.SubtotalPiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}", normal10, Brushes.Black,
                        isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                    y += 22;
                }
                if (hasTax)
                {
                    var taxLabel = ReceiptLabels.Format(ReceiptLabels.Tax, isRtl, request.TaxPercent);
                    g.DrawString(taxLabel, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString($"{(request.TaxPiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}", normal10, Brushes.Black,
                        isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                    y += 22;
                }
                if (hasDiscount)
                {
                    var discountLabel = ReceiptLabels.Format(ReceiptLabels.Discount, isRtl, request.DiscountPercent);
                    g.DrawString(discountLabel, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString($"-{(request.DiscountPiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}", normal10, Brushes.Black,
                        isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                    y += 22;
                }

                // ---- Total ----
                var totalLabel = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);
                g.DrawString(totalLabel, bold12, Brushes.Black, isRtl ? col3X : col1X, y,
                    isRtl ? rightFmt : leftFmt);
                g.DrawString($"{(request.TotalPiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}", bold12, Brushes.Black,
                    isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                y += 28;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Footer ----
                if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
                {
                    g.DrawString(request.ReceiptFootnote, small9, grayBrush, pageWidth / 2f, y, centerFmt);
                    y += 22;
                }

                // UUID
                if (!string.IsNullOrWhiteSpace(request.ReceiptUuid))
                {
                    var uuidText = ReceiptLabels.Format(ReceiptLabels.ReceiptUuid, isRtl, request.ReceiptUuid);
                    g.DrawString(uuidText, small9, darkGray, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                }
            };

            printDoc.Print();
            return printFileName ?? string.Empty;
        }
        catch (LogoRenderException)
        {
            // A provided-but-broken logo must reach the API layer as an error
            // (non-200 + body) instead of being swallowed into printed=false.
            throw;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintReceipt failed: {ex}");
            return null;
        }
    }

    /// <summary>
    /// Rasterizes the base64 SVG logo into a GDI+ bitmap for the print
    /// path. Scales to pageWidth/8 on the longest side — the same 1/8
    /// ratio the PNG export uses — so the printed logo matches the saved
    /// image. Returns null when NO logo was provided; throws
    /// <see cref="LogoRenderException"/> when a provided logo cannot be
    /// validated or rendered, so failures surface to the caller instead
    /// of silently vanishing from printed receipts.
    /// </summary>
    internal Image? RenderLogoToImage(string? logoSvgData, float pageWidth)
    {
        if (string.IsNullOrWhiteSpace(logoSvgData))
            return null;

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

        // Svg.Skia 2.x assigns dimensionless SVGs a positive CullRect
        // (child-bounds fallback), so the render-time guard below can no
        // longer catch them. Enforce the intrinsic-size contract from the
        // SVG root itself, before any platform-dependent rendering.
        if (!SvgHasIntrinsicSize(svgBytes))
            throw new LogoRenderException(
                "logo SVG has no intrinsic size (add width/height or viewBox)");

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

            var logoMaxSize = pageWidth / 8f;
            var scale = logoMaxSize / Math.Max(cullRect.Width, cullRect.Height);
            var logoW = cullRect.Width * scale;
            var logoH = cullRect.Height * scale;

            using var bitmap = new SKBitmap(new SKImageInfo(
                Math.Max(1, (int)Math.Ceiling(logoW)),
                Math.Max(1, (int)Math.Ceiling(logoH))));
            using (var canvas = new SKCanvas(bitmap))
            {
                canvas.Clear(SKColors.White);
                canvas.DrawPicture(svg.Picture, 0, 0,
                    new SKPaint { FilterQuality = SKFilterQuality.Low });
            }

            using var image = SKImage.FromBitmap(bitmap);
            using var data = image.Encode(SKEncodedImageFormat.Png, 100);
            using var stream = new MemoryStream(data.ToArray());
            using var loaded = new Bitmap(stream);
            // Deep-copy: the MemoryStream must not outlive the image (GDI+
            // may read lazily); the clone is fully self-contained.
            return new Bitmap(loaded);
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

    /// <summary>
    /// True when the SVG root declares an intrinsic size: explicit
    /// width+height, or a viewBox from which one can be derived.
    /// </summary>
    private static bool SvgHasIntrinsicSize(byte[] svgBytes)
    {
        try
        {
            using var stream = new MemoryStream(svgBytes);
            var root = XDocument.Load(stream).Root;
            if (root == null || root.Name.LocalName != "svg")
                return false;
            var hasSize = root.Attribute("width") != null &&
                          root.Attribute("height") != null;
            return hasSize || root.Attribute("viewBox") != null;
        }
        catch (XmlException ex)
        {
            throw new LogoRenderException("logo SVG is not valid XML", ex);
        }
    }

    public bool PrintTicket(TicketRequest request)
    {
        try
        {
            var printerName = ResolvePrinterName(request.PrinterName);
            if (printerName == null) return false;

            using var printDoc = new PrintDocument
            {
                PrinterSettings = new PrinterSettings { PrinterName = printerName },
                DocumentName = $"Ticket_{request.OrderNumber}",
            };

            printDoc.PrintPage += (sender, e) =>
            {
                const float margin = 10f;
                var pageWidth = e.PageBounds.Width;
                var usableWidth = pageWidth - 2 * margin;
                var centerX = pageWidth / 2f;
                var isRtl = request.IsRtl;
                var fontFamily = isRtl ? "Arial" : "Consolas";

                var y = margin;

                using var bold16 = new Font(fontFamily, 16, FontStyle.Bold);
                using var bold12 = new Font(fontFamily, 12, FontStyle.Bold);
                using var bold10 = new Font(fontFamily, 10, FontStyle.Bold);
                using var normal10 = new Font(fontFamily, 10);
                using var grayBrush = new SolidBrush(Color.DimGray);
                using var dashedPen = new Pen(Color.Gray, 1) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dash };
                using var centerFmt = new StringFormat { Alignment = StringAlignment.Center };
                using var rightFmt = new StringFormat { Alignment = StringAlignment.Far };

                var g = e.Graphics!;

                // ---- Venue header ----
                if (!string.IsNullOrWhiteSpace(request.StoreName))
                {
                    g.DrawString(request.StoreName, bold16, Brushes.Black, centerX, y, centerFmt);
                    y += 30;
                }

                // ---- Station / category label ----
                if (!string.IsNullOrWhiteSpace(request.Category))
                {
                    g.DrawString(request.Category.ToUpperInvariant(), bold12, Brushes.Black, centerX, y, centerFmt);
                    y += 26;
                }

                // Dashed divider
                g.DrawLine(dashedPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Table + zone + round ----
                var location = string.IsNullOrWhiteSpace(request.ZoneName)
                    ? request.TableName
                    : $"{request.TableName} / {request.ZoneName}";
                g.DrawString(location, bold12, Brushes.Black, margin, y);
                y += 22;
                if (request.RoundNumber > 0)
                {
                    var roundLabel = ReceiptLabels.Format(ReceiptLabels.Round, isRtl, request.RoundNumber);
                    DrawTicketMeta(g, roundLabel, normal10, grayBrush, margin, pageWidth, y, isRtl, rightFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.OrderNumber))
                {
                    var orderLabel = ReceiptLabels.Format(ReceiptLabels.Order, isRtl, request.OrderNumber);
                    DrawTicketMeta(g, orderLabel, normal10, grayBrush, margin, pageWidth, y, isRtl, rightFmt);
                    y += 20;
                }
                var firedLabel = ReceiptLabels.Format(ReceiptLabels.Fired, isRtl, request.CreatedAt.ToString("HH:mm"));
                DrawTicketMeta(g, firedLabel, normal10, grayBrush, margin, pageWidth, y, isRtl, rightFmt);
                y += 20;

                // Dashed divider
                g.DrawLine(dashedPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Items: qty x name (no prices) ----
                foreach (var item in request.Items)
                {
                    g.DrawString($"{item.Quantity} x {item.Name}", bold10, Brushes.Black, margin, y);
                    y += 22;
                }
            };

            printDoc.Print();
            return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintTicket failed: {ex}");
            return false;
        }
    }

    /// <summary>
    /// Draws a single ticket meta line (Round / Order / Fired). Mirrored:
    /// RTL renders right-aligned at the page's right edge so the Arabic
    /// text flows from the far side like the receipt layout.
    /// </summary>
    private static void DrawTicketMeta(Graphics g, string text, Font font, Brush brush,
        float margin, float pageWidth, float y, bool isRtl, StringFormat rightFmt)
    {
        if (isRtl)
            g.DrawString(text, font, brush, pageWidth - margin, y, rightFmt);
        else
            g.DrawString(text, font, brush, margin, y);
    }

    private static string ParseShiftTime(string? isoValue)    {
        if (string.IsNullOrWhiteSpace(isoValue))
            return "";
        if (DateTime.TryParse(isoValue, System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out var dt))
            return dt.ToString("h:mm tt", System.Globalization.CultureInfo.InvariantCulture);
        return "";
    }

    public async Task<bool> PrintBarcodeAsync(BarcodeRequest request)
    {
        return await Task.Run(() =>
        {
            try
            {
                var printerName = ResolvePrinterName(request.PrinterName);
                if (printerName == null) return false;

                using var barcodeBitmap = GenerateBarcodeImage(request.BarcodeData);

                var printDoc = new PrintDocument
                {
                    PrinterSettings = new PrinterSettings { PrinterName = printerName },
                    DocumentName = $"Barcode_{request.BarcodeData}",
                };

                printDoc.PrintPage += (sender, e) =>
                {
                    var y = 8f;
                    var leftMargin = 8f;

                    var barcodeWidth = Math.Min(barcodeBitmap.Width, e.PageBounds.Width - 16);
                    var barcodeHeight = (int)((float)barcodeBitmap.Height * barcodeWidth / barcodeBitmap.Width);
                    e.Graphics!.DrawImage(barcodeBitmap, leftMargin, y, barcodeWidth, barcodeHeight);
                    y += barcodeHeight + 4;

                    using var smallFont = new Font(request.IsRtl ? "Arial" : "Consolas", 8);
                    e.Graphics!.DrawString(request.BarcodeData, smallFont, Brushes.Gray, leftMargin, y);
                    y += 12;

                    if (!string.IsNullOrWhiteSpace(request.ProductName))
                    {
                        e.Graphics!.DrawString(request.ProductName, smallFont, Brushes.Black, leftMargin, y);
                        y += 12;
                    }
                    if (request.PricePiastres > 0)
                    {
                        var priceText = (request.PricePiastres / 100.0).ToString("F2", System.Globalization.CultureInfo.InvariantCulture);
                        e.Graphics!.DrawString(ReceiptLabels.Format(ReceiptLabels.PriceWithValue, request.IsRtl, priceText),
                            smallFont, Brushes.Black, leftMargin, y);
                    }
                };

                printDoc.Print();
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintBarcode failed: {ex.Message}");
                return false;
            }
        });
    }

    private static Image GenerateBarcodeImage(string barcodeData)
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

    private static string? ResolvePrinterName(string? preferred)
    {
        if (!string.IsNullOrWhiteSpace(preferred))
        {
            foreach (string printer in PrinterSettings.InstalledPrinters)
            {
                if (printer.Equals(preferred, StringComparison.OrdinalIgnoreCase))
                    return printer;
            }
        }

        if (PrinterSettings.InstalledPrinters.Count == 0)
            return null;

        // Prefer the OS default printer (e.g. 'Microsoft Print As PDF') over
        // the first arbitrary installed printer. Falling back to the first
        // installed device silently printed receipts to a random printer.
        var defaultPrinter = GetDefaultPrinterName();
        if (!string.IsNullOrWhiteSpace(defaultPrinter))
        {
            foreach (string printer in PrinterSettings.InstalledPrinters)
            {
                if (printer.Equals(defaultPrinter, StringComparison.OrdinalIgnoreCase))
                    return printer;
            }
        }

        return PrinterSettings.InstalledPrinters
            .Cast<string>()
            .FirstOrDefault();
    }

    /// <summary>
    /// Returns the Windows default printer via winspool GetDefaultPrinterW.
    /// Returns null on non-Windows platforms or when no default is set.
    /// (PrinterSettings.DefaultPrinter is a Windows-only API that does not
    /// exist in the non-Windows System.Drawing.Common surface.)
    /// </summary>
    [System.Runtime.InteropServices.DllImport("winspool.drv", EntryPoint = "GetDefaultPrinterW",
        SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern bool GetDefaultPrinterNative(System.Text.StringBuilder? buffer, ref int bufferSize);

    private static string? GetDefaultPrinterName()
    {
        if (!System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(
                System.Runtime.InteropServices.OSPlatform.Windows))
            return null;

        var size = 0;
        GetDefaultPrinterNative(null, ref size);
        if (size <= 0)
            return null;

        var sb = new System.Text.StringBuilder(size);
        return GetDefaultPrinterNative(sb, ref size) ? sb.ToString().Trim() : null;
    }
}
