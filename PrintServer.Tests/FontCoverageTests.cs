using System.IO;
using SkiaSharp;
using Xunit;

namespace PrintServer.Tests;

public class FontCoverageTests
{
    private static bool HasGlyph(string fileName, ushort codepoint)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Assets", fileName);
        using var stream = File.OpenRead(path);
        using var data = SKData.Create(stream);
        using var typeface = SKTypeface.FromData(data);
        return typeface!.GetGlyph(codepoint) != 0;
    }

    [Theory]
    [InlineData("NotoSansArabic-Regular.ttf")]
    [InlineData("NotoSansArabic-Bold.ttf")]
    public void ArabicFontCoversDigitsLatinAndPunctuation(string fileName)
    {
        foreach (var cp in new ushort[] { 0x0030, 0x0039, 0x0041, 0x007A, 0x0021, 0x002C, 0x0660 })
            Assert.True(HasGlyph(fileName, cp), $"missing U+{cp:X4} in {fileName}");
    }

    [Theory]
    [InlineData("NotoSansArabic-Regular.ttf")]
    [InlineData("NotoSansArabic-Bold.ttf")]
    public void ArabicFontStillCoversArabicLettersAndPresentationForms(string fileName)
    {
        foreach (var cp in new ushort[] { 0x0627, 0x0644, 0x0629, 0xFEE0, 0xFE91, 0x0645 })
            Assert.True(HasGlyph(fileName, cp), $"missing U+{cp:X4} in {fileName}");
    }
}