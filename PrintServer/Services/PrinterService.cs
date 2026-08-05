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

            using var printDoc = new PrintDocument
            {
                PrinterSettings = new PrinterSettings { PrinterName = printerName },
                DocumentName = $"Receipt_{DateTime.Now:yyyyMMddHHmmss}",
            };

            printDoc.PrintPage += (sender, e) =>
            {
                const float margin = 10f;
                var pageWidth = e.PageBounds.Width;
                var usableWidth = pageWidth - 2 * margin;
                var col1X = margin;
                var col2X = pageWidth / 2f;
                var col3X = pageWidth - margin;

                var y = margin;

                using var bold12 = new Font("Consolas", 12, FontStyle.Bold);
                using var bold11 = new Font("Consolas", 11, FontStyle.Bold);
                using var normal10 = new Font("Consolas", 10);
                using var small9 = new Font("Consolas", 9);
                using var grayBrush = new SolidBrush(Color.DimGray);
                using var darkGray = new SolidBrush(Color.FromArgb(80, 80, 80));
                using var dashPen = new Pen(Color.Gray, 1) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dash };

                var g = e.Graphics!;

                // ---- Header: "Welcome to {StoreName}" (centered) ----
                using var centerFmt = new StringFormat { Alignment = StringAlignment.Center };
                var headerText = $"Welcome to {request.StoreName}";
                g.DrawString(headerText, bold12, Brushes.Black, pageWidth / 2f, y, centerFmt);
                y += 26;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Metadata ----
                if (!string.IsNullOrWhiteSpace(request.OrderNumber))
                {
                    g.DrawString($"ORD: {request.OrderNumber}", normal10, grayBrush, col1X, y);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.StoreAddress))
                {
                    g.DrawString($"Address: {request.StoreAddress}", normal10, grayBrush, col1X, y);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.StorePhone))
                {
                    g.DrawString($"Tel: {request.StorePhone}", normal10, grayBrush, col1X, y);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.UserName))
                {
                    var timeStr = ParseShiftTime(request.ShiftStartedAt);
                    var shiftText = string.IsNullOrWhiteSpace(timeStr)
                        ? $"Shift: {request.UserName}"
                        : $"Shift: {request.UserName} {timeStr}";
                    g.DrawString(shiftText, normal10, grayBrush, col1X, y);
                    y += 20;
                }
                g.DrawString($"Date: {request.CreatedAt:yyyy-MM-dd HH:mm}", normal10, grayBrush, col1X, y);
                y += 20;

                if (!string.IsNullOrWhiteSpace(request.PaymentType))
                {
                    g.DrawString($"Payment Type: {request.PaymentType}", normal10, grayBrush, col1X, y);
                    y += 20;
                }

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Table headers ----
                using var rightFmt = new StringFormat { Alignment = StringAlignment.Far };
                using var centerFmt2 = new StringFormat { Alignment = StringAlignment.Center };
                g.DrawString("Item Description", bold11, Brushes.Black, col1X, y);
                g.DrawString("Price", bold11, Brushes.Black, col2X, y, centerFmt2);
                g.DrawString("Total", bold11, Brushes.Black, col3X, y, rightFmt);
                y += 20;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Items ----
                foreach (var item in request.Items)
                {
                    var desc = $"{item.Name} x{item.Quantity}";
                    var unitPrice = $"{(item.UnitPricePiastres / 100.0):F2}";
                    var totalPrice = $"{(item.TotalPiastres / 100.0):F2}";

                    g.DrawString(desc, normal10, Brushes.Black, col1X, y);
                    g.DrawString(unitPrice, normal10, Brushes.Black, col2X, y, centerFmt2);
                    g.DrawString(totalPrice, normal10, Brushes.Black, col3X, y, rightFmt);
                    y += 22;

                    g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                    y += 12;
                }

                // ---- Calculations ----
                var hasTax = request.TaxPiastres > 0;
                var hasDiscount = request.DiscountPiastres > 0;
                var showSubtotal = hasTax || hasDiscount;

                if (showSubtotal)
                {
                    g.DrawString("Subtotal", normal10, Brushes.Black, col1X, y);
                    g.DrawString($"{(request.SubtotalPiastres / 100.0):F2}", normal10, Brushes.Black, col3X, y, rightFmt);
                    y += 22;
                }
                if (hasTax)
                {
                    g.DrawString($"Tax ({request.TaxPercent}%)", normal10, Brushes.Black, col1X, y);
                    g.DrawString($"{(request.TaxPiastres / 100.0):F2}", normal10, Brushes.Black, col3X, y, rightFmt);
                    y += 22;
                }
                if (hasDiscount)
                {
                    g.DrawString($"Discount ({request.DiscountPercent}%)", normal10, Brushes.Black, col1X, y);
                    g.DrawString($"-{(request.DiscountPiastres / 100.0):F2}", normal10, Brushes.Black, col3X, y, rightFmt);
                    y += 22;
                }

                // ---- Total ----
                g.DrawString("Total", bold12, Brushes.Black, col1X, y);
                g.DrawString($"{(request.TotalPiastres / 100.0):F2}", bold12, Brushes.Black, col3X, y, rightFmt);
                y += 28;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Footer ----
                if (!string.IsNullOrWhiteSpace(request.ReceiptFootnote))
                {
                    g.DrawString(request.ReceiptFootnote, small9, grayBrush, pageWidth / 2f, y, centerFmt);
                    y += 22;
                }

                // UUID
                if (!string.IsNullOrWhiteSpace(request.ReceiptUuid))
                {
                    g.DrawString($"Receipt UUID: {request.ReceiptUuid}", small9, darkGray, col1X, y);
                }
            };

            printDoc.Print();
            return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintReceipt failed: {ex}");
            return false;
        }
    }

    private static string ParseShiftTime(string? isoValue)
    {
        if (string.IsNullOrWhiteSpace(isoValue))
            return "";
        if (DateTime.TryParse(isoValue, System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out var dt))
            return dt.ToString("h:mm tt", System.Globalization.CultureInfo.InvariantCulture);
        return "";
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
