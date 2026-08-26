using System.Text.Json.Serialization;

namespace PrintServer.Linux.Models;

public sealed class ReceiptRequest
{
    [JsonPropertyName("items")]
    public List<ReceiptItem> Items { get; set; } = [];

    [JsonPropertyName("subtotal_piastres")]
    public int SubtotalPiastres { get; set; }

    [JsonPropertyName("discount_piastres")]
    public int DiscountPiastres { get; set; }

    [JsonPropertyName("tax_piastres")]
    public int TaxPiastres { get; set; }

    [JsonPropertyName("total_piastres")]
    public int TotalPiastres { get; set; }

    [JsonPropertyName("tax_percent")]
    public int TaxPercent { get; set; }

    [JsonPropertyName("discount_percent")]
    public int DiscountPercent { get; set; }

    [JsonPropertyName("is_rtl")]
    public bool IsRtl { get; set; }

    [JsonPropertyName("save_as_png")]
    public bool SaveAsPng { get; set; }

    [JsonPropertyName("skip_print")]
    public bool SkipPrint { get; set; }

    [JsonPropertyName("outputDirectory")]
    public string? OutputDirectory { get; set; }

    [JsonPropertyName("printer_name")]
    public string? PrinterName { get; set; }

    [JsonPropertyName("print_to_file")]
    public bool PrintToFile { get; set; }

    [JsonPropertyName("print_file_name")]
    public string? PrintFileName { get; set; }

    [JsonPropertyName("store_name")]
    public string StoreName { get; set; } = string.Empty;

    [JsonPropertyName("store_address")]
    public string StoreAddress { get; set; } = string.Empty;

    [JsonPropertyName("store_phone")]
    public string StorePhone { get; set; } = string.Empty;

    [JsonPropertyName("logo_svg_data")]
    public string? LogoSvgData { get; set; }

    [JsonPropertyName("footnote")]
    public string ReceiptFootnote { get; set; } = string.Empty;

    [JsonPropertyName("order_number")]
    public string OrderNumber { get; set; } = string.Empty;

    [JsonPropertyName("username")]
    public string UserName { get; set; } = string.Empty;

    [JsonPropertyName("created_at")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("id")]
    public string ReceiptUuid { get; set; } = string.Empty;

    [JsonPropertyName("shift_started_at")]
    public string ShiftStartedAt { get; set; } = string.Empty;

    [JsonPropertyName("payment_type")]
    public string? PaymentType { get; set; }
}

public sealed class ReceiptItem
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("barcode")]
    public string Barcode { get; set; } = string.Empty;

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }

    [JsonPropertyName("unit_price_piastres")]
    public int UnitPricePiastres { get; set; }

    [JsonPropertyName("total_piastres")]
    public int TotalPiastres { get; set; }
}
