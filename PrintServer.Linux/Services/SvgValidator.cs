using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using Svg.Skia;

namespace PrintServer.Linux.Services;

public sealed record SvgValidationResult(bool Valid, List<string> Errors)
{
    public static SvgValidationResult Ok() => new(true, []);

    public static SvgValidationResult Fail(params string[] errors) => new(false, [.. errors]);
}

/// <summary>
/// Validates uploaded SVG logos before they are stored by the app or parsed by
/// the receipt renderer. Blocks malformed XML, entity/DTD attacks (XXE,
/// billion-laughs), scripts, event handlers, external references and hostile
/// geometry, and probes renderability with the same SKSvg parser the receipt
/// pipeline uses, so a logo that the server cannot draw is rejected at upload
/// time instead of silently disappearing from printed receipts.
/// </summary>
public sealed class SvgValidator
{
    public const string CodeTooLarge = "TOO_LARGE";
    public const string CodeNotSvg = "NOT_SVG";
    public const string CodeMalformedXml = "MALFORMED_XML";
    public const string CodeDoctypeForbidden = "DOCTYPE_FORBIDDEN";
    public const string CodeScriptForbidden = "SCRIPT_FORBIDDEN";
    public const string CodeForbiddenElement = "FORBIDDEN_ELEMENT";
    public const string CodeEventAttrForbidden = "EVENT_ATTR_FORBIDDEN";
    public const string CodeExternalRefForbidden = "EXTERNAL_REF_FORBIDDEN";
    public const string CodeTooComplex = "TOO_COMPLEX";
    public const string CodeNotRenderable = "NOT_RENDERABLE";
    public const string CodeDimensionsInvalid = "DIMENSIONS_INVALID";

    public const int MaxSvgBytes = 5 * 1024 * 1024;
    public const int MaxElements = 20_000;
    public const int MaxDepth = 200;
    public const long MaxXmlCharacters = 10_000_000;
    public const float MaxDimension = 8192f;

    private static readonly HashSet<string> ForbiddenElements = new(StringComparer.OrdinalIgnoreCase)
    {
        "script",
        "foreignobject",
        "iframe",
        "object",
        "embed",
        "a",
        "audio",
        "video",
    };

    private static readonly HashSet<string> ExternalRefAttributes = new(StringComparer.OrdinalIgnoreCase)
    {
        "href",
        "xlink:href",
        "src",
    };

    private static readonly Regex DoctypeRegex = new(
        @"<!DOCTYPE\s+([A-Za-z_][\w.:-]*)",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public SvgValidationResult Validate(string? base64Data)
    {
        if (string.IsNullOrWhiteSpace(base64Data))
            return SvgValidationResult.Fail(CodeNotSvg);

        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(base64Data);
        }
        catch (FormatException)
        {
            return SvgValidationResult.Fail(CodeNotSvg);
        }

        return Validate(bytes);
    }

    public SvgValidationResult Validate(byte[] svgBytes)
    {
        if (svgBytes.Length == 0)
            return SvgValidationResult.Fail(CodeNotSvg);

        if (svgBytes.Length > MaxSvgBytes)
            return SvgValidationResult.Fail(CodeTooLarge);

        var text = DecodeUtf8(svgBytes);
        if (text is null)
            return SvgValidationResult.Fail(CodeNotSvg);

        if (!LooksLikeSvg(text))
            return SvgValidationResult.Fail(CodeNotSvg);

        var structureResult = ValidateXmlStructure(text);
        if (!structureResult.Valid)
            return structureResult;

        return ValidateRenderable(svgBytes);
    }

