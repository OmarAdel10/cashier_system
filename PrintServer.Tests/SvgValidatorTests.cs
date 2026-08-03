using PrintServer.Services;
using Xunit;

namespace PrintServer.Tests;

public sealed class SvgValidatorTests
{
    private readonly SvgValidator _validator = new();

    private static byte[] FromString(string svg) => System.Text.Encoding.UTF8.GetBytes(svg);

    private SvgValidationResult Validate(string svg) => _validator.Validate(FromString(svg));

    [Fact]
    public void Validate_WellFormedIconSvg_ReturnsValid()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#ff0000"/></svg>""");

        Assert.True(result.Valid);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void Validate_SvgWithGradientAndFragmentReference_ReturnsValid()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><defs><linearGradient id="g"><stop offset="0" stop-color="#f00"/><stop offset="1" stop-color="#00f"/></linearGradient></defs><rect width="32" height="32" fill="url(#g)"/></svg>""");

        Assert.True(result.Valid);
    }

    [Fact]
    public void Validate_SvgWithLeadingComment_ReturnsValid()
    {
        var result = Validate(
            """<!-- generator comment --><svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="5" fill="#000"/></svg>""");

        Assert.True(result.Valid);
    }

    [Fact]
    public void Validate_ContainsScriptElement_RejectsWithScriptForbidden()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeScriptForbidden, result.Errors);
    }

    [Fact]
    public void Validate_ContainsForeignObject_RejectsWithForbiddenElement()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"><foreignObject><div xmlns="http://www.w3.org/1999/xhtml">hi</div></foreignObject></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeForbiddenElement, result.Errors);
    }

    [Fact]
    public void Validate_ContainsDoctypeWithEntity_RejectsWithDoctypeForbidden()
    {
        var result = Validate(
            """<!DOCTYPE svg [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><svg xmlns="http://www.w3.org/2000/svg"/>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeDoctypeForbidden, result.Errors);
    }

    [Fact]
    public void Validate_ContainsEventAttribute_RejectsWithEventAttrForbidden()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><rect width="10" height="10"/></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeEventAttrForbidden, result.Errors);
    }

    [Fact]
    public void Validate_ExternalHttpHref_RejectsWithExternalRefForbidden()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"><image href="http://evil.example/x.png" width="10" height="10"/></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeExternalRefForbidden, result.Errors);
    }

    [Fact]
    public void Validate_ExternalFileXlinkHref_RejectsWithExternalRefForbidden()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><image xlink:href="file:///etc/passwd" width="10" height="10"/></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeExternalRefForbidden, result.Errors);
    }

    [Fact]
    public void Validate_NonImageDataUriHref_RejectsWithExternalRefForbidden()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"><image href="data:text/html,&lt;script&gt;" width="10" height="10"/></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeExternalRefForbidden, result.Errors);
    }

    [Fact]
    public void Validate_CssStyleWithImport_RejectsWithExternalRefForbidden()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10" style="@import url(http://evil.example/x.css)"/></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeExternalRefForbidden, result.Errors);
    }

    [Fact]
    public void Validate_MalformedXml_RejectsWithMalformedXml()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeMalformedXml, result.Errors);
    }

    [Fact]
    public void Validate_RenamedPngBytes_RejectsWithNotSvg()
    {
        var result = _validator.Validate(
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D]);

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeNotSvg, result.Errors);
    }

    [Fact]
    public void Validate_HtmlDisguisedAsSvg_RejectsWithNotSvg()
    {
        var result = Validate(
            """<!DOCTYPE html><html><body>scam</body></html>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeNotSvg, result.Errors);
    }

    [Fact]
    public void Validate_InvalidBase64_RejectsWithNotSvg()
    {
        var result = _validator.Validate("%%%not-base64%%%");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeNotSvg, result.Errors);
    }

    [Fact]
    public void Validate_EmptySvg_ReturnsInvalid()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg"/>""");

        Assert.False(result.Valid);
    }

    [Fact]
    public void Validate_AbsurdCanvasDimensions_RejectsWithDimensionsInvalid()
    {
        var result = Validate(
            """<svg xmlns="http://www.w3.org/2000/svg" width="999999" height="999999"><rect width="999999" height="999999" fill="#000"/></svg>""");

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeDimensionsInvalid, result.Errors);
    }

    [Fact]
    public void Validate_DeeplyNestedGroups_RejectsWithTooComplex()
    {
        var depth = SvgValidator.MaxDepth + 50;
        var svg = new System.Text.StringBuilder(
            """<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">""");
        for (var i = 0; i < depth; i++)
            svg.Append("<g>");
        svg.Append("<rect width=\"10\" height=\"10\"/>");
        for (var i = 0; i < depth; i++)
            svg.Append("</g>");
        svg.Append("</svg>");

        var result = Validate(svg.ToString());

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeTooComplex, result.Errors);
    }

    [Fact]
    public void Validate_TooManyElements_RejectsWithTooComplex()
    {
        var svg = new System.Text.StringBuilder(
            """<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">""");
        for (var i = 0; i < SvgValidator.MaxElements + 100; i++)
            svg.Append("<path d=\"M0 0h1v1z\"/>");
        svg.Append("</svg>");

        var result = Validate(svg.ToString());

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeTooComplex, result.Errors);
    }

    [Fact]
    public void Validate_OverFiveMb_RejectsWithTooLarge()
    {
        var bytes = new byte[SvgValidator.MaxSvgBytes + 1];

        var result = _validator.Validate(bytes);

        Assert.False(result.Valid);
        Assert.Contains(SvgValidator.CodeTooLarge, result.Errors);
    }
}
