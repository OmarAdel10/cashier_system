using Microsoft.Extensions.Hosting;
using PrintServer.Services;
using Xunit;

namespace PrintServer.Tests;

public sealed class ParentProcessWatcherTests
{
    private sealed class RecordingLifetime : IHostApplicationLifetime
    {
        public int StopRequestCount { get; private set; }
        public CancellationToken ApplicationStarted => CancellationToken.None;
        public CancellationToken ApplicationStopping => CancellationToken.None;
        public CancellationToken ApplicationStopped => CancellationToken.None;
        public void StopApplication() => StopRequestCount++;
    }

    private static ParentProcessWatcher Create(
        RecordingLifetime lifetime,
        Func<int, bool> isAlive,
        TimeSpan? pollInterval = null) =>
        new(
            parentPid: 4242,
            lifetime,
            pollInterval ?? TimeSpan.FromMilliseconds(50),
            isAlive);

    [Fact]
    public void Ctor_NonPositivePid_Throws()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            new ParentProcessWatcher(0, new RecordingLifetime()));
    }

    [Fact]
    public async Task Execute_WhenParentExits_RequestsStop()
    {
        var lifetime = new RecordingLifetime();
        using var watcher = Create(lifetime, _ => false);
        await watcher.StartAsync(CancellationToken.None);
        try
        {
            var deadline = DateTime.UtcNow.AddSeconds(5);
            while (lifetime.StopRequestCount == 0 && DateTime.UtcNow < deadline)
                await Task.Delay(20);

            Assert.Equal(1, lifetime.StopRequestCount);
        }
        finally
        {
            await watcher.StopAsync(CancellationToken.None);
        }
    }

    [Fact]
    public async Task Execute_WhenParentStaysAlive_DoesNotStop()
    {
        var lifetime = new RecordingLifetime();
        using var watcher = Create(lifetime, _ => true);
        await watcher.StartAsync(CancellationToken.None);
        try
        {
            await Task.Delay(200);
            Assert.Equal(0, lifetime.StopRequestCount);
        }
        finally
        {
            await watcher.StopAsync(CancellationToken.None);
        }
    }

    [Fact]
    public async Task Execute_WhenParentAppearsAfterStart_StopsOnlyOnce()
    {
        var lifetime = new RecordingLifetime();
        var parentAlive = true;
        using var watcher = Create(lifetime, _ => parentAlive);
        await watcher.StartAsync(CancellationToken.None);
        try
        {
            await Task.Delay(100);
            Assert.Equal(0, lifetime.StopRequestCount);

            parentAlive = false;

            var deadline = DateTime.UtcNow.AddSeconds(5);
            while (lifetime.StopRequestCount == 0 && DateTime.UtcNow < deadline)
                await Task.Delay(20);

            Assert.Equal(1, lifetime.StopRequestCount);
        }
        finally
        {
            await watcher.StopAsync(CancellationToken.None);
        }
    }
}
