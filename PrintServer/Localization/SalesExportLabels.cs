namespace PrintServer.Localization;

/// <summary>
/// AR/EN strings for the stacked sales-export PDF. Selected via the
/// request's <c>is_rtl</c> flag (derived from settings.languageCode == "ar"),
/// mirroring <see cref="ReceiptLabels"/> for the invoice path.
/// </summary>
public static class SalesExportLabels
{
    public const string SalesReportTitle = "SalesReportTitle";
    public const string ReportPeriod = "ReportPeriod";
    public const string TypeLabel = "TypeLabel";
    public const string ReceiptId = "ReceiptId";
    public const string DateLabel = "DateLabel";
    public const string ItemsQty = "ItemsQty";
    public const string ItemsLabel = "ItemsLabel";
    public const string Cashier = "Cashier";
    public const string DiscountLabel = "DiscountLabel";
    public const string TaxLabel = "TaxLabel";
    public const string Amount = "Amount";
    public const string Total = "Total";
    public const string TotalTransactions = "TotalTransactions";
    public const string TotalReceipts = "TotalReceipts";
    public const string TotalExpenses = "TotalExpenses";
    public const string AvgTransaction = "AvgTransaction";
    public const string Subtotal = "Subtotal";
    public const string Discount = "Discount";
    public const string GrandTotal = "GrandTotal";
    public const string ReceiptBadge = "ReceiptBadge";
    public const string ExpenseBadge = "ExpenseBadge";

    private static readonly IReadOnlyDictionary<string, string> En = new Dictionary<string, string>
    {
        [SalesReportTitle] = "Sales Export",
        [ReportPeriod] = "Report period: {0} - {1}",
        [TypeLabel] = "Type",
        [ReceiptId] = "Receipt ID",
        [DateLabel] = "Date",
        [ItemsQty] = "Items Qty",
        [ItemsLabel] = "Items",
        [Cashier] = "Cashier",
        [DiscountLabel] = "Discount",
        [TaxLabel] = "Tax",
        [Amount] = "Amount",
        [Total] = "Total",
        [TotalTransactions] = "Total transactions",
        [TotalReceipts] = "Total receipts",
        [TotalExpenses] = "Total expenses",
        [AvgTransaction] = "Avg transaction value",
        [Subtotal] = "Subtotal",
        [Discount] = "Discount",
        [GrandTotal] = "Grand Total",
        [ReceiptBadge] = "Receipt",
        [ExpenseBadge] = "Expense",
    };

    private static readonly IReadOnlyDictionary<string, string> Ar = new Dictionary<string, string>
    {
        [SalesReportTitle] = "تصدير المبيعات",
        [ReportPeriod] = "فترة التقرير: {0} - {1}",
        [TypeLabel] = "النوع",
        [ReceiptId] = "رقم الفاتورة",
        [DateLabel] = "التاريخ",
        [ItemsQty] = "عدد الأصناف",
        [ItemsLabel] = "الأصناف",
        [Cashier] = "الكاشير",
        [DiscountLabel] = "الخصم",
        [TaxLabel] = "الضريبة",
        [Amount] = "المبلغ",
        [Total] = "الإجمالي",
        [TotalTransactions] = "إجمالي العمليات",
        [TotalReceipts] = "إجمالي الفواتير",
        [TotalExpenses] = "إجمالي المصروفات",
        [AvgTransaction] = "متوسط قيمة العملية",
        [Subtotal] = "المجموع الفرعي",
        [Discount] = "الخصم",
        [GrandTotal] = "الإجمالي الكلي",
        [ReceiptBadge] = "فاتورة",
        [ExpenseBadge] = "مصروف",
    };

    public static string Get(string key, bool isRtl) => isRtl ? Ar[key] : En[key];

    public static string Format(string key, bool isRtl, params object[] args) =>
        string.Format(Get(key, isRtl), args);

    /// <summary>Returns the label part of a "{0}" template (everything before
    /// the format hole, whitespace and trailing separators trimmed) so callers
    /// can draw label and value separately — required for RTL so digit/Latin
    /// values (dates) are not reshaped together with the Arabic label.</summary>
    public static string Label(string key, bool isRtl)
    {
        var s = Get(key, isRtl);
        var i = s.IndexOf("{0}", StringComparison.Ordinal);
        if (i >= 0) s = s[..i];
        return s.TrimEnd(' ', ':', '-');
    }
}