    private static string? DecodeUtf8(byte[] bytes)
    {
        try
        {
            return new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true)
                .GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            return null;
        }
    }

    private static bool LooksLikeSvg(string text)
    {
        var trimmed = text.TrimStart('\uFEFF', ' ', '\t', '\r', '\n');
        return trimmed.StartsWith("<svg", StringComparison.OrdinalIgnoreCase) ||
               trimmed.StartsWith("<?xml", StringComparison.OrdinalIgnoreCase) ||
               trimmed.StartsWith("<!--", StringComparison.Ordinal) ||
               trimmed.StartsWith("<!DOCTYPE", StringComparison.OrdinalIgnoreCase);
    }

    private static SvgValidationResult ValidateXmlStructure(string text)
    {
        var doctype = DoctypeRegex.Match(text);
        if (doctype.Success)
        {
            return doctype.Groups[1].Value.Equals("svg", StringComparison.OrdinalIgnoreCase)
                ? SvgValidationResult.Fail(CodeDoctypeForbidden)
                : SvgValidationResult.Fail(CodeNotSvg);
        }

        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null,
            IgnoreWhitespace = true,
            IgnoreComments = true,
            MaxCharactersInDocument = MaxXmlCharacters,
        };

        try
        {
            using var reader = XmlReader.Create(new StringReader(text), settings);
            var elementCount = 0;
            string? rootName = null;

            while (reader.Read())
            {
                if (reader.NodeType != XmlNodeType.Element)
                    continue;

                rootName ??= reader.LocalName;

                elementCount++;
                if (elementCount > MaxElements)
                    return SvgValidationResult.Fail(CodeTooComplex);

                if (reader.Depth > MaxDepth)
                    return SvgValidationResult.Fail(CodeTooComplex);

                if (ForbiddenElements.Contains(reader.LocalName))
                {
                    return reader.LocalName.Equals("script", StringComparison.OrdinalIgnoreCase)
                        ? SvgValidationResult.Fail(CodeScriptForbidden)
                        : SvgValidationResult.Fail(CodeForbiddenElement);
                }

                if (!reader.HasAttributes)
                    continue;

                for (var i = 0; i < reader.AttributeCount; i++)
                {
                    reader.MoveToAttribute(i);
                    var name = reader.Name;
                    var value = reader.Value;

                    if (name.StartsWith("on", StringComparison.OrdinalIgnoreCase))
                        return SvgValidationResult.Fail(CodeEventAttrForbidden);

                    if (ExternalRefAttributes.Contains(name) && !IsSafeReference(value))
                        return SvgValidationResult.Fail(CodeExternalRefForbidden);

                    if (name.Equals("style", StringComparison.OrdinalIgnoreCase) &&
                        ContainsUnsafeCss(value))
                        return SvgValidationResult.Fail(CodeExternalRefForbidden);
                }

                reader.MoveToElement();
            }

            if (rootName is null || !rootName.Equals("svg", StringComparison.OrdinalIgnoreCase))
                return SvgValidationResult.Fail(CodeNotSvg);

            return SvgValidationResult.Ok();
        }
        catch (XmlException ex) when (ex.Message.Contains("DTD", StringComparison.OrdinalIgnoreCase))
        {
            return SvgValidationResult.Fail(CodeDoctypeForbidden);
        }
        catch (XmlException)
        {
            return SvgValidationResult.Fail(CodeMalformedXml);
        }
        catch (Exception)
        {
            return SvgValidationResult.Fail(CodeMalformedXml);
        }
    }

    /// <summary>
    /// Allows data URIs (raster images only) and same-document fragment
    /// references; rejects every other scheme (http/https/file/javascript/...)
    /// including protocol-relative and percent-encoded variants.
    /// </summary>
    private static bool IsSafeReference(string value)
    {
        var v = value.Trim();
        if (v.Length == 0)
            return true;

        if (v.StartsWith("#", StringComparison.Ordinal))
            return true;

        var lower = v.ToLowerInvariant();
        if (lower.StartsWith("data:", StringComparison.Ordinal))
            return lower.StartsWith("data:image/", StringComparison.Ordinal);

        if (lower.StartsWith("http:", StringComparison.Ordinal) ||
            lower.StartsWith("https:", StringComparison.Ordinal) ||
            lower.StartsWith("file:", StringComparison.Ordinal) ||
            lower.StartsWith("javascript:", StringComparison.Ordinal) ||
            lower.Contains("://", StringComparison.Ordinal) ||
            lower.Contains("%3a", StringComparison.Ordinal))
            return false;

        var colon = v.IndexOf(':');
        return colon <= 0;
    }

    private static bool ContainsUnsafeCss(string value)
    {
        var lower = value.ToLowerInvariant();
        return lower.Contains("@import", StringComparison.Ordinal) ||
               lower.Contains("expression(", StringComparison.Ordinal) ||
               lower.Contains("javascript:", StringComparison.Ordinal) ||
               lower.Contains("behavior:", StringComparison.Ordinal) ||
               lower.Contains("url(http", StringComparison.Ordinal) ||
               lower.Contains("url(https", StringComparison.Ordinal) ||
               lower.Contains("url(file", StringComparison.Ordinal);
    }

    private static SvgValidationResult ValidateRenderable(byte[] svgBytes)
    {
        try
        {
            using var svg = new SKSvg();
            using var stream = new MemoryStream(svgBytes);
            svg.Load(stream);

            if (svg.Picture is null)
                return SvgValidationResult.Fail(CodeNotRenderable);

            var rect = svg.Picture.CullRect;
            if (!float.IsFinite(rect.Width) || !float.IsFinite(rect.Height) ||
                rect.Width <= 0 || rect.Height <= 0)
                return SvgValidationResult.Fail(CodeDimensionsInvalid);

            if (rect.Width > MaxDimension || rect.Height > MaxDimension)
                return SvgValidationResult.Fail(CodeDimensionsInvalid);

            return SvgValidationResult.Ok();
        }
        catch (Exception)
        {
            return SvgValidationResult.Fail(CodeNotRenderable);
        }
    }
}
