using System.Collections.Concurrent;
using System.Globalization;
using PrintServer.Linux.Localization;
using PrintServer.Linux.Models;
using SkiaSharp;
using SkiaSharp.HarfBuzz;
using Svg.Skia;

namespace PrintServer.Linux.Services;

public sealed class ImageExportService : IDisposable
{
    private const float Width = 384;
    private const float Margin = 20;
    private readonly SvgValidator _svgValidator;
    private readonly ConcurrentDictionary<(string family, bool bold, SKFontStyleWidth width, SKFontStyleSlant slant, SKFontStyleWeight weight), SKTypeface> _fontCache = new();
    private bool _disposed;

    public ImageExportService()
        : this(new SvgValidator())
    {
    }

    public ImageExportService(SvgValidator svgValidator)
    {
        _svgValidator = svgValidator;
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

    public async Task<string?> SaveReceiptAsPngAsync(ReceiptRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.OutputDirectory) || !request.SaveAsPng)
            return null;

        var dir = request.OutputDirectory;
        if (!Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        var filename = $"receipt_{DateTime.Now:yyyyMMdd_HHmmss}.png";
        var fullPath = Path.GetFullPath(Path.Combine(dir, filename));

        // Exclusive create: a pre-planted symlink or colliding file at the
        // predictable timestamped name fails the save instead of being
        // truncated through.
        using (new FileStream(fullPath, FileMode.CreateNew, FileAccess.Write,
                   FileShare.None, 0, FileOptions.WriteThrough))
        {
        }

        return await Task.Run(() =>
        {
            var height = CalculateHeight(request);

            using var surface = SKSurface.Create(new SKImageInfo((int)Width, (int)height));
            var canvas = surface.Canvas;
            canvas.Clear(SKColors.White);

            DrawReceipt(canvas, request);

            using var image = surface.Snapshot();
            using var data = image.Encode(SKEncodedImageFormat.Png, 100);
            using var stream = File.Create(fullPath);
            data.SaveTo(stream);

            return fullPath;
        });
    }

