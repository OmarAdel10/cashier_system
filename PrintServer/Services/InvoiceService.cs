using System.Globalization;
using BidiReshapeSharp;
using PrintServer.Localization;
using PrintServer.Models;
using SkiaSharp;
using SkiaSharp.HarfBuzz;
using Svg.Skia;

namespace PrintServer.Services;

/// <summary>
/// Renders an A4 portrait invoice PDF (Skia PDF backend) from the same
/// <see cref="ReceiptRequest"/> the thermal/PNG paths use. The layout mirrors
/// invoice_receipt_template.html: header (logo + company), doc title, meta
/// (invoice id + created), banded items table, end-aligned totals and a
/// centered footer note. RTL mirrors the LTR layout via logical start/end
/// semantics exactly like the template's CSS, and Arabic text is reordered
/// with BidiReshape before drawing (same contract as ImageExportService).
/// </summary>
public sealed class InvoiceService
{
    // A4 portrait in points (1/72 inch).
    private const float PageWidth = 595f;
    private const float PageHeight = 842f;

    // 18mm page margin.
    private const float Margin = 51f;
    private const float ContentWidth = PageWidth - 2 * Margin;

    // Items table column widths as fractions of ContentWidth (template
    // allocates the qty/total cells ~16% / ~32% with the item cell flexible).
    private const float ItemColW = 0.52f;
    private const float QtyColW = 0.16f;

    // Logo max height: template <img height="60px"> → 45pt.
    private const float LogoMaxSize = 45f;

    // Company block is end-aligned: LTR hugs the right edge, RTL the left edge.
    // No inset so both languages align flush with the page margin.
    private const float CompanyBlockInset = 0f;

    // Palette from invoice_receipt_template.html :root.
    private static readonly SKColor Ink = new(0x16, 0x23, 0x2E);
    private static readonly SKColor Muted = new(0x6B, 0x77, 0x85);
    private static readonly SKColor Rule = new(0xE4, 0xE7, 0xEB);
    private static readonly SKColor Band = new(0xF4, 0xF6, 0xF7);
    private static readonly SKColor Strike = new(0xC0, 0x39, 0x2B);

    private readonly SvgValidator _svgValidator;

    public InvoiceService()
        : this(new SvgValidator())
    {
    }

    public InvoiceService(SvgValidator svgValidator)
    {
        _svgValidator = svgValidator;
    }

