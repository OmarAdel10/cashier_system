using System.Drawing;
using System.Drawing.Printing;
using BarcodeLib;
using PrintServer.Models;

namespace PrintServer.Services;

public sealed class PrinterService
{
    public List<string> GetInstalledPrinters()
    {
        var printers = new List<string>();
        foreach (string printer in PrinterSettings.InstalledPrinters)
        {
            printers.Add(printer);
        }
        return printers;
    }

    public bool PrintReceipt(ReceiptRequest request, string? pngPath)
    {
        try
        {
            var printerName = ResolvePrinterName(request.PrinterName);
            if (printerName == null) return false;

            var printDoc = new PrintDocument
            {
                PrinterSettings = new PrinterSettings { PrinterName = printerName },
                DocumentName = $"Receipt_{DateTime.Now:yyyyMMddHHmmss}",
            };

            printDoc.PrintPage += (sender, e) =>
            {
                var y = 10f;
                var leftMargin = 10f;

                using var boldFont = new Font("Consolas", 12, FontStyle.Bold);
                using var normalFont = new Font("Consolas", 10);
                using var smallFont = new Font("Consolas", 8);

                e.Graphics!.DrawString(request.StoreName, boldFont, Brushes.Black, leftMargin, y);
                y += 22;

                if (!string.IsNullOrWhiteSpace(request.StoreAddress))
                {
                    e.Graphics!.DrawString(request.StoreAddress, smallFont, Brushes.Gray, leftMargin, y);
                    y += 16;
                }

                if (!string.IsNullOrWhiteSpace(request.StorePhone))
                {
                    e.Graphics!.DrawString($"Tel: {request.StorePhone}", smallFont, Brushes.Gray, leftMargin, y);
                    y += 16;
                }

                y += 10;

                foreach (var item in request.Items)
                {
                    var line = $"{item.Name} x{item.Quantity}  {(item.UnitPricePiastres * item.Quantity / 100.0):F2}";
                    e.Graphics!.DrawString(line, normalFont, Brushes.Black, leftMargin, y);
                    y += 20;
                }

                y += 10;

                var showSubtotal = request.TaxPiastres > 0 || request.DiscountPiastres > 0;
                var showTax = request.TaxPiastres > 0;
                var showDiscount = request.DiscountPiastres > 0;

                if (showSubtotal)
                {
                    e.Graphics!.DrawString($"Subtotal: {request.SubtotalPiastres / 100.0:F2}",
                        normalFont, Brushes.Black, leftMargin, y);
                    y += 20;
                }
                if (showTax)
                {
                    e.Graphics!.DrawString($"Tax ({request.TaxPercent}%): {request.TaxPiastres / 100.0:F2}",
                        normalFont, Brushes.Black, leftMargin, y);
                    y += 20;
                }
                if (showDiscount)
                {
                    e.Graphics!.DrawString($"Discount: -{request.DiscountPiastres / 100.0:F2}",
                        normalFont, Brushes.Black, leftMargin, y);
                    y += 20;
                }

                var totalLabel = showSubtotal ? "Grand Total" : "Total";
                e.Graphics!.DrawString($"{totalLabel}: {request.TotalPiastres / 100.0:F2}",
                    boldFont, Brushes.Black, leftMargin, y);
                y += 26;

                if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
                {
                    e.Graphics!.DrawString(request.ReceiptFootnote, smallFont, Brushes.Gray, leftMargin, y);
                }
            };

            printDoc.Print();
            return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintReceipt failed: {ex.Message}");
            return false;
        }
    }

    public async Task<bool> PrintBarcodeAsync(BarcodeRequest request)
    {
        return await Task.Run(() =>
        {
            try
            {
                var printerName = ResolvePrinterName(request.PrinterName);
                if (printerName == null) return false;

                using var barcodeBitmap = GenerateBarcodeImage(request.BarcodeData);

                var printDoc = new PrintDocument
                {
                    PrinterSettings = new PrinterSettings { PrinterName = printerName },
                    DocumentName = $"Barcode_{request.BarcodeData}",
                };

                printDoc.PrintPage += (sender, e) =>
                {
                    var y = 10f;
                    var leftMargin = 10f;

                    var barcodeWidth = Math.Min(barcodeBitmap.Width, e.PageBounds.Width - 20);
                    var barcodeHeight = (int)((float)barcodeBitmap.Height * barcodeWidth / barcodeBitmap.Width);
                    e.Graphics!.DrawImage(barcodeBitmap, leftMargin, y, barcodeWidth, barcodeHeight);
                    y += barcodeHeight + 6;

                    using var smallFont = new Font("Consolas", 10);
                    e.Graphics!.DrawString(request.BarcodeData, smallFont, Brushes.Gray, leftMargin, y);
                    y += 16;

                    if (!string.IsNullOrWhiteSpace(request.ProductName))
                    {
                        e.Graphics!.DrawString(request.ProductName, smallFont, Brushes.Black, leftMargin, y);
                        y += 16;
                    }
                    if (request.PricePiastres > 0)
                    {
                        e.Graphics!.DrawString($"Price: {request.PricePiastres / 100.0:F2}",
                            smallFont, Brushes.Black, leftMargin, y);
                    }
                };

                printDoc.Print();
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintBarcode failed: {ex.Message}");
                return false;
            }
        });
    }

    private static Image GenerateBarcodeImage(string barcodeData)
    {
        var b = new BarcodeLib.Barcode
        {
            IncludeLabel = false,
            Alignment = BarcodeLib.AlignmentPositions.CENTER,
            Width = 300,
            Height = 80,
        };
        return b.Encode(BarcodeLib.TYPE.CODE128, barcodeData);
    }

    private static string? ResolvePrinterName(string? preferred)
    {
        if (!string.IsNullOrWhiteSpace(preferred))
        {
            foreach (string printer in PrinterSettings.InstalledPrinters)
            {
                if (printer.Equals(preferred, StringComparison.OrdinalIgnoreCase))
                    return printer;
            }
        }

        if (PrinterSettings.InstalledPrinters.Count == 0)
            return null;

        return PrinterSettings.InstalledPrinters
            .Cast<string>()
            .FirstOrDefault();
    }
}
