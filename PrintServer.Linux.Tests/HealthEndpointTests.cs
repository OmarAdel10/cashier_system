using Microsoft.AspNetCore.Mvc.Testing;
using System.Net.Http.Json;
using Xunit;

namespace PrintServer.Linux.Tests;

public sealed class HealthEndpointTests : IClassFixture<WebApplicationFactory<global::Program>>
{
    private readonly WebApplicationFactory<global::Program> _factory;

    public HealthEndpointTests(WebApplicationFactory<global::Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Health_ReturnsOk_WithStatusOkAndApiVersion4()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/api/printing/health");

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.Equal("ok", json.GetProperty("status").GetString());
        Assert.Equal(4, json.GetProperty("version").GetInt32());
    }
}
