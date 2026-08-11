using System.Globalization;
using PrintServer.Localization;
using PrintServer.Models;
using SkiaSharp;
using SkiaSharp.HarfBuzz;
using Svg.Skia;

namespace PrintServer.Services;

public sealed class ImageExportService
{
    private const float Width = 384;
    private const float Margin = 20;
    private readonly SvgValidator _svgValidator;

    public ImageExportService()
        : this(new SvgValidator())
    {
    }

    public ImageExportService(SvgValidator svgValidator)
    {
        _svgValidator = svgValidator;
    }

    public async Task<string?> SaveReceiptAsPngAsync(ReceiptRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.OutputDirectory) || !request.SaveAsPng)
            return null;

        var dir = request.OutputDirectory;
        if (!Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        var filename = $"receipt_{DateTime.Now:yyyyMMdd_HHmmss}.png";
        var fullPath = Path.Combine(dir, filename);

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

    private static float CalculateHeight(ReceiptRequest request)
    {
        float h = 0;

        // Logo
        if (!string.IsNullOrWhiteSpace(request.LogoSvgData))
            h += 48;

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

        return h + Margin;
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

        // Arabic text needs a font with Arabic glyphs (Consolas is Latin-only)
        // plus HarfBuzz shaping for correct letter joining. Fonts are disposed
        // in reverse declaration order, so the shaper (declared last) dies
        // before the typeface it references.
        using var enBoldTypeface = SKTypeface.FromFamilyName("Consolas",
            SKFontStyleWeight.SemiBold, SKFontStyleWidth.Normal, SKFontStyleSlant.Upright);
        using var enNormalTypeface = SKTypeface.FromFamilyName("Consolas");
        using var arTypeface = isRtl ? LoadArabicTypeface() : null!;
        using var shaper = isRtl ? new SKShaper(arTypeface) : null;

        SKTypeface boldTypeface = isRtl ? arTypeface : enBoldTypeface;
        SKTypeface normalTypeface = isRtl ? arTypeface : enNormalTypeface;

        // Layout mirroring: RTL puts labels on the right side and amounts on
        // the left, mirroring the English column layout.
        var labelX = isRtl ? Width - Margin : Margin;
        var valueX = isRtl ? Margin : Width - Margin;

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
        DrawText(canvas, shaper, isRtl, headerText, headerPaint, Width / 2f, y + headerPaint.TextSize,
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
            var ordText = ReceiptLabels.Format(ReceiptLabels.OrderNumber, isRtl, request.OrderNumber);
            DrawText(canvas, shaper, isRtl, ordText, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        // Address
        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
        {
            var addressText = ReceiptLabels.Format(ReceiptLabels.Address, isRtl, request.StoreAddress);
            DrawText(canvas, shaper, isRtl, addressText, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        // Tel
        if (!string.IsNullOrWhiteSpace(request.StorePhone))
        {
            var phoneText = ReceiptLabels.Format(ReceiptLabels.Phone, isRtl, request.StorePhone);
            DrawText(canvas, shaper, isRtl, phoneText, metaPaint, labelX, y + metaPaint.TextSize,
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
            var shiftText = string.IsNullOrWhiteSpace(timeStr)
                ? ReceiptLabels.Format(ReceiptLabels.Shift, isRtl, request.UserName)
                : ReceiptLabels.Format(ReceiptLabels.Shift, isRtl, $"{request.UserName} {timeStr}");
            DrawText(canvas, shaper, isRtl, shiftText, metaPaint, labelX, y + metaPaint.TextSize,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += metaLineHeight;
        }

        // Date
        var dateText = ReceiptLabels.Format(ReceiptLabels.Date, isRtl,
            request.CreatedAt.ToString("yyyy-MM-dd HH:mm"));
        DrawText(canvas, shaper, isRtl, dateText, metaPaint, labelX, y + metaPaint.TextSize,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        y += metaLineHeight;

        // Payment Type
        if (!string.IsNullOrWhiteSpace(request.PaymentType))
        {
            var paymentText = ReceiptLabels.Format(ReceiptLabels.PaymentTypeLabel, isRtl,
                ReceiptLabels.PaymentType(request.PaymentType, isRtl));
            DrawText(canvas, shaper, isRtl, paymentText, metaPaint, labelX, y + metaPaint.TextSize,
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
            DrawText(canvas, shaper, isRtl, itemDescHeader, leftBold, col3X, y + 11, RtlAlign.Right);
        }
        else
        {
            DrawText(canvas, shaper, isRtl, itemDescHeader, leftBold, col1X, y + 11, RtlAlign.Left);
        }

        DrawText(canvas, shaper, isRtl, priceHeader, leftBold, col2X, y + 11, RtlAlign.Center);
        DrawText(canvas, shaper, isRtl, totalHeader, rightBold, isRtl ? col1X : col3X, y + 11,
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
            var unitPrice = $"{(item.UnitPricePiastres / 100.0):F2}";
            var totalPrice = $"{(item.TotalPiastres / 100.0):F2}";

            DrawText(canvas, shaper, isRtl, desc, itemLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            DrawText(canvas, shaper, isRtl, unitPrice, itemCenterPaint, col2X, y + 12, RtlAlign.Center);
            DrawText(canvas, shaper, isRtl, totalPrice, itemRightPaint, isRtl ? col1X : col3X, y + 12,
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
            DrawText(canvas, shaper, isRtl, subtotalLabel, financeLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            DrawText(canvas, shaper, isRtl, $"{(request.SubtotalPiastres / 100.0):F2}",
                financeRightPaint, isRtl ? col1X : col3X, y + 12, isRtl ? RtlAlign.Left : RtlAlign.Right);
            y += 24;
        }

        if (hasTax)
        {
            var taxLabel = ReceiptLabels.Format(ReceiptLabels.Tax, isRtl, request.TaxPercent);
            DrawText(canvas, shaper, isRtl, taxLabel, financeLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            DrawText(canvas, shaper, isRtl, $"+{(request.TaxPiastres / 100.0):F2}",
                financeRightPaint, isRtl ? col1X : col3X, y + 12, isRtl ? RtlAlign.Left : RtlAlign.Right);
            y += 24;
        }

        if (hasDiscount)
        {
            var discountLabel = ReceiptLabels.Format(ReceiptLabels.Discount, isRtl, request.DiscountPercent);
            DrawText(canvas, shaper, isRtl, discountLabel, financeLeftPaint, isRtl ? col3X : col1X, y + 12,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            DrawText(canvas, shaper, isRtl, $"-{(request.DiscountPiastres / 100.0):F2}",
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
        DrawText(canvas, shaper, isRtl, totalLabel, totalLeftPaint, isRtl ? col3X : col1X, y + 14,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        DrawText(canvas, shaper, isRtl, $"{(request.TotalPiastres / 100.0):F2}",
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
            DrawText(canvas, shaper, isRtl, request.ReceiptFootnote, footnotePaint, Width / 2f, y + 11,
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
                TextAlign = isRtl ? SKTextAlign.Left : SKTextAlign.Left,
            };
            var uuidText = ReceiptLabels.Format(ReceiptLabels.ReceiptUuid, isRtl, request.ReceiptUuid);
            DrawText(canvas, shaper, isRtl, uuidText, uuidPaint, isRtl ? col3X : Margin, y + 10,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
        }
    }

    private enum RtlAlign
    {
        Left,
        Right,
        Center,
    }

    /// <summary>
    /// Draws a line. On the RTL path the text is shaped with HarfBuzz (needed
    /// for Arabic letter joining) and column alignment is derived from the
    /// shaped glyph advances; on the LTR path behavior matches plain
    /// SKPaint.DrawText with the paint's own TextAlign.
    /// </summary>
    private static void DrawText(
        SKCanvas canvas,
        SKShaper? shaper,
        bool isRtl,
        string text,
        SKPaint paint,
        float x,
        float y,
        RtlAlign align)
    {
        if (!isRtl || shaper == null)
        {
            canvas.DrawText(text, x, y, paint);
            return;
        }

        var shaped = shaper.Shape(text, paint);
        if (shaped.Codepoints.Length == 0)
        {
            canvas.DrawText(text, x, y, paint);
            return;
        }

        var glyphs = new ushort[shaped.Codepoints.Length];
        for (var i = 0; i < glyphs.Length; i++)
            glyphs[i] = (ushort)shaped.Codepoints[i];

        using var builder = new SKTextBlobBuilder();
        builder.AddPositionedRun(paint, glyphs, shaped.Points);
        using var blob = builder.Build();

        var drawX = align switch
        {
            RtlAlign.Right => x - blob.Bounds.Width,
            RtlAlign.Center => x - blob.Bounds.Width / 2f,
            _ => x,
        };
        canvas.DrawText(blob, drawX, y, paint);
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
        if (string.IsNullOrWhiteSpace(logoSvgData) || !_svgValidator.Validate(logoSvgData).Valid)
            return;

        byte[]? svgBytes = null;
        try
        {
            svgBytes = Convert.FromBase64String(logoSvgData);
        }
        catch
        {
            return;
        }

        if (svgBytes == null || svgBytes.Length > 5 * 1024 * 1024)
            return;

        try
        {
            var svg = new SKSvg();
            using var svgStream = new MemoryStream(svgBytes);
            svg.Load(svgStream);

            if (svg.Picture == null)
                return;

            var cullRect = svg.Picture.CullRect;
            var logoMaxSize = 48f;
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
        catch
        {
            // SVG rendering failed silently
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
