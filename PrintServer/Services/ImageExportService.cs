using SkiaSharp;
using SkiaSharp.HarfBuzz;
using Svg.Skia;
using PrintServer.Models;

namespace PrintServer.Services;

public sealed class ImageExportService
{
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
            var width = 384;
            var margin = 20;

            var showSubtotal = request.TaxPiastres > 0 || request.DiscountPiastres > 0;
            var showTax = request.TaxPiastres > 0;
            var showDiscount = request.DiscountPiastres > 0;
            var financeLines = (showSubtotal ? 1 : 0)
                             + (showTax ? 1 : 0)
                             + (showDiscount ? 1 : 0)
                             + 1;

            var lineHeight = 26;
            var metaLines = 1
                          + (string.IsNullOrWhiteSpace(request.StoreAddress) ? 0 : 1)
                          + (string.IsNullOrWhiteSpace(request.StorePhone) ? 0 : 1);
            var hasMeta = metaLines > 1;
            var itemsHeight = request.Items.Count * lineHeight;
            var height = (metaLines * 24) + (hasMeta ? 10 : 0)
                       + itemsHeight + 10
                       + (financeLines * lineHeight) + 10
                       + (string.IsNullOrWhiteSpace(request.ReceiptFootnote) ? 0 : 20)
                       + 40;

            using var surface = SKSurface.Create(new SKImageInfo(width, height));
            var canvas = surface.Canvas;
            canvas.Clear(SKColors.White);

            using var boldTypeface = SKTypeface.FromFamilyName("Consolas",
                SKFontStyleWeight.SemiBold, SKFontStyleWidth.Normal, SKFontStyleSlant.Upright);
            using var normalTypeface = SKTypeface.FromFamilyName("Consolas");

            float y = margin;

            using var headerPaint = new SKPaint
            {
                Typeface = boldTypeface,
                TextSize = 20,
                Color = SKColors.Black,
                IsAntialias = true,
            };
            using var metaPaint = new SKPaint
            {
                Typeface = normalTypeface,
                TextSize = 11,
                Color = SKColors.DimGray,
                IsAntialias = true,
            };

            byte[]? svgBytes = null;
            if (!string.IsNullOrWhiteSpace(request.LogoSvgData))
            {
                try
                {
                    svgBytes = Convert.FromBase64String(request.LogoSvgData);
                }
                catch
                {
                    System.Diagnostics.Debug.WriteLine("[PrintServer] Invalid base64 LogoSvgData, skipping");
                }
            }

            if (svgBytes != null && svgBytes.Length > 5 * 1024 * 1024) // 5MB limit
            {
                System.Diagnostics.Debug.WriteLine("[PrintServer] Logo SVG exceeds 5MB limit, skipping");
                svgBytes = null;
            }

            if (svgBytes != null)
            {
                try
                {
                    var svg = new SKSvg();
                    using var svgStream = new MemoryStream(svgBytes);
                    svg.Load(svgStream);
                    var logoSize = 40f;
                    var logoX = request.IsRtl ? width - margin - logoSize : margin;
                    canvas.DrawPicture(svg.Picture, logoX, y,
                        new SKPaint { FilterQuality = SKFilterQuality.Low });
                    y += logoSize + 6;
                }
                catch
                {
                    // SVG rendering failed silently — continue without logo
                }
            }

            DrawShapedLine(canvas, request.StoreName, headerPaint,
                request.IsRtl, width, margin, ref y);
            y += 4;

            if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            {
                DrawShapedLine(canvas, request.StoreAddress, metaPaint,
                    request.IsRtl, width, margin, ref y);
                y += 2;
            }
            if (!string.IsNullOrWhiteSpace(request.StorePhone))
            {
                var phoneText = $"Tel: {request.StorePhone}";
                DrawShapedLine(canvas, phoneText, metaPaint,
                    request.IsRtl, width, margin, ref y);
            }

            y += 16;

            using var itemPaint = new SKPaint
            {
                Typeface = normalTypeface,
                TextSize = 14,
                Color = SKColors.Black,
                IsAntialias = true,
            };

            foreach (var item in request.Items)
            {
                var price = item.UnitPricePiastres * item.Quantity / 100.0;
                var line = $"{item.Name} x{item.Quantity}  {price:F2}";
                DrawShapedLine(canvas, line, itemPaint,
                    request.IsRtl, width, margin, ref y);
                y += lineHeight;
            }

            y += 10;

            using var financePaint = new SKPaint
            {
                Typeface = normalTypeface,
                TextSize = 14,
                Color = SKColors.Black,
                IsAntialias = true,
            };

            if (showSubtotal)
            {
                var text = $"Subtotal: {request.SubtotalPiastres / 100.0:F2}";
                DrawShapedLine(canvas, text, financePaint,
                    request.IsRtl, width, margin, ref y);
                y += lineHeight;
            }

            if (showTax)
            {
                var text = $"Tax ({request.TaxPercent}%): {request.TaxPiastres / 100.0:F2}";
                DrawShapedLine(canvas, text, financePaint,
                    request.IsRtl, width, margin, ref y);
                y += lineHeight;
            }

            if (showDiscount)
            {
                var text = $"Discount: -{request.DiscountPiastres / 100.0:F2}";
                DrawShapedLine(canvas, text, financePaint,
                    request.IsRtl, width, margin, ref y);
                y += lineHeight;
            }

            using var totalPaint = new SKPaint
            {
                Typeface = boldTypeface,
                TextSize = 18,
                Color = SKColors.Black,
                IsAntialias = true,
            };
            var totalLabel = showSubtotal ? "Grand Total" : "Total";
            var totalText = $"{totalLabel}: {request.TotalPiastres / 100.0:F2}";
            DrawShapedLine(canvas, totalText, totalPaint,
                request.IsRtl, width, margin, ref y);
            y += 12;

            if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
            {
                using var footnotePaint = new SKPaint
                {
                    Typeface = normalTypeface,
                    TextSize = 11,
                    Color = SKColors.Gray,
                    IsAntialias = true,
                };
                DrawShapedLine(canvas, request.ReceiptFootnote,
                    footnotePaint, request.IsRtl, width, margin, ref y);
            }

            using var image = surface.Snapshot();
            using var data = image.Encode(SKEncodedImageFormat.Png, 100);
            using var stream = File.OpenWrite(fullPath);
            data.SaveTo(stream);

            return fullPath;
        });
    }

    private static void DrawShapedLine(
        SKCanvas canvas,
        string text,
        SKPaint paint,
        bool isRtl,
        float canvasWidth,
        float margin,
        ref float y)
    {
        var textWidth = paint.MeasureText(text);
        float x;

        if (isRtl)
        {
            x = (canvasWidth - margin) - textWidth;
        }
        else
        {
            x = margin;
        }

        canvas.DrawText(text, x, y, paint);
    }
}