    private float CalculateHeight(ReceiptRequest request)
    {
        const float maxBitmapHeightPx = 60000f;
        float h = 0;

        // Logo: reserve the MEASURED rendered height + the 8px gap that
        // DrawLogo advances — not a fixed 48px (blank gap / clipping for
        // any other aspect ratio). A broken logo reserves 0 here; DrawLogo
        // throws and surfaces the error at draw time.
        if (!string.IsNullOrWhiteSpace(request.LogoSvgData))
            h += MeasureLogoHeight(request.LogoSvgData) + 8;

        // Header: "Welcome to {StoreName}"
        h += 32;

        // Dashed divider
        h += 16;

        // ORD line
        if (!string.IsNullOrWhiteSpace(request.OrderNumber))
            h += 24;

        // Address line
        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            h += 24;

        // Phone line
        if (!string.IsNullOrWhiteSpace(request.StorePhone))
            h += 24;

        // Shift line
        if (!string.IsNullOrWhiteSpace(request.UserName))
            h += 24;

        // Date line
        h += 24;

        // Payment Type line
        if (!string.IsNullOrWhiteSpace(request.PaymentType))
            h += 24;

        // Dashed divider
        h += 16;

        // Table headers
        h += 24;

        // Dashed divider
        h += 16;

        // Items (with dividers)
        h += request.Items.Count * 40f;

        // Calculations
        var hasSubtotal = request.TaxPiastres > 0 || request.DiscountPiastres > 0;
        var hasTax = request.TaxPiastres > 0;
        var hasDiscount = request.DiscountPiastres > 0;
        if (hasSubtotal) h += 24;
        if (hasTax) h += 24;
        if (hasDiscount) h += 24;

        // Total
        h += 32;

        // Dashed divider
        h += 16;

        // Footnote
        if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
            h += 30;

        // UUID
        h += 24;

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
        // Consolas originally used SemiBold weight.
        var arTypeface = isRtl ? LoadArabicTypeface() : null;
        var enBoldTypeface = GetTypeface("Consolas", true, weight: SKFontStyleWeight.SemiBold);
        var enNormalTypeface = GetTypeface("Consolas", false);
        using var shaper = isRtl && arTypeface != null ? new SKShaper(arTypeface) : null;

        SKTypeface boldTypeface = isRtl && arTypeface != null ? arTypeface : enBoldTypeface;
        SKTypeface normalTypeface = isRtl && arTypeface != null ? arTypeface : enNormalTypeface;

        // Layout mirroring: RTL puts labels on the right side and amounts on
        // the left, mirroring the English column layout.
        var labelX = isRtl ? Width - Margin : Margin;

        float y = Margin;

        // ---- Logo ----
        if (!string.IsNullOrWhiteSpace(request.LogoSvgData))
        {
            DrawLogo(canvas, request.LogoSvgData, ref y);
        }

        // ---- Header: "Welcome to {StoreName}" ----
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

        // Dashed divider
        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Metadata section ----
        using var metaPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 11,
            Color = SKColors.DimGray,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        var metaLineHeight = 22f;

        // ORD
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

        // Address
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

        // Tel
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

        // Shift
        if (!string.IsNullOrWhiteSpace(request.UserName))
        {
            var shiftTime = ParseDateTime(request.ShiftStartedAt);
            var timeStr = shiftTime.HasValue
                ? shiftTime.Value.ToString("h:mm tt", CultureInfo.InvariantCulture)
                : "";
            var shiftLabel = ReceiptLabels.Label(ReceiptLabels.Shift, isRtl);
            TextDraw.DrawText(canvas, shaper, isRtl, shiftLabel, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var shiftLabelW = TextDraw.MeasureVisual(shiftLabel, metaPaint, isRtl);
            // Name/time split: the Arabic name must not reshape "9:54 PM" (it
            // would reorder to "PM 9:54"); the time alone is pure-Latin.
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

        // Date
        var dateLabel = ReceiptLabels.Label(ReceiptLabels.Date, isRtl);
        var dateValue = request.CreatedAt.ToString("yyyy-MM-dd h:mm tt", CultureInfo.InvariantCulture);
        TextDraw.DrawText(canvas, shaper, isRtl, dateLabel, metaPaint, labelX, y + metaPaint.TextSize,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        var dateLabelW = TextDraw.MeasureVisual(dateLabel, metaPaint, isRtl);
        TextDraw.DrawText(canvas, shaper, isRtl, dateValue, metaPaint,
            isRtl ? labelX - dateLabelW - 4f : labelX + dateLabelW + 4f, y + metaPaint.TextSize,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        y += metaLineHeight;

        // Payment Type
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

        // Dashed divider
        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Table headers ----
        var col1X = Margin;
        var col2X = Width / 2f;
        var col3X = Width - Margin;

        // RTL path always shapes with left-aligned paint; the DrawText helper
        // applies the column alignment from the blob width.
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

        // Dashed divider
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

            // Dashed divider after each item
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
            // "(N%)" is digits/punct only: drawn beside the label so it is
            // never reshaped with Arabic (parens/percent would flip to ")%N(").
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
            // Same treatment as the tax row above: keep "(N%)" out of the
            // Arabic label's reshape.
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

        // Dashed divider
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

    /// <summary>
    /// Loads the bundled Noto Naskh Arabic font (SIL OFL, ships under
    /// Assets/ so the installer copies it with the server). Falls back to
    /// Segoe UI / default so the PNG path never crashes when the asset is
    /// missing.
    /// </summary>
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

    /// <summary>
    /// Measures the height the logo will occupy after being scaled to the
    /// receipt's max logo size. Returns 0 when the logo is absent or broken —
    /// broken logos surface via <see cref="LogoRenderException"/> at draw time
    /// so the caller gets an error instead of a silently blank receipt.
    /// </summary>
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

        if (DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt))
            return dt;

        return null;
    }
}