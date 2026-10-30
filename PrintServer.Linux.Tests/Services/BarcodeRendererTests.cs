using PrintServer.Linux.Services;
using Xunit;

namespace PrintServer.Linux.Tests;

public sealed class BarcodeRendererTests
{
    private static readonly BarcodeRenderer Renderer = new();

    [Fact]
    public void Render_ReturnsNonEmptyPath_WithPositiveDimensions()
    {
        var output = Renderer.Render("1234567890");

        Assert.NotNull(output.Path);
        Assert.True(output.Width > 0);
        Assert.Equal(53f, output.Height);
    }

    [Fact]
    public void Render_IsDeterministic()
    {
        var a = Renderer.Render("ABC-123");
        var b = Renderer.Render("ABC-123");

        Assert.Equal(a.Width, b.Width);
        Assert.Equal(a.Height, b.Height);
    }

    [Fact]
    public void Render_StartsAndEndsWithQuietZone()
    {
        var output = Renderer.Render("1234567890");

        output.Path.GetBounds(out var bounds);
        // Left quiet zone: drawing starts after the quiet zone.
        Assert.True(bounds.Left >= 9.5f);
        // Right quiet zone: path ends before total width minus quiet zone.
        Assert.True(bounds.Right <= output.Width - 9.5f);
    }

    [Fact]
    public void SymbolValues_AllDigits_UseCodeCStart()
    {
        var symbols = Renderer.GetSymbolValues("1234567890");

        // Start C = 105.
        Assert.Equal(105, symbols[0]);
        // Stop = 106 at the end.
        Assert.Equal(106, symbols[^1]);
    }

    [Fact]
    public void SymbolValues_MixedContent_SwitchesCodeSets()
    {
        var symbols = Renderer.GetSymbolValues("ABC123");

        Assert.Contains(99, symbols);  // CODE C switch
        Assert.Contains(100, symbols); // CODE B switch
    }

    [Fact]
    public void Checksum_IsValid()
    {
        foreach (var data in new[] { "1234567890", "ABC123", "Hello, World!", "9999", "" })
        {
            var symbols = Renderer.GetSymbolValues(data);

            // Position 0 is the start symbol; 1-based weighted sum including
            // check must be 0 mod 103 (start=1, first data=2, ...).
            var weighted = 0;
            for (var i = 0; i < symbols.Length - 1; i++) // exclude stop (106, not part of checksum)
                weighted += (i + 1) * symbols[i];

            Assert.Equal(0, weighted % 103);
        }
    }

    [Fact]
    public void Width_GrowsWithDataLength()
    {
        var shortCode = Renderer.Render("12");
        var longCode = Renderer.Render("1234567890");

        Assert.True(longCode.Width > shortCode.Width);
    }

    [Fact]
    public void Render_EmptyString_ReturnsEmptyPathWithHeightAndQuietZoneWidth()
    {
        var output = Renderer.Render("");

        Assert.NotNull(output.Path);
        Assert.Equal(53f, output.Height);
        Assert.Equal(20f, output.Width); // QuietZone × 2
        output.Path.GetBounds(out var bounds);
        Assert.Equal(0f, bounds.Width);
    }

    [Fact]
    public void Render_SingleCharacter_ReturnsNonEmptyPath()
    {
        var output = Renderer.Render("1");

        Assert.NotNull(output.Path);
        Assert.Equal(53f, output.Height);
        Assert.True(output.Width > 0);
        output.Path.GetBounds(out var bounds);
        Assert.True(bounds.Width > 0);
    }

    [Fact]
    public void Render_NullInput_ReturnsEmptyOutput()
    {
        var output = Renderer.Render(null!);

        Assert.NotNull(output.Path);
        Assert.Equal(53f, output.Height);
        Assert.Equal(20f, output.Width);
        output.Path.GetBounds(out var bounds);
        Assert.Equal(0f, bounds.Width);
    }

    [Fact]
    public void Render_BarGeometry_MatchesExpectedModuleCount()
    {
        // "12": Start C (105) + digit pair 12 + check + Stop (106) = 4 symbols × 11 modules × 2px + 2×10px quiet zone
        var output = Renderer.Render("12");

        Assert.Equal(4 * 11 * 2f + 2 * 10f, output.Width);
    }

    [Fact]
    public void BarcodeOutput_Dispose_IsIdempotent()
    {
        var output = Renderer.Render("123");
        output.Dispose();
        output.Dispose(); // second dispose must not throw
    }

    [Fact]
    public void Render_OverMaxLength_ReturnsEmptyOutput()
    {
        var tooLong = new string('9', BarcodeRenderer.MaxBarcodeLength + 1);

        var output = Renderer.Render(tooLong);

        Assert.NotNull(output.Path);
        Assert.Equal(53f, output.Height);
        Assert.Equal(20f, output.Width); // QuietZone × 2, no bars drawn
        output.Path.GetBounds(out var bounds);
        Assert.Equal(0f, bounds.Width);
    }

    [Fact]
    public void Render_AtMaxLength_ReturnsNonEmptyPath()
    {
        var atMax = new string('1', BarcodeRenderer.MaxBarcodeLength);

        var output = Renderer.Render(atMax);

        Assert.True(output.Width > 20f); // bars present, not empty
        Assert.Equal(53f, output.Height);
    }
}
