namespace PrintServer.Models;

public sealed class BarcodeRequest
{
    public string BarcodeData { get; set; } = string.Empty;
    public string? PrinterName { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public int PricePiastres { get; set; }
    public string StoreName { get; set; } = string.Empty;
    public bool IsRtl { get; set; }
}
