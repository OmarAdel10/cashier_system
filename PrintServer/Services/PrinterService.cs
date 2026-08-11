using System.Drawing;
using System.Drawing.Printing;
using BarcodeLib;
using PrintServer.Localization;
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

                var isRtl = request.IsRtl;

                // Arabic receipts: Arial (full Arabic glyphs on Windows) with
                // GDI+ shaping; layout mirrors columns so labels sit on the
                // right and amounts on the left.
                var fontFamily = isRtl ? "Arial" : "Consolas";

                var y = margin;

                using var bold12 = new Font(fontFamily, 12, FontStyle.Bold);
                using var bold11 = new Font(fontFamily, 11, FontStyle.Bold);
                using var normal10 = new Font(fontFamily, 10);
                using var small9 = new Font(fontFamily, 9);
                using var grayBrush = new SolidBrush(Color.DimGray);
                using var darkGray = new SolidBrush(Color.FromArgb(80, 80, 80));
                using var dashPen = new Pen(Color.Gray, 1) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dash };

                var g = e.Graphics!;

                // ---- Header: "Welcome to {StoreName}" (centered) ----
                using var centerFmt = new StringFormat { Alignment = StringAlignment.Center };
                var headerText = ReceiptLabels.Format(ReceiptLabels.Welcome, isRtl, request.StoreName);
                g.DrawString(headerText, bold12, Brushes.Black, pageWidth / 2f, y, centerFmt);
                y += 26;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // RTL text anchors right edge; LTR anchors left edge.
                var labelX = isRtl ? col3X : col1X;
                var labelFmt = isRtl
                    ? new StringFormat { Alignment = StringAlignment.Far }
                    : new StringFormat { Alignment = StringAlignment.Near };

                // ---- Metadata ----
                if (!string.IsNullOrWhiteSpace(request.OrderNumber))
                {
                    var ordText = ReceiptLabels.Format(ReceiptLabels.OrderNumber, isRtl, request.OrderNumber);
                    g.DrawString(ordText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.StoreAddress))
                {
                    var addressText = ReceiptLabels.Format(ReceiptLabels.Address, isRtl, request.StoreAddress);
                    g.DrawString(addressText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.StorePhone))
                {
                    var phoneText = ReceiptLabels.Format(ReceiptLabels.Phone, isRtl, request.StorePhone);
                    g.DrawString(phoneText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.UserName))
                {
                    var timeStr = ParseShiftTime(request.ShiftStartedAt);
                    var shiftText = string.IsNullOrWhiteSpace(timeStr)
                        ? ReceiptLabels.Format(ReceiptLabels.Shift, isRtl, request.UserName)
                        : ReceiptLabels.Format(ReceiptLabels.Shift, isRtl, $"{request.UserName} {timeStr}");
                    g.DrawString(shiftText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }
                var dateText = ReceiptLabels.Format(ReceiptLabels.Date, isRtl,
                    request.CreatedAt.ToString("yyyy-MM-dd HH:mm"));
                g.DrawString(dateText, normal10, grayBrush, labelX, y, labelFmt);
                y += 20;

                if (!string.IsNullOrWhiteSpace(request.PaymentType))
                {
                    var paymentText = ReceiptLabels.Format(ReceiptLabels.PaymentTypeLabel, isRtl,
                        ReceiptLabels.PaymentType(request.PaymentType, isRtl));
                    g.DrawString(paymentText, normal10, grayBrush, labelX, y, labelFmt);
                    y += 20;
                }

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Table headers (mirrored for RTL) ----
                using var rightFmt = new StringFormat { Alignment = StringAlignment.Far };
                using var centerFmt2 = new StringFormat { Alignment = StringAlignment.Center };
                using var leftFmt = new StringFormat { Alignment = StringAlignment.Near };
                var itemDescHeader = ReceiptLabels.Get(ReceiptLabels.ItemDescription, isRtl);
                var priceHeader = ReceiptLabels.Get(ReceiptLabels.Price, isRtl);
                var totalHeader = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);
                g.DrawString(itemDescHeader, bold11, Brushes.Black, isRtl ? col3X : col1X, y,
                    isRtl ? rightFmt : leftFmt);
                g.DrawString(priceHeader, bold11, Brushes.Black, col2X, y, centerFmt2);
                g.DrawString(totalHeader, bold11, Brushes.Black, isRtl ? col1X : col3X, y,
                    isRtl ? leftFmt : rightFmt);
                y += 20;

                // Dashed divider
                g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Items (mirrored for RTL) ----
                foreach (var item in request.Items)
                {
                    var desc = $"{item.Name} x{item.Quantity}";
                    var unitPrice = $"{(item.UnitPricePiastres / 100.0):F2}";
                    var totalPrice = $"{(item.TotalPiastres / 100.0):F2}";

                    g.DrawString(desc, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString(unitPrice, normal10, Brushes.Black, col2X, y, centerFmt2);
                    g.DrawString(totalPrice, normal10, Brushes.Black, isRtl ? col1X : col3X, y,
                        isRtl ? leftFmt : rightFmt);
                    y += 22;

                    g.DrawLine(dashPen, margin, y, pageWidth - margin, y);
                    y += 12;
                }

                // ---- Calculations (mirrored for RTL) ----
                var hasTax = request.TaxPiastres > 0;
                var hasDiscount = request.DiscountPiastres > 0;
                var showSubtotal = hasTax || hasDiscount;

                if (showSubtotal)
                {
                    var subtotalLabel = ReceiptLabels.Get(ReceiptLabels.Subtotal, isRtl);
                    g.DrawString(subtotalLabel, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString($"{(request.SubtotalPiastres / 100.0):F2}", normal10, Brushes.Black,
                        isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                    y += 22;
                }
                if (hasTax)
                {
                    var taxLabel = ReceiptLabels.Format(ReceiptLabels.Tax, isRtl, request.TaxPercent);
                    g.DrawString(taxLabel, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString($"{(request.TaxPiastres / 100.0):F2}", normal10, Brushes.Black,
                        isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                    y += 22;
                }
                if (hasDiscount)
                {
                    var discountLabel = ReceiptLabels.Format(ReceiptLabels.Discount, isRtl, request.DiscountPercent);
                    g.DrawString(discountLabel, normal10, Brushes.Black, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
                    g.DrawString($"-{(request.DiscountPiastres / 100.0):F2}", normal10, Brushes.Black,
                        isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
                    y += 22;
                }

                // ---- Total ----
                var totalLabel = ReceiptLabels.Get(ReceiptLabels.Total, isRtl);
                g.DrawString(totalLabel, bold12, Brushes.Black, isRtl ? col3X : col1X, y,
                    isRtl ? rightFmt : leftFmt);
                g.DrawString($"{(request.TotalPiastres / 100.0):F2}", bold12, Brushes.Black,
                    isRtl ? col1X : col3X, y, isRtl ? leftFmt : rightFmt);
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
                    var uuidText = ReceiptLabels.Format(ReceiptLabels.ReceiptUuid, isRtl, request.ReceiptUuid);
                    g.DrawString(uuidText, small9, darkGray, isRtl ? col3X : col1X, y,
                        isRtl ? rightFmt : leftFmt);
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

    public bool PrintTicket(TicketRequest request)
    {
        try
        {
            var printerName = ResolvePrinterName(request.PrinterName);
            if (printerName == null) return false;

            using var printDoc = new PrintDocument
            {
                PrinterSettings = new PrinterSettings { PrinterName = printerName },
                DocumentName = $"Ticket_{request.OrderNumber}",
            };

            printDoc.PrintPage += (sender, e) =>
            {
                const float margin = 10f;
                var pageWidth = e.PageBounds.Width;
                var usableWidth = pageWidth - 2 * margin;
                var centerX = pageWidth / 2f;

                var y = margin;

                using var bold16 = new Font("Consolas", 16, FontStyle.Bold);
                using var bold12 = new Font("Consolas", 12, FontStyle.Bold);
                using var bold10 = new Font("Consolas", 10, FontStyle.Bold);
                using var normal10 = new Font("Consolas", 10);
                using var grayBrush = new SolidBrush(Color.DimGray);
                using var dashedPen = new Pen(Color.Gray, 1) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dash };
                using var centerFmt = new StringFormat { Alignment = StringAlignment.Center };

                var g = e.Graphics!;

                // ---- Venue header ----
                if (!string.IsNullOrWhiteSpace(request.StoreName))
                {
                    g.DrawString(request.StoreName, bold16, Brushes.Black, centerX, y, centerFmt);
                    y += 30;
                }

                // ---- Station / category label ----
                if (!string.IsNullOrWhiteSpace(request.Category))
                {
                    g.DrawString(request.Category.ToUpperInvariant(), bold12, Brushes.Black, centerX, y, centerFmt);
                    y += 26;
                }

                // Dashed divider
                g.DrawLine(dashedPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Table + zone + round ----
                var location = string.IsNullOrWhiteSpace(request.ZoneName)
                    ? request.TableName
                    : $"{request.TableName} / {request.ZoneName}";
                g.DrawString(location, bold12, Brushes.Black, margin, y);
                y += 22;
                if (request.RoundNumber > 0)
                {
                    g.DrawString($"Round: {request.RoundNumber}", normal10, grayBrush, margin, y);
                    y += 20;
                }
                if (!string.IsNullOrWhiteSpace(request.OrderNumber))
                {
                    g.DrawString($"Order: {request.OrderNumber}", normal10, grayBrush, margin, y);
                    y += 20;
                }
                g.DrawString($"Fired: {request.CreatedAt:HH:mm}", normal10, grayBrush, margin, y);
                y += 20;

                // Dashed divider
                g.DrawLine(dashedPen, margin, y, pageWidth - margin, y);
                y += 12;

                // ---- Items: qty x name (no prices) ----
                foreach (var item in request.Items)
                {
                    g.DrawString($"{item.Quantity} x {item.Name}", bold10, Brushes.Black, margin, y);
                    y += 22;
                }
            };

            printDoc.Print();
            return true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[PrintServer] PrintTicket failed: {ex}");
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
