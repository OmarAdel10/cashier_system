using System.Text.Json.Serialization;

namespace PrintServer.Models;

public sealed class SvgValidationRequest
{
    [JsonPropertyName("data")]
    public string Data { get; set; } = string.Empty;
}
