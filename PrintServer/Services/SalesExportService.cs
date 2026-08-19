using System.Globalization;
using PrintServer.Localization;
using PrintServer.Models;
using SkiaSharp;
using SkiaSharp.HarfBuzz;
using Svg.Skia;

namespace PrintServer.Services;

/// <summary>
/// Renders the stacked sales-export PDF (A4 landscape, Skia PDF backend)
/// from <see cref="SalesExportRequest"/> — the sales_export_template.html
/// layout: logo + company header, doc title + period, inline summary stats,
/// a 10-column transactions table (Type | Receipt ID | Date | Items Qty |
/// Items | Cashier | Discount | Tax | Amount | Total) with one row per
/// transaction and line items stacked inside the Items/Amount cells, and an
/// end-aligned totals block. The table header repeats on every page and rows
/// are measured (including stacked items) so tall rows flow to the next page.
/// RTL mirrors the LTR layout via logical start/end semantics like the
/// template's dir=rtl, and Arabic text is reordered with BidiReshape before
/// drawing (same contract as InvoiceService).
/// </summary>
public sealed class SalesExportService
{
    // A4 landscape in points (1/72 inch).
    private const float PageWidth = 842f;
    private const float PageHeight = 595f;

    // ~16mm page margin (template .page padding 14mm 16mm).
    private const float Margin = 45f;
    private const float ContentWidth = PageWidth - 2 * Margin;

    // Logo max height: template <img height="44px"> → 33pt.
    private const float LogoMaxSize = 33f;

    // End-aligned company block inset from the page edge (mirrors
    // InvoiceService) so header text no longer hugs the margin.
    private const float CompanyBlockInset = 100f;

    // Palette from sales_export_template.html :root.
    private static readonly SKColor Ink = new(0x16, 0x23, 0x2E);
    private static readonly SKColor Muted = new(0x6B, 0x77, 0x85);
    private static readonly SKColor Rule = new(0xE4, 0xE7, 0xEB);
    private static readonly SKColor Band = new(0xF4, 0xF6, 0xF7);
    private static readonly SKColor Zebra = new(0xFA, 0xFB, 0xFC);
    private static readonly SKColor ReceiptGreen = new(0x1C, 0x7A, 0x4B);
    private static readonly SKColor ReceiptGreenBg = new(0xE7, 0xF5, 0xEC);
    private static readonly SKColor ExpenseRed = new(0xB2, 0x3B, 0x3B);
    private static readonly SKColor ExpenseRedBg = new(0xFB, 0xEB, 0xEB);

    // Column widths as fractions of ContentWidth: Items keeps 150pt and
    // wraps; Cashier narrows to 56pt; the freed width goes to the stacked
    // Amount/Total numeric cells, which previously clipped large totals.
    private static readonly (float Left, float W, bool Num)[] Columns =
    [
        (0.000f, 0.075f, false), // Type (badge)
        (0.075f, 0.095f, false), // Receipt ID
        (0.170f, 0.100f, false), // Date
        (0.270f, 0.055f, true),  // Items Qty
        (0.325f, 0.200f, false), // Items (stacked, wrapped)
        (0.525f, 0.075f, false), // Cashier
        (0.600f, 0.070f, true),  // Discount
        (0.670f, 0.070f, true),  // Tax
        (0.740f, 0.115f, true),  // Amount (stacked)
        (0.855f, 0.145f, true),  // Total
    ];

    private readonly SvgValidator _svgValidator;

    public SalesExportService()
        : this(new SvgValidator())
    {
    }

    public SalesExportService(SvgValidator svgValidator)
    {
        _svgValidator = svgValidator;
    }

    /// <summary>Word-wraps text to maxWidth by spaces (LTR) or visual-width
    /// spacing (RTL); hard-breaks single over-long words by characters.
    /// Tracks line count so callers can size row heights.</summary>
    internal static List<string> WrapText(string text, SKPaint paint, bool isRtl, float maxWidth)
    {
        if (string.IsNullOrEmpty(text)) return new List<string> { "" };
        var lines = new List<string>();
        foreach (var word in text.Split(' '))
        {
            if (lines.Count == 0) lines.Add("");
            var probe = lines[^1].Length == 0 ? word : lines[^1] + " " + word;
            if (TextDraw.MeasureVisual(probe, paint, isRtl) <= maxWidth || lines[^1].Length == 0)
                lines[^1] = probe;
            else
                lines.Add(word);
        }
        for (var i = 0; i < lines.Count; i++)
            while (TextDraw.MeasureVisual(lines[i], paint, isRtl) > maxWidth && lines[i].Length > 1)
                lines[i] = lines[i][..^1];
        return lines;
    }

