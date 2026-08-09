using System.Text.Json.Serialization;

namespace PrintServer.Models;

public sealed class TicketRequest
{
    [JsonPropertyName("printer_name")]
    public string? PrinterName { get; set; }

    [JsonPropertyName("store_name")]
    public string StoreName { get; set; } = string.Empty;

    [JsonPropertyName("store_address")]
    public string StoreAddress { get; set; } = string.Empty;

    [JsonPropertyName("store_phone")]
    public string StorePhone { get; set; } = string.Empty;

    [JsonPropertyName("is_rtl")]
    public bool IsRtl { get; set; }

    [JsonPropertyName("table_name")]
    public string TableName { get; set; } = string.Empty;

    [JsonPropertyName("zone_name")]
    public string ZoneName { get; set; } = string.Empty;

    [JsonPropertyName("round_number")]
    public int RoundNumber { get; set; }

    [JsonPropertyName("order_number")]
    public string OrderNumber { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("created_at")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("items")]
    public List<TicketItem> Items { get; set; } = [];
}

public sealed class TicketItem
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }
}