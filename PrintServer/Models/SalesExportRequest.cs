using System.Text.Json.Serialization;

namespace PrintServer.Models;

/// <summary>
/// Payload for the stacked sales-export PDF (sales_export_template.html):
/// one row per transaction (receipt or expense) with nested line items.
/// The server derives the summary stats and the totals block from the rows,
/// so the app only sends the raw transaction data plus header info.
/// </summary>
public sealed class SalesExportRequest
{
    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("period_start")]
    public string PeriodStart { get; set; } = string.Empty;

    [JsonPropertyName("period_end")]
    public string PeriodEnd { get; set; } = string.Empty;

    [JsonPropertyName("store_name")]
    public string StoreName { get; set; } = string.Empty;

    [JsonPropertyName("store_address")]
    public string StoreAddress { get; set; } = string.Empty;

    [JsonPropertyName("store_phone")]
    public string StorePhone { get; set; } = string.Empty;

    [JsonPropertyName("logo_svg_data")]
    public string? LogoSvgData { get; set; }

    [JsonPropertyName("is_rtl")]
    public bool IsRtl { get; set; }

    [JsonPropertyName("outputDirectory")]
    public string? OutputDirectory { get; set; }

    [JsonPropertyName("rows")]
    public List<SalesExportRow> Rows { get; set; } = [];
}

public sealed class SalesExportRow
{
    /// <summary>Transaction kind: <c>sale</c> or <c>expense</c>.</summary>
    [JsonPropertyName("type")]
    public string Type { get; set; } = "sale";

    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("date")]
    public string Date { get; set; } = string.Empty;

    [JsonPropertyName("cashier")]
    public string Cashier { get; set; } = string.Empty;

    [JsonPropertyName("discount_percent")]
    public int DiscountPercent { get; set; }

    [JsonPropertyName("tax_percent")]
    public int TaxPercent { get; set; }

    [JsonPropertyName("discount_piastres")]
    public int DiscountPiastres { get; set; }

    [JsonPropertyName("tax_piastres")]
    public int TaxPiastres { get; set; }

    /// <summary>Transaction subtotal (sum of the line amounts).</summary>
    [JsonPropertyName("amount_piastres")]
    public int AmountPiastres { get; set; }

    [JsonPropertyName("total_piastres")]
    public int TotalPiastres { get; set; }

    [JsonPropertyName("items")]
    public List<SalesExportItem> Items { get; set; } = [];
}

public sealed class SalesExportItem
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }

    [JsonPropertyName("price_piastres")]
    public int PricePiastres { get; set; }
}