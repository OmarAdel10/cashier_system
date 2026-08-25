using System.Text.Json.Serialization;

namespace PrintServer.Linux.Models;

public sealed class SvgValidationRequest
{
    [JsonPropertyName("data")]
    public string Data { get; set; } = string.Empty;
}
