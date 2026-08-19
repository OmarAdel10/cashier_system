using SkiaSharp;
using PrintServer;
using Xunit;

namespace PrintServer.Tests;

public class TextDrawTests
{
    private static SKPaint Paint() => new()
    {
        Typeface = SKTypeface.FromFamilyName("Arial"),
        TextSize = 10f,
        IsAntialias = true,
    };

    [Fact]
    public void FromWidth_Right_ReturnsLeftShiftedX()
    {
        using var p = Paint();
        var x = TextDraw.FromWidth(100f, p.MeasureText("Qty"), RtlAlign.Right);
        Assert.True(x < 100f, "right-aligned text must start left of x");
        Assert.Equal(100f - p.MeasureText("Qty"), x, 1);
    }

    [Fact]
    public void FromWidth_Center_ReturnsHalfWidthOffset()
    {
        using var p = Paint();
        var x = TextDraw.FromWidth(90f, p.MeasureText("Total"), RtlAlign.Center);
        Assert.Equal(90f - p.MeasureText("Total") / 2f, x, 1);
    }

    [Fact]
    public void FromWidth_Left_ReturnsXUnchanged()
    {
        Assert.Equal(50f, TextDraw.FromWidth(50f, 100f, RtlAlign.Left));
    }

    [Fact]
    public void ContainsArabic_DetectsArabicLettersOnly()
    {
        Assert.True(TextDraw.ContainsArabic("رقم الطلب: ORD-00001"));
        Assert.False(TextDraw.ContainsArabic("ORD-00001"));
        Assert.False(TextDraw.ContainsArabic("12 Gamasa - Street"));
        Assert.False(TextDraw.ContainsArabic("5000"));
    }

    [Fact]
    public void DrawText_Ltr_NeutralizesPaintTextAlign()
    {
        using var canvas = new SKCanvas(new SKBitmap(200, 100));
        using var p = Paint();
p.TextAlign = SKTextAlign.Right;
        TextDraw.DrawText(canvas, null, isRtl: false, "Qty", p, 150f, 50f, RtlAlign.Right);
        Assert.Equal(SKTextAlign.Left, p.TextAlign);
    }

    [Fact]
    public void DrawText_RtlNonArabicText_IsNotReshaped()
    {
        // "ORD-00001" must render in its original LTR order even in RTL mode.
        using var canvas = new SKCanvas(new SKBitmap(200, 100));
        using var p = Paint();
        TextDraw.DrawText(canvas, null, isRtl: true, "ORD-00001", p, 150f, 50f, RtlAlign.Right);
        // No exception, and paint still left-aligned afterwards.
        Assert.Equal(SKTextAlign.Left, p.TextAlign);
    }
}