    /// <summary>
    /// Writes sales_export_{timestamp}.pdf into
    /// <see cref="SalesExportRequest.OutputDirectory"/>. Returns the full
    /// path, or null when no OutputDirectory was provided (so callers can
    /// 400 early, same contract as InvoiceService).
    /// </summary>
    public Task<string?> SaveSalesExportPdfAsync(SalesExportRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.OutputDirectory))
            return Task.FromResult<string?>(null);

        var dir = request.OutputDirectory;
        if (!Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        var fullPath = Path.Combine(dir, $"sales_export_{DateTime.Now:yyyyMMdd_HHmmss}.pdf");

        return Task.Run<string?>(() =>
        {
            DrawPdf(fullPath, request);
            return fullPath;
        });
    }

    private void DrawPdf(string path, SalesExportRequest request)
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
        // the current page and start a fresh one. The table header re-draws
        // at the top of every continuation page (template: thead repeats).
        void EnsureSpace(float needed, Action? onNewPage = null)
        {
            if (canvas != null && y + needed <= PageHeight - Margin)
                return;
            document.EndPage();
            canvas?.Dispose();
            canvas = document.BeginPage(PageWidth, PageHeight);
            canvas.Clear(SKColors.White);
            y = Margin;
            onNewPage?.Invoke();
        }

        using var bandPaint = new SKPaint
        {
            Color = Band,
            Style = SKPaintStyle.Fill,
            IsAntialias = true,
        };
        using var zebraPaint = new SKPaint
        {
            Color = Zebra,
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

        // Column anchors. LTR: text cells start at colLeft+pad, numeric cells
        // end at colRight-pad. RTL mirrors every anchor around the page center
        // so the logical column order reads right-to-left (template dir=rtl).
        const float padX = 6f;   // 8px cell padding
        const float padY = 6f;   // 8px cell padding
        const float lineH = 9.5f * 1.4f; // stacked line-item line height
        float ColLeft(int i) => Margin + Columns[i].Left * ContentWidth;
        float ColRight(int i) => ColLeft(i) + Columns[i].W * ContentWidth;
        (float X, RtlAlign Align) TextAnchor(int i) => isRtl
            ? (PageWidth - ColRight(i) + padX, RtlAlign.Right)
            : (ColLeft(i) + padX, RtlAlign.Left);
        (float X, RtlAlign Align) NumAnchor(int i) => isRtl
            ? (PageWidth - ColLeft(i) - padX, RtlAlign.Left)
            : (ColRight(i) - padX, RtlAlign.Right);

        // ---- Header: logo (start) + company (end) ----
        var hasLogo = !string.IsNullOrWhiteSpace(request.LogoSvgData);
        var logoSize = hasLogo ? MeasureLogo(request.LogoSvgData, LogoMaxSize) : null;

        float companyH = 12f * 1.4f; // name line
        if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            companyH += 9f * 1.4f;
        if (!string.IsNullOrWhiteSpace(request.StorePhone))
            companyH += 9f * 1.4f;
        var headerH = Math.Max(logoSize?.H ?? 0f, companyH);
        EnsureSpace(headerH + 8);

        if (hasLogo)
        {
            // A provided-but-broken logo must NOT be silently dropped: DrawLogo
            // re-validates and throws LogoRenderException (same contract as the
            // invoice path) so the app can tell the user why the logo is missing.
            var logoW = logoSize?.W ?? LogoMaxSize;
            DrawLogo(canvas, request.LogoSvgData!,
                isRtl ? PageWidth - Margin - logoW : Margin,
                y, LogoMaxSize);
        }

        if (!string.IsNullOrWhiteSpace(request.StoreName) ||
            !string.IsNullOrWhiteSpace(request.StoreAddress) ||
            !string.IsNullOrWhiteSpace(request.StorePhone))
        {
            var companyX = isRtl ? Margin : PageWidth - Margin - CompanyBlockInset;
            var cy = y;
            if (!string.IsNullOrWhiteSpace(request.StoreName))
            {
                using var namePaint = new SKPaint
                {
                    Typeface = bold,
                    TextSize = 12f,
                    Color = Ink,
                    IsAntialias = true,
                };
                TextDraw.DrawText(canvas, shaper, isRtl, request.StoreName, namePaint, companyX, cy + 12f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                cy += 12f * 1.4f;
            }
            if (!string.IsNullOrWhiteSpace(request.StoreAddress))
            {
                using var linePaint = new SKPaint
                {
                    Typeface = regular,
                    TextSize = 9f,
                    Color = Muted,
                    IsAntialias = true,
                };
                TextDraw.DrawText(canvas, shaper, isRtl, request.StoreAddress, linePaint, companyX, cy + 9f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                cy += 9f * 1.4f;
            }
            if (!string.IsNullOrWhiteSpace(request.StorePhone))
            {
                using var linePaint = new SKPaint
                {
                    Typeface = regular,
                    TextSize = 9f,
                    Color = Muted,
                    IsAntialias = true,
                };
                TextDraw.DrawText(canvas, shaper, isRtl, request.StorePhone, linePaint, companyX, cy + 9f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
            }
        }
        y += headerH + 8;

        // ---- Doc title (18pt/800) + period (9.5pt muted) ----
        y += 12f; // 16px top margin
        EnsureSpace(40f);
        var titleText = string.IsNullOrWhiteSpace(request.Title)
            ? SalesExportLabels.Get(SalesExportLabels.SalesReportTitle, isRtl)
            : request.Title;
        using var titlePaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 18f,
            Color = Ink,
            IsAntialias = true,
        };
        TextDraw.DrawText(canvas, shaper, isRtl, titleText, titlePaint,
            isRtl ? PageWidth - Margin : Margin, y + 18f,
            isRtl ? RtlAlign.Right : RtlAlign.Left);
        // 4px margin-bottom (+6pt: extra air before the period line)
        y += 18f + 9f;

        // Period: label + value split (same contract as InvoiceService) so the
        // pure-Latin date value is never reshaped with the Arabic label.
        var periodLabel = SalesExportLabels.Label(SalesExportLabels.ReportPeriod, isRtl);
        var periodValue = $"{request.PeriodStart} - {request.PeriodEnd}";
        using var periodPaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9.5f,
            Color = Muted,
            IsAntialias = true,
        };
        var periodX = isRtl ? PageWidth - Margin : Margin;
        var periodLabelW = TextDraw.MeasureVisual(periodLabel, periodPaint, isRtl);
        if (isRtl)
        {
            TextDraw.DrawText(canvas, shaper, isRtl, periodLabel, periodPaint, periodX, y + 9.5f,
                RtlAlign.Right);
            TextDraw.DrawText(canvas, shaper, isRtl, periodValue, periodPaint, periodX - periodLabelW - 4f,
                y + 9.5f, RtlAlign.Right);
        }
        else
        {
            TextDraw.DrawText(canvas, shaper, isRtl, periodLabel, periodPaint, periodX, y + 9.5f,
                RtlAlign.Left);
            TextDraw.DrawText(canvas, shaper, isRtl, periodValue, periodPaint, periodX + periodLabelW + 4f,
                y + 9.5f, RtlAlign.Left);
        }
        y += 9.5f * 1.4f + 10.5f; // 14px margin-bottom

        // ---- Summary stats (label muted + value 700, 32px gaps) ----
        var totalTransactions = request.Rows.Count;
        var totalReceipts = request.Rows.Count(r => !IsExpense(r));
        var totalExpenses = request.Rows.Count(IsExpense);
        var grandTotal = request.Rows.Sum(r => r.TotalPiastres);
        var avgTransaction = totalTransactions > 0
            ? (grandTotal / (double)totalTransactions).ToString("F2", CultureInfo.InvariantCulture)
            : "0.00";
        var stats = new List<(string Label, string Value)>
        {
            (SalesExportLabels.Get(SalesExportLabels.TotalTransactions, isRtl),
                totalTransactions.ToString(CultureInfo.InvariantCulture)),
            (SalesExportLabels.Get(SalesExportLabels.TotalReceipts, isRtl),
                totalReceipts.ToString(CultureInfo.InvariantCulture)),
            (SalesExportLabels.Get(SalesExportLabels.TotalExpenses, isRtl),
                totalExpenses.ToString(CultureInfo.InvariantCulture)),
            (SalesExportLabels.Get(SalesExportLabels.AvgTransaction, isRtl), avgTransaction),
        };
        using var statLabelPaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9.5f,
            Color = Muted,
            IsAntialias = true,
        };
        using var statValuePaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 9.5f,
            Color = Ink,
            IsAntialias = true,
        };
        var statX = isRtl ? PageWidth - Margin : Margin;
        foreach (var (label, value) in stats)
        {
            var labelW = statLabelPaint.MeasureText(label);
            var valueW = statValuePaint.MeasureText(value);
            if (isRtl)
            {
                TextDraw.DrawText(canvas, shaper, isRtl, label, statLabelPaint, statX, y + 9.5f, RtlAlign.Right);
                TextDraw.DrawText(canvas, shaper, isRtl, value, statValuePaint, statX - labelW - 4f, y + 9.5f,
                    RtlAlign.Right);
                statX -= labelW + 4f + valueW + 24f; // 32px gap
            }
            else
            {
                TextDraw.DrawText(canvas, shaper, isRtl, label, statLabelPaint, statX, y + 9.5f, RtlAlign.Left);
                TextDraw.DrawText(canvas, shaper, isRtl, value, statValuePaint, statX + labelW + 4f, y + 9.5f,
                    RtlAlign.Left);
                statX += labelW + 4f + valueW + 24f;
            }
        }
        y += 9.5f * 1.4f + 10.5f; // 14px margin-bottom

        // ---- Table ----
        var headerH2 = padY + 8f * 1.4f + padY;

        // Localized column labels (positional — widths stay language-agnostic).
        var colLabels = new[]
        {
            SalesExportLabels.Get(SalesExportLabels.TypeLabel, isRtl),
            SalesExportLabels.Get(SalesExportLabels.ReceiptId, isRtl),
            SalesExportLabels.Get(SalesExportLabels.DateLabel, isRtl),
            SalesExportLabels.Get(SalesExportLabels.ItemsQty, isRtl),
            SalesExportLabels.Get(SalesExportLabels.ItemsLabel, isRtl),
            SalesExportLabels.Get(SalesExportLabels.Cashier, isRtl),
            SalesExportLabels.Get(SalesExportLabels.DiscountLabel, isRtl),
            SalesExportLabels.Get(SalesExportLabels.TaxLabel, isRtl),
            SalesExportLabels.Get(SalesExportLabels.Amount, isRtl),
            SalesExportLabels.Get(SalesExportLabels.Total, isRtl),
        };

        void DrawTableHeader()
        {
            canvas.DrawRect(new SKRect(Margin, y, PageWidth - Margin, y + headerH2), bandPaint);
            using var headPaint = new SKPaint
            {
                Typeface = bold,
                TextSize = 8f,
                Color = Ink,
                IsAntialias = true,
            };
            for (var i = 0; i < Columns.Length; i++)
            {
                var (x, align) = Columns[i].Num ? NumAnchor(i) : TextAnchor(i);
                TextDraw.DrawText(canvas, shaper, isRtl, colLabels[i], headPaint, x, y + padY + 8f, align);
            }
            y += headerH2;
        }

        EnsureSpace(headerH2 + 8);
        DrawTableHeader();

        using var textPaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9.5f,
            Color = Ink,
            IsAntialias = true,
        };
        using var numPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 9.5f,
            Color = Ink,
            IsAntialias = true,
        };
        using var dottedPaint = new SKPaint
        {
            Color = Rule,
            StrokeWidth = 1f,
            Style = SKPaintStyle.Stroke,
            IsAntialias = true,
        };
        dottedPaint.PathEffect = SKPathEffect.CreateDash([2f, 2f], 0f);

        for (var index = 0; index < request.Rows.Count; index++)
        {
            var row = request.Rows[index];

            // Wrap every item name to the Items cell; the row height sums the
            // wrapped line counts (min 1 line for empty item lists).
            var itemsW = Columns[4].W * ContentWidth;
            var wrappedItems = new List<List<string>>(row.Items.Count);
            var totalLines = 0;
            foreach (var item in row.Items)
            {
                var wrapped = WrapText(item.Name ?? "", textPaint, isRtl, itemsW);
                wrappedItems.Add(wrapped);
                totalLines += wrapped.Count;
            }
            var lineCount = Math.Max(totalLines, 1);
            var rowH = 2 * padY + lineCount * lineH;
            EnsureSpace(rowH, DrawTableHeader);

            var rowTop = y;
            if (index % 2 == 1)
                canvas.DrawRect(new SKRect(Margin, rowTop, PageWidth - Margin, rowTop + rowH), zebraPaint);

            // Type badge (col 0): green pill for receipts, red for expenses.
            var (typeX, typeAlign) = TextAnchor(0);
            var badgeBaseline = rowTop + padY + 8f;
            var isExpense = IsExpense(row);
            var badgeLabel = isExpense
                ? SalesExportLabels.Get(SalesExportLabels.ExpenseBadge, isRtl)
                : SalesExportLabels.Get(SalesExportLabels.ReceiptBadge, isRtl);
            using (var badgePaint = new SKPaint
            {
                Typeface = bold,
                TextSize = 8f,
                Color = isExpense ? ExpenseRed : ReceiptGreen,
                IsAntialias = true,
            })
            {
                var badgeW = badgePaint.MeasureText(badgeLabel) + 2 * 6f; // 8px padding
                var badgeH = 8f + 2 * 1.5f; // 2px padding
                var badgeLeft = typeAlign == RtlAlign.Right ? typeX - badgeW : typeX;
                using var badgeBg = new SKPaint
                {
                    Color = isExpense ? ExpenseRedBg : ReceiptGreenBg,
                    IsAntialias = true,
                };
                canvas.DrawRoundRect(new SKRect(badgeLeft, badgeBaseline - badgeH + 1.5f,
                    badgeLeft + badgeW, badgeBaseline + 1.5f), 3f, 3f, badgeBg);
                TextDraw.DrawText(canvas, shaper, isRtl, badgeLabel, badgePaint,
                    badgeLeft + badgeW / 2f, badgeBaseline, RtlAlign.Center);
            }

            // Receipt ID (1), Date (2), Cashier (5).
            var (idX, idAlign) = TextAnchor(1);
            TextDraw.DrawText(canvas, shaper, isRtl, row.Id, textPaint, idX, rowTop + padY + 9.5f, idAlign);
            var (dateX, dateAlign) = TextAnchor(2);
            TextDraw.DrawText(canvas, shaper, isRtl, row.Date, textPaint, dateX, rowTop + padY + 9.5f, dateAlign);
            var (cashierX, cashierAlign) = TextAnchor(5);
            TextDraw.DrawText(canvas, shaper, isRtl, row.Cashier, textPaint, cashierX, rowTop + padY + 9.5f,
                cashierAlign);

            // Items Qty (3): number of line items (first baseline, like Total).
            var (qtyX, qtyAlign) = NumAnchor(3);
            TextDraw.DrawText(canvas, shaper, isRtl, Math.Max(row.Items.Count, 1).ToString(CultureInfo.InvariantCulture),
                numPaint, qtyX, rowTop + padY + 9.5f, qtyAlign);

            // Discount (6) / Tax (7): percent columns.
            var (discX, discAlign) = NumAnchor(6);
            TextDraw.DrawText(canvas, shaper, isRtl, $"{row.DiscountPercent}%", numPaint, discX,
                rowTop + padY + 9.5f, discAlign);
            var (taxX, taxAlign) = NumAnchor(7);
            TextDraw.DrawText(canvas, shaper, isRtl, $"{row.TaxPercent}%", numPaint, taxX,
                rowTop + padY + 9.5f, taxAlign);

            // Items (4) + Amount (8): stacked line items, wrapped names on
            // increasing baselines (lineH apart); each item's amount stays on
            // that item's first baseline (same contract as before).
            var (itemsX, itemsAlign) = TextAnchor(4);
            var (amountX, amountAlign) = NumAnchor(8);
            var itemsLeft = ColLeft(4);
            var itemsRight = ColRight(4);
            var itemBaseline = rowTop + padY + 9.5f;
            for (var li = 0; li < row.Items.Count; li++)
            {
                var item = row.Items[li];
                var firstBaseline = itemBaseline;
                foreach (var line in wrappedItems[li])
                {
                    TextDraw.DrawText(canvas, shaper, isRtl, line, textPaint, itemsX, itemBaseline, itemsAlign);
                    itemBaseline += lineH;
                }
                var lineAmount = FormatAmount(item.Quantity * item.PricePiastres);
                TextDraw.DrawText(canvas, shaper, isRtl, lineAmount, numPaint, amountX, firstBaseline, amountAlign);
                if (li < row.Items.Count - 1)
                {
                    canvas.DrawLine(itemsLeft, itemBaseline - 9.5f - 1.5f,
                        itemsRight, itemBaseline - 9.5f - 1.5f, dottedPaint);
                }
            }
            if (row.Items.Count == 0)
            {
                TextDraw.DrawText(canvas, shaper, isRtl, FormatAmount(row.AmountPiastres), numPaint,
                    amountX, rowTop + padY + 9.5f, amountAlign);
            }

            // Total (9).
            var (totalX, totalAlign) = NumAnchor(9);
            TextDraw.DrawText(canvas, shaper, isRtl, FormatAmount(row.TotalPiastres), numPaint, totalX,
                rowTop + padY + 9.5f, totalAlign);

            y += rowH;
            canvas.DrawLine(Margin, y, PageWidth - Margin, y, rulePaint);
        }

        // ---- Totals (end-aligned, min-width 240px = 180pt) ----
        y += 10.5f; // 14px top margin
        var subtotal = request.Rows.Sum(r => r.AmountPiastres);
        var discountSum = request.Rows.Sum(r => r.DiscountPiastres);
        var grand = request.Rows.Sum(r => r.TotalPiastres);

        using var totalsLabelPaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9.5f,
            Color = Muted,
            IsAntialias = true,
        };
        using var totalsValuePaint = new SKPaint
        {
            Typeface = regular,
            TextSize = 9.5f,
            Color = Ink,
            IsAntialias = true,
        };
        using var grandLabelPaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 11f,
            Color = Muted,
            IsAntialias = true,
        };
        using var grandValuePaint = new SKPaint
        {
            Typeface = bold,
            TextSize = 11f,
            Color = Ink,
            IsAntialias = true,
        };

        var totalsRows = new List<(string Label, string Value, bool Grand)>
        {
            (SalesExportLabels.Get(SalesExportLabels.Subtotal, isRtl), FormatAmount(subtotal), false),
        };
        if (discountSum > 0)
        {
            totalsRows.Add((
                SalesExportLabels.Get(SalesExportLabels.Discount, isRtl),
                "-" + FormatAmount(discountSum),
                false));
        }
        totalsRows.Add((
            SalesExportLabels.Get(SalesExportLabels.GrandTotal, isRtl),
            FormatAmount(grand),
            true));

        var maxLabelW = totalsRows.Max(r =>
            r.Grand ? grandLabelPaint.MeasureText(r.Label) : totalsLabelPaint.MeasureText(r.Label));
        var maxValW = totalsRows.Max(r =>
            r.Grand ? grandValuePaint.MeasureText(r.Value) : totalsValuePaint.MeasureText(r.Value));
        var tableW = Math.Max(180f, maxLabelW + 12f + maxValW);

        // End-aligned block: LTR hugs the right edge; RTL hugs the left.
        float tableLeft = PageWidth - Margin - tableW;
        float tableRight = PageWidth - Margin;
        if (isRtl)
        {
            tableLeft = Margin;
            tableRight = Margin + tableW;
        }

        foreach (var (label, value, grandRow) in totalsRows)
        {
            if (grandRow)
            {
                EnsureSpace(30f);
                canvas.DrawLine(tableLeft, y, tableRight, y, rulePaint);
                y += 7.5f; // 10px padding-top
                TextDraw.DrawText(canvas, shaper, isRtl, label, grandLabelPaint,
                    isRtl ? tableRight : tableLeft, y + 11f,
                    isRtl ? RtlAlign.Right : RtlAlign.Left);
                TextDraw.DrawText(canvas, shaper, isRtl, value, grandValuePaint,
                    isRtl ? tableLeft : tableRight, y + 11f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                y += 11f + 4.5f; // 6px padding-bottom
            }
            else
            {
                EnsureSpace(22f);
                TextDraw.DrawText(canvas, shaper, isRtl, label, totalsLabelPaint,
                    isRtl ? tableRight : tableLeft, y + 9.5f,
                    isRtl ? RtlAlign.Right : RtlAlign.Left);
                TextDraw.DrawText(canvas, shaper, isRtl, value, totalsValuePaint,
                    isRtl ? tableLeft : tableRight, y + 9.5f,
                    isRtl ? RtlAlign.Left : RtlAlign.Right);
                y += 9.5f + 9f;
            }
        }

        document.EndPage();
        canvas.Dispose();
        document.Close();
    }

    private static bool IsExpense(SalesExportRow row) =>
        string.Equals(row.Type, "expense", StringComparison.OrdinalIgnoreCase);

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

    private static string FormatAmount(int piastres) =>
        (piastres / 100.0).ToString("F2", CultureInfo.InvariantCulture);
}