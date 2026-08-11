namespace PrintServer.Localization;

/// <summary>
/// AR/EN receipt strings used by both the System.Drawing printer path and
/// the Skia PNG export path. Mirrors the app-side LocalizationService keys
/// (sales.* / checkout.* / paymentType.*) so printed receipts match the
/// in-app receipt tower language. Selected via <c>is_rtl</c> sent from the
/// Flutter app (derived from settings.languageCode == "ar").
/// </summary>
public static class ReceiptLabels
{
    public const string Welcome = "Welcome";
    public const string OrderNumber = "OrderNumber";
    public const string Address = "Address";
    public const string Phone = "Phone";
    public const string Shift = "Shift";
    public const string Date = "Date";
    public const string PaymentTypeLabel = "PaymentTypeLabel";
    public const string ItemDescription = "ItemDescription";
    public const string Price = "Price";
    public const string Total = "Total";
    public const string Subtotal = "Subtotal";
    public const string Tax = "Tax";
    public const string Discount = "Discount";
    public const string ReceiptUuid = "ReceiptUuid";

    private static readonly IReadOnlyDictionary<string, string> En = new Dictionary<string, string>
    {
        [Welcome] = "Welcome to {0}",
        [OrderNumber] = "ORD: {0}",
        [Address] = "Address: {0}",
        [Phone] = "Tel: {0}",
        [Shift] = "Shift: {0}",
        [Date] = "Date: {0}",
        [PaymentTypeLabel] = "Payment Type: {0}",
        [ItemDescription] = "Item Description",
        [Price] = "Price",
        [Total] = "Total",
        [Subtotal] = "Subtotal",
        [Tax] = "Tax ({0}%)",
        [Discount] = "Discount ({0}%)",
        [ReceiptUuid] = "Receipt UUID: {0}",
    };

    private static readonly IReadOnlyDictionary<string, string> Ar = new Dictionary<string, string>
    {
        [Welcome] = "أهلاً بك في {0}",
        [OrderNumber] = "رقم الطلب: {0}",
        [Address] = "العنوان: {0}",
        [Phone] = "تليفون: {0}",
        [Shift] = "شيفت: {0}",
        [Date] = "التاريخ: {0}",
        [PaymentTypeLabel] = "طريقة الدفع: {0}",
        [ItemDescription] = "الصنف",
        [Price] = "السعر",
        [Total] = "الإجمالي",
        [Subtotal] = "المجموع الفرعي",
        [Tax] = "الضريبة ({0}%)",
        [Discount] = "الخصم ({0}%)",
        [ReceiptUuid] = "رقم الفاتورة: {0}",
    };

    private static readonly IReadOnlyDictionary<string, (string En, string Ar)> PaymentTypes =
        new Dictionary<string, (string En, string Ar)>
        {
            ["cash"] = ("Cash", "نقدي"),
            ["instapay"] = ("InstaPay", "إنستاباي"),
            ["vodafoneCash"] = ("Vodafone Cash", "فودافون كاش"),
            ["visa"] = ("Visa", "فيزا"),
        };

    public static string Get(string key, bool isRtl) => isRtl ? Ar[key] : En[key];

    public static string Format(string key, bool isRtl, params object[] args) =>
        string.Format(Get(key, isRtl), args);

    /// <summary>
    /// Maps the raw payment type id sent by the app (cash / instapay /
    /// vodafoneCash / visa) to the localized display string. Unknown ids
    /// fall back to the raw id so the receipt never prints an empty value.
    /// </summary>
    public static string PaymentType(string typeId, bool isRtl)
    {
        if (PaymentTypes.TryGetValue(typeId, out var localized))
            return isRtl ? localized.Ar : localized.En;
        return typeId;
    }
}