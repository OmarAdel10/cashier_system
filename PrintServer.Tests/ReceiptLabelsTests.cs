using PrintServer.Localization;
using Xunit;

namespace PrintServer.Tests;

/// <summary>
/// Tests for the AR/EN receipt label selection used by both the
/// System.Drawing printer path and the Skia PNG export path.
/// </summary>
public sealed class ReceiptLabelsTests
{
    [Fact]
    public void Get_IsRtlFalse_ReturnsEnglish()
    {
        Assert.Equal("Total", ReceiptLabels.Get(ReceiptLabels.Total, isRtl: false));
        Assert.Equal("Item Description", ReceiptLabels.Get(ReceiptLabels.ItemDescription, isRtl: false));
    }

    [Fact]
    public void Get_IsRtlTrue_ReturnsArabic()
    {
        Assert.Equal("الإجمالي", ReceiptLabels.Get(ReceiptLabels.Total, isRtl: true));
        Assert.Equal("الصنف", ReceiptLabels.Get(ReceiptLabels.ItemDescription, isRtl: true));
        Assert.Equal("طريقة الدفع: {0}", ReceiptLabels.Get(ReceiptLabels.PaymentTypeLabel, isRtl: true));
    }

    [Fact]
    public void Format_IsRtlFalse_InterpolatesEnglishArgs()
    {
        Assert.Equal("Welcome to My Store", ReceiptLabels.Format(ReceiptLabels.Welcome, isRtl: false, "My Store"));
        Assert.Equal("Tax (14%)", ReceiptLabels.Format(ReceiptLabels.Tax, isRtl: false, 14));
    }

    [Fact]
    public void Format_IsRtlTrue_InterpolatesArabicArgs()
    {
        Assert.Equal("أهلاً بك في متجري", ReceiptLabels.Format(ReceiptLabels.Welcome, isRtl: true, "متجري"));
        Assert.Equal("الضريبة (14%)", ReceiptLabels.Format(ReceiptLabels.Tax, isRtl: true, 14));
        Assert.Equal("التاريخ: 2026-08-12", ReceiptLabels.Format(ReceiptLabels.Date, isRtl: true, "2026-08-12"));
    }

    [Theory]
    [InlineData("cash", "Cash", "نقدي")]
    [InlineData("instapay", "InstaPay", "إنستاباي")]
    [InlineData("vodafoneCash", "Vodafone Cash", "فودافون كاش")]
    [InlineData("visa", "Visa", "فيزا")]
    public void PaymentType_KnownIds_MapToLocalized(string typeId, string expectedEn, string expectedAr)
    {
        Assert.Equal(expectedEn, ReceiptLabels.PaymentType(typeId, isRtl: false));
        Assert.Equal(expectedAr, ReceiptLabels.PaymentType(typeId, isRtl: true));
    }

    [Fact]
    public void PaymentType_UnknownId_FallsBackToRawId()
    {
        Assert.Equal("weird-payment", ReceiptLabels.PaymentType("weird-payment", isRtl: false));
        Assert.Equal("weird-payment", ReceiptLabels.PaymentType("weird-payment", isRtl: true));
    }

    [Fact]
    public void TicketLabels_IsRtlFalse_ReturnEnglishTemplates()
    {
        Assert.Equal("Round: {0}", ReceiptLabels.Get(ReceiptLabels.Round, isRtl: false));
        Assert.Equal("Order: {0}", ReceiptLabels.Get(ReceiptLabels.Order, isRtl: false));
        Assert.Equal("Fired: {0}", ReceiptLabels.Get(ReceiptLabels.Fired, isRtl: false));
    }

    [Fact]
    public void TicketLabels_IsRtlTrue_ReturnArabicTemplates()
    {
        Assert.Equal("الجولة: {0}", ReceiptLabels.Get(ReceiptLabels.Round, isRtl: true));
        Assert.Equal("الطلب: {0}", ReceiptLabels.Get(ReceiptLabels.Order, isRtl: true));
        Assert.Equal("التوقيت: {0}", ReceiptLabels.Get(ReceiptLabels.Fired, isRtl: true));
    }

    [Fact]
    public void TicketLabels_Format_Interpolates()
    {
        Assert.Equal("Round: 2", ReceiptLabels.Format(ReceiptLabels.Round, isRtl: false, 2));
        Assert.Equal("الجولة: 2", ReceiptLabels.Format(ReceiptLabels.Round, isRtl: true, 2));
        Assert.Equal("التوقيت: 14:30", ReceiptLabels.Format(ReceiptLabels.Fired, isRtl: true, "14:30"));
    }

    [Fact]
    public void PriceWithValue_BothLanguages_FormatsPrice()
    {
        Assert.Equal("Price: 12.50", ReceiptLabels.Format(ReceiptLabels.PriceWithValue, isRtl: false, "12.50"));
        Assert.Equal("السعر: 12.50", ReceiptLabels.Format(ReceiptLabels.PriceWithValue, isRtl: true, "12.50"));
    }
}