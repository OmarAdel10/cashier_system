using PrintServer.Linux.Models;
using PrintServer.Linux.Services;
using Xunit;

namespace PrintServer.Linux.Tests;

public sealed class CupsPrinterServiceTests
{
    [Theory]
    [InlineData(100f, 30f, RtlAlign.Right, 70f)]
    [InlineData(100f, 30f, RtlAlign.Center, 85f)]
    [InlineData(100f, 30f, RtlAlign.Left, 100f)]
    public void FromWidth_OffsetsByWidthAndAlignment(float x, float w, RtlAlign align, float expected)
    {
        Assert.Equal(expected, TextDraw.FromWidth(x, w, align));
    }

    [Theory]
    [InlineData("مرحبا", true)]
    [InlineData("hello", false)]
    [InlineData("", false)]
    [InlineData("Coffee قهوة", true)]
    [InlineData("\u06FF", true)]
    [InlineData("\u0750", true)]
    [InlineData("\u08A0", true)]
    [InlineData("\uFB50", true)]
    [InlineData("\uFE70", true)]
    [InlineData("\u0590", false)]
    public void ContainsArabic_DetectsArabicUnicodeRanges(string text, bool expected)
    {
        Assert.Equal(expected, TextDraw.ContainsArabic(text));
    }

    [Fact]
    public void MeasureVisual_LtrText_UsesRawMeasure()
    {
        using var typeface = SkiaSharp.SKTypeface.FromFamilyName("DejaVu Sans");
        using var paint = new SkiaSharp.SKPaint { Typeface = typeface, TextSize = 12, IsAntialias = true };

        var measured = TextDraw.MeasureVisual("Hello", paint, isRtl: false);

        Assert.Equal(paint.MeasureText("Hello"), measured);
        Assert.True(measured > 0);
    }

    [Fact]
    public void MeasureVisual_LatinUnderRtlFlag_UsesRawMeasure()
    {
        using var typeface = SkiaSharp.SKTypeface.FromFamilyName("DejaVu Sans");
        using var paint = new SkiaSharp.SKPaint { Typeface = typeface, TextSize = 12, IsAntialias = true };

        var measured = TextDraw.MeasureVisual("Hello", paint, isRtl: true);

        Assert.Equal(paint.MeasureText("Hello"), measured);
    }

    [Fact]
    public void GetInstalledPrinters_ReturnsCupsDestNames()
    {
        var mock = new Mocks.MockCupsClient();
        mock.Printers.Add("ThermalReceipt");
        mock.Printers.Add("KitchenPrinter");
        var service = new CupsPrinterService(mock);

        var printers = service.GetInstalledPrinters();

        Assert.Equal(new[] { "ThermalReceipt", "KitchenPrinter" }, printers);
    }

    [Fact]
    public void GetDefaultPrinter_ReturnsCupsDefault()
    {
        var mock = new Mocks.MockCupsClient { DefaultPrinter = "ThermalReceipt" };
        var service = new CupsPrinterService(mock);

        Assert.Equal("ThermalReceipt", service.GetDefaultPrinter());
    }

    [Fact]
    public void GetDefaultPrinter_NoDefault_ReturnsNull()
    {
        var service = new CupsPrinterService(new Mocks.MockCupsClient());

        Assert.Null(service.GetDefaultPrinter());
    }

    [Fact]
    public void ResolvePrinterName_PrefersExactRequestedMatch()
    {
        var mock = new Mocks.MockCupsClient { DefaultPrinter = "Other" };
        mock.Printers.Add("ThermalReceipt");
        mock.Printers.Add("Other");
        var service = new CupsPrinterService(mock);

        var resolved = service.ResolvePrinterName("thermalreceipt");

        Assert.Equal("ThermalReceipt", resolved);
    }

    [Fact]
    public void ResolvePrinterName_UnknownPreferred_FallsBackToCupsDefault()
    {
        var mock = new Mocks.MockCupsClient { DefaultPrinter = "ThermalReceipt" };
        mock.Printers.Add("ThermalReceipt");
        var service = new CupsPrinterService(mock);

        var resolved = service.ResolvePrinterName("GhostPrinter");

        Assert.Equal("ThermalReceipt", resolved);
    }

    [Fact]
    public void PrintReceipt_NoPrinters_ReturnsFalseWithoutPrinting()
    {
        var mock = new Mocks.MockCupsClient();
        var service = new CupsPrinterService(mock);
        var request = new ReceiptRequest
        {
            StoreName = "Test",
            Items = [],
            CreatedAt = DateTime.Now,
        };

        var printed = service.PrintReceipt(request);

        Assert.False(printed);
        Assert.Empty(mock.PrintCalls);
    }

    [Fact]
    public void PrintTicket_NoPrinters_ReturnsFalseWithoutPrinting()
    {
        var mock = new Mocks.MockCupsClient();
        var service = new CupsPrinterService(mock);
        var request = new TicketRequest
        {
            StoreName = "Test",
            Items = [new TicketItem { Name = "Burger", Quantity = 1 }],
        };

        var printed = service.PrintTicket(request);

        Assert.False(printed);
        Assert.Empty(mock.PrintCalls);
    }
}
