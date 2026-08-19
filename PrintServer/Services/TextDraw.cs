using System;
using BidiReshapeSharp;
using SkiaSharp;
using SkiaSharp.HarfBuzz;

namespace PrintServer;

public enum RtlAlign { Left, Right, Center }

public static class TextDraw
{
    /// <summary>X position for text whose visual width is w: Right ends at x,
    /// Center straddles x, Left starts at x.</summary>
    public static float FromWidth(float x, float w, RtlAlign align) => align switch
    {
        RtlAlign.Right => x - w,
        RtlAlign.Center => x - w / 2f,
        _ => x,
    };

    public static bool ContainsArabic(string text)
    {
        foreach (var ch in text)
        {
            var c = (int)ch;
            if ((c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F) ||
                (c >= 0x0870 && c <= 0x089F) || (c >= 0x08A0 && c <= 0x08FF) ||
                (c >= 0xFB50 && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF))
                return true;
        }
        return false;
    }

    public static float MeasureVisual(string text, SKPaint paint, bool isRtl)
    {
        if (!isRtl || !ContainsArabic(text)) return paint.MeasureText(text);
        try { return paint.MeasureText(BidiReshape.ProcessString(text)); }
        catch { return paint.MeasureText(text); }
    }

    public static void DrawText(
        SKCanvas canvas, SKShaper? shaper, bool isRtl, string text,
        SKPaint paint, float x, float y, RtlAlign align)
    {
        paint.TextAlign = SKTextAlign.Left;

        if (!isRtl || !ContainsArabic(text))
        {
            canvas.DrawText(text, FromWidth(x, paint.MeasureText(text), align), y, paint);
            return;
        }

        string? visual = null;
        try { visual = BidiReshape.ProcessString(text); }
        catch { /* fall through to HarfBuzz path below */ }

        if (!string.IsNullOrEmpty(visual))
        {
            canvas.DrawText(visual, FromWidth(x, paint.MeasureText(visual), align), y, paint);
            return;
        }

        if (shaper == null)
        {
            canvas.DrawText(text, FromWidth(x, paint.MeasureText(text), align), y, paint);
            return;
        }

        var shaped = shaper.Shape(text, paint);
        if (shaped.Codepoints.Length == 0)
        {
            canvas.DrawText(text, FromWidth(x, paint.MeasureText(text), align), y, paint);
            return;
        }

        var glyphs = new ushort[shaped.Codepoints.Length];
        for (var i = 0; i < glyphs.Length; i++)
            glyphs[i] = (ushort)shaped.Codepoints[i];

        using var builder = new SKTextBlobBuilder();
        builder.AddPositionedRun(paint, glyphs, shaped.Points);
        using var blob = builder.Build();
        canvas.DrawText(blob, FromWidth(x, blob.Bounds.Width, align), y, paint);
    }
}