    /// <summary>
    /// Writes invoice_{timestamp}.pdf into <see cref="ReceiptRequest.OutputDirectory"/>.
    /// Returns the full path, or null when no OutputDirectory was provided
    /// (mirrors ImageExportService's guard so callers can 400 early).
    /// </summary>
    public Task<string?> SaveInvoicePdfAsync(ReceiptRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.OutputDirectory))
            return Task.FromResult<string?>(null);

        var dir = request.OutputDirectory;
        if (!Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        var fullPath = Path.Combine(dir, $"invoice_{DateTime.Now:yyyyMMdd_HHmmss}.pdf");

        return Task.Run<string?>(() =>
        {
            DrawPdf(fullPath, request);
            return fullPath;
        });
    }

    private void DrawPdf(string path, ReceiptRequest request)
    {
        var isRtl = request.IsRtl;

        // Arabic text needs a font with Arabic glyphs (Segoe UI is Latin-only)
        // plus HarfBuzz shaping for correct letter joining. Fonts are disposed
        // in reverse declaration order, so the shaper (declared last) dies
        // before the typeface it references.
        using var arRegular = isRtl ? LoadArabicTypeface("NotoSansArabic-Regular.ttf") : null!;
        using var arBold = isRtl ? LoadArabicTypeface("NotoSansArabic-Bold.ttf") : null!;
        using var enRegular = SKTypeface.FromFamilyName("Segoe UI") ?? SKTypeface.Default;
        using var enBold = SKTypeface.FromFamilyName("Segoe UI",
            SKFontStyleWeight.SemiBold, SKFontStyleWidth.Normal, SKFontStyleSlant.Upright)
            ?? SKTypeface.Default;
        using var shaper = isRtl ? new SKShaper(arRegular) : null;

        SKTypeface regular = isRtl ? arRegular : enRegular;
        SKTypeface bold = isRtl ? arBold : enBold;

        using var stream = new SKFileWStream(path);
        using var document = SKDocument.CreatePdf(stream);
        if (document == null)
            throw new InvalidOperationException("PDF backend unavailable");

        SKCanvas? canvas = document.BeginPage(PageWidth, PageHeight);
        canvas.Clear(SKColors.White);
        var y = Margin;

        // Pagination: when a section does not fit the remaining page, close
        // the current page and start a fresh one (content that does not fit
        // an A4 page — very long item lists — flows onto the next page).
        void EnsureSpace(float needed)
        {
            if (canvas != null && y + needed <= PageHeight - Margin)
                return;
            document.EndPage();
            canvas?.Dispose();
            canvas = document.BeginPage(PageWidth, PageHeight);
            canvas.Clear(SKColors.White);
            y = Margin;
        }

        using var bandPaint = new SKPaint
        {
            Color = Band,
            Style = SKPaintStyle.Fill,
            IsAntialias = true,
        };
        using var rulePaint = new SKPaint
        {
            Color = Rule,
            StrokeWidth = 1f,
            Style = SKPaintStyle.Stroke,
            IsAntialias = true,
        };

        // ---- Header: logo (start) + company (end) ----
        var hasLogo = !string.IsNullOrWhiteSpace(request.LogoSvgData);
        var logoSize = hasLogo ? MeasureLogo(request.LogoSvgData, LogoMaxSize) : null;

        float companyH = 15f * 1.4f; // name line
        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            companyH += 9.5f * 1.4f;
        if (!string.IsNullOrWhiteSpace(request.StorePhone))
            companyH += 9.5f * 1.4f;
        var headerH = Math.Max(logoSize?.H ?? 0f, companyH);
        EnsureSpace(headerH + 8);

        if (hasLogo)
        {
            // A provided-but-broken logo must NOT be silently dropped: DrawLogo
            // re-validates and throws LogoRenderException (same contract as the
            // PNG path) so the app can tell the user why the logo is missing.
            var logoW = logoSize?.W ?? LogoMaxSize;
            DrawLogo(canvas, request.LogoSvgData!,
                isRtl ? PageWidth - Margin - logoW : Margin,
                y, LogoMaxSize);
        }

        if (!string.IsNullOrWhiteSpace(request.StoreName) ||
            !string.IsNullOrWhiteSpace(request.StoreAddress) ||
            !string.IsNullOrWhiteSpace(request.StorePhone))
        {
            // Company block is end-aligned: LTR hugs the right edge, RTL the
            // left edge (text ends at the boundary).
            var companyX = isRtl ? Margin : PageWidth - Margin;
            var cy = y;
            if (!string.IsNullOrWhiteSpace(request.StoreName))
            {
                using var namePaint = new SKPaint
                {
                    Typeface = bold,
                    TextSize = 15f,
                    Color = Ink,
                    IsAntialias = true,
                };
                TextDraw.DrawText(canvas, shaper, isRtl, request.StoreName, namePaint, companyX, cy + 15f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                cy += 15f * 1.4f;
            }
            if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            {
                using var linePaint = new SKPaint
                {
                    Typeface = regular,
                    TextSize = 9.5f,
                    Color = Muted,
                    IsAntialias = true,
                };
                TextDraw.DrawText(canvas, shaper, isRtl, request.StoreAddress, linePaint, companyX, cy + 9.5f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                cy += 9.5f * 1.4f;
            }
            if (!string.IsNullOrWhiteSpace(request.StorePhone))
            {
                using var linePaint = new SKPaint
                {
                    Typeface = regular,
                    TextSize = 9.5f,
                    Color = Muted,
                    IsAntialias = true,
                };
                TextDraw.DrawText(canvas, shaper, isRtl, request.StorePhone, linePaint, companyX, cy + 9.5f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
            }
        }
        y += headerH + 8;

        // ---- Doc title (24pt/800, 26px top / 18px bottom margins) ----
        y += 19.5f;
        EnsureSpace(40f);
        using var titlePaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 24f,
            Color = Ink,
            IsAntialias = true,
        };
        var titleText = ReceiptLabels.Get(ReceiptLabels.InvoiceTitle, isRtl);
        TextDraw.DrawText(canvas, shaper, isRtl, titleText, titlePaint,
            isRtl ? PageWidth - Margin : Margin, y + 24f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        y += 24f + 13.5f;

        // ---- Meta: invoice id + created (padding-bottom 18px = 13.5pt) ----
        EnsureSpace(60f);
        var metaX = isRtl ? PageWidth - Margin : Margin;
        var invoiceIdLabel = ReceiptLabels.Label(ReceiptLabels.InvoiceId, isRtl);
        var invoiceIdValue = request.OrderNumber ?? "";
        using var idPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 10f,
            Color = Ink,
            IsAntialias = true,
        };
        // Draw label reshaped at metaX; then the value right next to it (gate keeps
        // "ORD-00001" LTR even in RTL mode).
        TextDraw.DrawText(canvas, shaper, isRtl, invoiceIdLabel, idPaint, metaX, y + 10f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        var idLabelW = TextDraw.MeasureVisual(invoiceIdLabel, idPaint, isRtl);
        var idValueX = isRtl ? metaX - idLabelW - 4f : metaX + idLabelW + 4f;
        TextDraw.DrawText(canvas, shaper, isRtl, invoiceIdValue, idPaint, idValueX, y + 10f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        y += 10f + 4.5f; // 6px margin-bottom

        var createdLabel = ReceiptLabels.Get(ReceiptLabels.CreatedLabel, isRtl);
        var createdValue = request.CreatedAt.ToString("yyyy-MM-dd h:mm tt", CultureInfo.InvariantCulture);
        using var metaLabelPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 10f,
            Color = Ink,
            IsAntialias = true,
        };
        using var metaValuePaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 10f,
            Color = Ink,
            IsAntialias = true,
        };
        TextDraw.DrawText(canvas, shaper, isRtl, createdLabel, metaLabelPaint, metaX, y + 10f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        var labelW = TextDraw.MeasureVisual(createdLabel, metaLabelPaint, isRtl);
        var valueX = isRtl ? metaX - labelW - 4f : metaX + labelW + 4f;
        TextDraw.DrawText(canvas, shaper, isRtl, createdValue, metaValuePaint, valueX, y + 10f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        y += 10f + 13.5f;

        // ---- Items table ----
        const float padX = 9f;   // 12px cell padding
        const float padY = 7.5f; // 10px cell padding
        EnsureSpace(40f);

        var headerH2 = padY + 12.5f + padY; // 9pt header line
        canvas.DrawRect(new SKRect(Margin, y, PageWidth - Margin, y + headerH2), bandPaint);
        using var headPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 9f,
            Color = Ink,
            IsAntialias = true,
        };
        var itemLabel = ReceiptLabels.Get(ReceiptLabels.ItemLabel, isRtl);
        var qtyLabel = ReceiptLabels.Get(ReceiptLabels.QtyLabel, isRtl);
        var totalLabel = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);

        // Column layout: LTR = Item (left) | QTY (middle) | Total (right)
        // RTL = Item (right) | QTY (middle) | Total (left)
        var itemColW = ItemColW * ContentWidth;
        var qtyColW = QtyColW * ContentWidth;
        var totalColW = ContentWidth - itemColW - qtyColW;

        float itemX, qtyX, totalX;
        if (isRtl)
        {
            // RTL: Item on far right, QTY middle, Total on far left
            var itemLeft = PageWidth - Margin - itemColW;
            var qtyLeft = itemLeft - qtyColW;
            var totalLeft = Margin;
            itemX = itemLeft + itemColW - padX; // right-aligned within item column
            qtyX = qtyLeft + qtyColW - padX;    // right-aligned within qty column
            totalX = totalLeft + totalColW - padX; // right-aligned within total column
        }
        else
        {
            // LTR: Item on far left, QTY middle, Total on far right
            var itemLeft = Margin;
            var qtyLeft = itemLeft + itemColW;
            var totalLeft = qtyLeft + qtyColW;
            itemX = itemLeft + padX;          // left-aligned within item column
            qtyX = qtyLeft + qtyColW - padX;  // right-aligned within qty column
            totalX = totalLeft + totalColW - padX; // right-aligned within total column
        }

        TextDraw.DrawText(canvas, shaper, isRtl, itemLabel, headPaint, itemX, y + padY + 9f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        TextDraw.DrawText(canvas, shaper, isRtl, qtyLabel, headPaint, qtyX, y + padY + 9f, RtlAlign.Right);
        TextDraw.DrawText(canvas, shaper, isRtl, totalLabel, headPaint, totalX, y + padY + 9f, RtlAlign.Right);
        y += headerH2;

        using var itemNamePaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 10.5f,
            Color = Ink,
            IsAntialias = true,
        };
        using var itemDescPaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9.5f,
            Color = Muted,
            IsAntialias = true,
        };
        using var numPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 10.5f,
            Color = Ink,
            IsAntialias = true,
            TextAlign = SKTextAlign.Right,
        };

        foreach (var item in request.Items)
        {
            var hasDesc = !string.IsNullOrWhiteSpace(item.Barcode);
            var nameLineH = 10.5f * 1.38f;
            var descLineH = hasDesc ? 9.5f * 1.38f : 0f;
            var rowH = 2 * padY + nameLineH + descLineH;
            EnsureSpace(rowH);

            TextDraw.DrawText(canvas, shaper, isRtl, item.Name, itemNamePaint, itemX, y + padY + 10.5f,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            if (hasDesc)
            {
                TextDraw.DrawText(canvas, shaper, isRtl, item.Barcode, itemDescPaint, itemX,
                    y + padY + 10.5f + 13.5f, isRtl ? RtlAlign.Right : RtlAlign.Left);
            }

            var qtyText = item.Quantity.ToString(CultureInfo.InvariantCulture);
            TextDraw.DrawText(canvas, shaper, isRtl, qtyText, numPaint, qtyX, y + padY + 10.5f, RtlAlign.Right);

            // Per-item discount: UnitPricePiastres * Quantity differs from the
            // line TotalPiastres. Render the original struck through, then the
            // final price below (template .price-original / .price-final).
            var hasDiscount = item.TotalPiastres != item.UnitPricePiastres * item.Quantity;
            var finalAmount = FormatAmount(item.TotalPiastres, isRtl);
            if (hasDiscount)
            {
                var originalAmount = FormatAmount(item.UnitPricePiastres * item.Quantity, isRtl);
                using var strikePaint = new SKPaint
                {
                    Typeface = regular,
                    TextSize = 9.5f,
                    Color = Strike,
                    IsAntialias = true,
                    TextAlign = SKTextAlign.Left,
                };
                DrawStruckText(canvas, shaper, isRtl, originalAmount, strikePaint, totalX,
                    y + padY + 9.5f);
                TextDraw.DrawText(canvas, shaper, isRtl, finalAmount, numPaint, totalX,
                    y + padY + 10.5f + 14f, RtlAlign.Right);
            }
            else
            {
                TextDraw.DrawText(canvas, shaper, isRtl, finalAmount, numPaint, totalX,
                    y + padY + 10.5f, RtlAlign.Right);
            }

            y += rowH;
            canvas.DrawLine(Margin, y, PageWidth - Margin, y, rulePaint);
        }

        // ---- Totals (end-aligned, min-width 260px = 195pt) ----
        y += 12f; // 16px top margin
        using var totalsLabelPaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 10f,
            Color = Muted,
            IsAntialias = true,
        };
        using var totalsValuePaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 10f,
            Color = Ink,
            IsAntialias = true,
            TextAlign = SKTextAlign.Right,
        };
        using var grandLabelPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 12f,
            Color = Muted,
            IsAntialias = true,
        };
        using var grandValuePaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 12f,
            Color = Ink,
            IsAntialias = true,
            TextAlign = SKTextAlign.Right,
        };

        var rows = new List<(string Label, string? Suffix, string Value, bool Grand)>
        {
            (ReceiptLabels.Get(ReceiptLabels.Subtotal, isRtl), null, FormatAmount(request.SubtotalPiastres, isRtl), false),
        };
        if (request.DiscountPiastres > 0)
        {
            rows.Add((
                ReceiptLabels.Label(ReceiptLabels.Discount, isRtl),
                string.Format("({0}%)", request.DiscountPercent),
                "-" + FormatAmount(request.DiscountPiastres, isRtl),
                false));
        }
        if (request.TaxPiastres > 0)
        {
            rows.Add((
                ReceiptLabels.Label(ReceiptLabels.Tax, isRtl),
                string.Format("({0}%)", request.TaxPercent),
                FormatAmount(request.TaxPiastres, isRtl),
                false));
        }
        rows.Add((ReceiptLabels.Get(ReceiptLabels.GrandTotal, isRtl), null, FormatAmount(request.TotalPiastres, isRtl), true));

        var maxLabelW = rows.Max(r =>
            r.Grand ? grandLabelPaint.MeasureText(r.Label + r.Suffix) : totalsLabelPaint.MeasureText(r.Label + r.Suffix));
        var maxValW = rows.Max(r =>
            r.Grand ? grandValuePaint.MeasureText(r.Value) : totalsValuePaint.MeasureText(r.Value));
        var tableW = Math.Max(195f, maxLabelW + 12f + maxValW);

        // End-aligned block: LTR table hugs the right edge; RTL hugs the left.
        float tableLeft = PageWidth - Margin - tableW;
        float tableRight = PageWidth - Margin;
        if (isRtl)
        {
            tableLeft = Margin;
            tableRight = Margin + tableW;
        }

        foreach (var (label, suffix, value, grand) in rows)
        {
            if (grand)
            {
                EnsureSpace(30f);
                canvas.DrawLine(tableLeft, y, tableRight, y, rulePaint);
                y += 7.5f; // 10px padding-top
                TextDraw.DrawText(canvas, shaper, isRtl, label, grandLabelPaint,
                    isRtl ? tableRight : tableLeft, y + 12f,
                    isRtl ? RtlAlign.Right : RtlAlign.Left);
                TextDraw.DrawText(canvas, shaper, isRtl, value, grandValuePaint,
                    isRtl ? tableLeft : tableRight, y + 12f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                y += 12f + 4.5f; // 6px padding-bottom
            }
            else
            {
                EnsureSpace(22f);
                TextDraw.DrawText(canvas, shaper, isRtl, label, totalsLabelPaint,
                    isRtl ? tableRight : tableLeft, y + 10f,
                    isRtl ? RtlAlign.Right : RtlAlign.Left);
                // "(N%)" is digits/punct only: drawn beside the label so it is
                // never reshaped with Arabic (parens/percent would flip).
                if (suffix != null)
                {
                    var suffixLabelW = TextDraw.MeasureVisual(label, totalsLabelPaint, isRtl);
                    TextDraw.DrawText(canvas, shaper, isRtl, suffix, totalsLabelPaint,
                        isRtl ? tableRight - suffixLabelW - 4f : tableLeft + suffixLabelW + 4f, y + 10f,
                        isRtl ? RtlAlign.Right : RtlAlign.Left);
                }
                TextDraw.DrawText(canvas, shaper, isRtl, value, totalsValuePaint,
                    isRtl ? tableLeft : tableRight, y + 10f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                y += 10f + 9f; // 6px vertical padding + line
            }
        }

        // ---- Footer note (24px top margin, 9pt muted centered) ----
        y += 18f;
        EnsureSpace(30f);
        var note = string.IsNullOrWhiteSpace(request.ReceiptFootnote)
            ? ReceiptLabels.Get(ReceiptLabels.FooterThanks, isRtl)
            : request.ReceiptFootnote;
        using var footnotePaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9f,
            Color = Muted,
            IsAntialias = true,
            TextAlign = SKTextAlign.Center,
        };
        TextDraw.DrawText(canvas, shaper, isRtl, note, footnotePaint, PageWidth / 2f, y + 9f, RtlAlign.Center);
        y += 9f + 18f; // footer height + bottom margin

        // ---- Receipt UUID (at the very bottom, below footer) ----
        if (!string.IsNullOrWhiteSpace(request.ReceiptUuid))
        {
            EnsureSpace(20f);
            using var uuidPaint = new SKPaint
            {
                Typeface = regular,
                TextSize = 8f,
                Color = Muted,
                IsAntialias = true,
            };
            // Split label/value so "XXXX-XXXX-..." UUIDs keep LTR order in RTL mode.
            var uuidLabel = ReceiptLabels.Label(ReceiptLabels.ReceiptUuid, isRtl);
            var uuidX = isRtl ? PageWidth - Margin : Margin;
            TextDraw.DrawText(canvas, shaper, isRtl, uuidLabel, uuidPaint, uuidX, y + 8f,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            var uuidLabelW = TextDraw.MeasureVisual(uuidLabel, uuidPaint, isRtl);
            var uuidValueX = isRtl ? uuidX - uuidLabelW - 4f : uuidX + uuidLabelW + 4f;
            TextDraw.DrawText(canvas, shaper, isRtl, request.ReceiptUuid, uuidPaint, uuidValueX, y + 8f,
                isRtl ? RtlAlign.Right : RtlAlign.Left);
            y += 8f + 8f;
        }

        document.EndPage();
        canvas.Dispose();
        document.Close();
    }

    /// <summary>
    /// Draws right-aligned text (ending at <paramref name="x"/>) with a
    /// strike-through line across its middle — the template's
    /// .price-original (original price on a discounted line).
    /// </summary>
    private static void DrawStruckText(
        SKCanvas canvas,
        SKShaper? shaper,
        bool isRtl,
        string text,
        SKPaint paint,
        float x,
        float y)
    {
        var width = paint.MeasureText(text);
        if (!isRtl)
        {
            canvas.DrawText(text, x - width, y, paint);
        }
        else
        {
            string? visual = null;
            try
            {
                visual = BidiReshape.ProcessString(text);
            }
            catch
            {
                // Fall through to unshaped text below.
            }
            if (!string.IsNullOrEmpty(visual))
            {
                width = paint.MeasureText(visual);
                canvas.DrawText(visual, x - width, y, paint);
            }
else
            {
                canvas.DrawText(text, x - width, y, paint);
            }
        }

        using var strikePaint = new SKPaint
        {
            Color = Strike,
            StrokeWidth = 1f,
            Style = SKPaintStyle.Stroke,
            IsAntialias = true,
        };
        var strikeY = y - paint.TextSize * 0.32f;
        canvas.DrawLine(x - width, strikeY, x, strikeY, strikePaint);
    }

    /// <summary>
    /// Loads one of the bundled Noto Sans Arabic faces (SIL OFL, shipped
    /// under Assets/ so the installer copies it with the server). Falls back
    /// to any Arabic-capable host face so the PDF path never crashes when the
    /// asset is missing.
    /// </summary>
    private static SKTypeface LoadArabicTypeface(string fileName)
    {
        var fontPath = Path.Combine(AppContext.BaseDirectory, "Assets", fileName);
        if (File.Exists(fontPath))
        {
            using var stream = File.OpenRead(fontPath);
            using var data = SKData.Create(stream);
            var typeface = SKTypeface.FromData(data);
            if (typeface != null)
                return typeface;
        }
        return SKTypeface.FromFamilyName("Noto Naskh Arabic")
            ?? SKTypeface.FromFamilyName("Segoe UI")
            ?? SKTypeface.Default;
    }

    /// <summary>
    /// Measures the logo scaled to <paramref name="maxSize"/> on its longest
    /// side. Returns null when absent/broken so the caller can lay out the
    /// header without it; broken logos surface via <see cref="LogoRenderException"/>
    /// at draw time.
    /// </summary>
    private (float W, float H)? MeasureLogo(string logoSvgData, float maxSize)
    {
        try
        {
            var svgBytes = Convert.FromBase64String(logoSvgData);
            if (svgBytes.Length > 5 * 1024 * 1024)
                return null;

            using var svg = new SKSvg();
            using var svgStream = new MemoryStream(svgBytes);
            svg.Load(svgStream);

            if (svg.Picture == null)
                return null;

            var cullRect = svg.Picture.CullRect;
            if (!float.IsFinite(cullRect.Width) || !float.IsFinite(cullRect.Height) ||
                cullRect.Width <= 0 || cullRect.Height <= 0)
                return null;

            var scale = maxSize / Math.Max(cullRect.Width, cullRect.Height);
            return (cullRect.Width * scale, cullRect.Height * scale);
        }
        catch
        {
            return null;
        }
    }

    private void DrawLogo(SKCanvas canvas, string logoSvgData, float x, float y, float maxSize)
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

            var scale = maxSize / Math.Max(cullRect.Width, cullRect.Height);
            canvas.Save();
            canvas.Translate(x, y);
            canvas.Scale(scale, scale);
            canvas.DrawPicture(svg.Picture, 0, 0, new SKPaint { FilterQuality = SKFilterQuality.Low });
            canvas.Restore();
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

    private static string FormatAmount(int piastres, bool isRtl) =>
        ReceiptLabels.FormatCurrency(piastres, isRtl);
}