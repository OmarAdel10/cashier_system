using System.Globalization;
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

        using var boldTypeface = SKTypeface.FromFamilyName("Consolas",
            SKFontStyleWeight.SemiBold, SKFontStyleWidth.Normal, SKFontStyleSlant.Upright);
        using var normalTypeface = SKTypeface.FromFamilyName("Consolas");

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
        var headerText = $"Welcome to {request.StoreName}";
        canvas.DrawText(headerText, Width / 2f, y + headerPaint.TextSize, headerPaint);
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
            canvas.DrawText($"ORD: {request.OrderNumber}", Margin, y + metaPaint.TextSize, metaPaint);
            y += metaLineHeight;
        }

        // Address
        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
        {
            canvas.DrawText($"Address: {request.StoreAddress}", Margin, y + metaPaint.TextSize, metaPaint);
            y += metaLineHeight;
        }

        // Tel
        if (!string.IsNullOrWhiteSpace(request.StorePhone))
        {
            canvas.DrawText($"Tel: {request.StorePhone}", Margin, y + metaPaint.TextSize, metaPaint);
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
                ? $"Shift: {request.UserName}"
                : $"Shift: {request.UserName} {timeStr}";
            canvas.DrawText(shiftText, Margin, y + metaPaint.TextSize, metaPaint);
            y += metaLineHeight;
        }

        // Date
        var dateText = $"Date: {request.CreatedAt:yyyy-MM-dd HH:mm}";
        canvas.DrawText(dateText, Margin, y + metaPaint.TextSize, metaPaint);
        y += metaLineHeight;

        // Payment Type
        if (!string.IsNullOrWhiteSpace(request.PaymentType))
        {
            var paymentText = $"Payment Type: {request.PaymentType}";
            canvas.DrawText(paymentText, Margin, y + metaPaint.TextSize, metaPaint);
            y += metaLineHeight;
        }

        // Dashed divider
        DrawDashedLine(canvas, y, dashPaint);
        y += 14;

        // ---- Table headers ----
        var col1X = Margin;
        var col2X = Width / 2f;
        var col3X = Width - Margin;

        // Left-aligned header
        using var leftBold = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 11,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Left,
        };
        // Right-aligned header for col3
        using var rightBold = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 11,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Right,
        };

        canvas.DrawText("Item Description", col1X, y + 11, leftBold);

        // Center "Price" between col2X
        using var centerBold = new SKPaint
        {
            Typeface = boldTypeface,
            TextSize = 11,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Center,
        };
        canvas.DrawText("Price", col2X, y + 11, centerBold);
        canvas.DrawText("Total", col3X, y + 11, rightBold);
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
            TextAlign = SKTextAlign.Right,
        };
        using var itemCenterPaint = new SKPaint
        {
            Typeface = normalTypeface,
            TextSize = 12,
            Color = SKColors.Black,
            IsAntialias = true,
            TextAlign = SKTextAlign.Center,
        };

        foreach (var item in request.Items)
        {
            var desc = $"{item.Name} x{item.Quantity}";
            var unitPrice = $"{(item.UnitPricePiastres / 100.0):F2}";
            var totalPrice = $"{(item.TotalPiastres / 100.0):F2}";

            canvas.DrawText(desc, col1X, y + 12, itemLeftPaint);
            canvas.DrawText(unitPrice, col2X, y + 12, itemCenterPaint);
            canvas.DrawText(totalPrice, col3X, y + 12, itemRightPaint);
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
            TextAlign = SKTextAlign.Right,
        };

        if (showSubtotal)
        {
            canvas.DrawText("Subtotal", col1X, y + 12, financeLeftPaint);
            canvas.DrawText($"{(request.SubtotalPiastres / 100.0):F2}", col3X, y + 12, financeRightPaint);
            y += 24;
        }

        if (hasTax)
        {
            canvas.DrawText($"Tax ({request.TaxPercent}%)", col1X, y + 12, financeLeftPaint);
            canvas.DrawText($"+{(request.TaxPiastres / 100.0):F2}", col3X, y + 12, financeRightPaint);
            y += 24;
        }

        if (hasDiscount)
        {
            canvas.DrawText($"Discount ({request.DiscountPercent}%)", col1X, y + 12, financeLeftPaint);
            canvas.DrawText($"-{(request.DiscountPiastres / 100.0):F2}", col3X, y + 12, financeRightPaint);
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
            TextAlign = SKTextAlign.Right,
        };
        canvas.DrawText("Total", col1X, y + 14, totalLeftPaint);
        canvas.DrawText($"{(request.TotalPiastres / 100.0):F2}", col3X, y + 14, totalRightPaint);
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
            canvas.DrawText(request.ReceiptFootnote, Width / 2f, y + 11, footnotePaint);
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
            canvas.DrawText($"Receipt UUID: {request.ReceiptUuid}", Margin, y + 10, uuidPaint);
        }
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
