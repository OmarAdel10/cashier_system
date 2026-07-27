namespace PrintServer.Models;

public sealed class ReceiptRequest
{
    public List<ReceiptItem> Items { get; set; } = [];
    public int SubtotalPiastres { get; set; }
    public int DiscountPiastres { get; set; }
    public int TaxPiastres { get; set; }
    public int TotalPiastres { get; set; }
    public int TaxPercent { get; set; }
    public bool IsRtl { get; set; }
    public bool SaveAsPng { get; set; }
    public bool SkipPrint { get; set; }
    public string? OutputDirectory { get; set; }
    public string? PrinterName { get; set; }
    public string StoreName { get; set; } = string.Empty;
    public string StoreAddress { get; set; } = string.Empty;
    public string StorePhone { get; set; } = string.Empty;
    public string? LogoSvg { get; set; }
    public string? LogoSvgData { get; set; }
    public string ReceiptFootnote { get; set; } = string.Empty;
}

public sealed class ReceiptItem
{
    public string Name { get; set; } = string.Empty;
    public string Barcode { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public int UnitPricePiastres { get; set; }
}
