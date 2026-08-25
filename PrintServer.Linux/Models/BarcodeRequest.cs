using System.ComponentModel.DataAnnotations;

namespace PrintServer.Linux.Models;

public sealed class BarcodeRequest
{
    [StringLength(80, ErrorMessage = "BarcodeData must be at most 80 characters")]
    [RegularExpression(@"^[\x20-\x7E]*$", ErrorMessage = "BarcodeData must only contain printable ASCII characters")]
    public string BarcodeData { get; set; } = string.Empty;
    public string? PrinterName { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public int PricePiastres { get; set; }
    public string StoreName { get; set; } = string.Empty;
    public bool IsRtl { get; set; }
}
