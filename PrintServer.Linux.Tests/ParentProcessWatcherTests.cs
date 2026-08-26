using Microsoft.Extensions.Hosting;
using PrintServer.Linux.Services;
using System.Diagnostics;
using Xunit;

namespace PrintServer.Linux.Tests;

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
        Func<int, DateTime, bool> isAlive,
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
    public void Ctor_CapturesParentStartTime()
    {
        var lifetime = new RecordingLifetime();
        var watcher = new ParentProcessWatcher(
            parentPid: Process.GetCurrentProcess().Id,
            lifetime,
            TimeSpan.FromMilliseconds(50));

        Assert.NotNull(watcher);
    }

    [Fact]
    public async Task Execute_WhenParentExits_RequestsStop()
    {
        var lifetime = new RecordingLifetime();
        using var watcher = Create(lifetime, (_, _) => false);
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
        using var watcher = Create(lifetime, (_, _) => true);
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
        using var watcher = Create(lifetime, (_, _) => parentAlive);
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

    [Fact]
    public void DefaultIsAlive_PidExistsStartTimeMatches_ReturnsTrue()
    {
        var current = Process.GetCurrentProcess();
        Assert.True(ParentProcessWatcher.DefaultIsAlive(current.Id, current.StartTime));
    }

    [Fact]
    public void DefaultIsAlive_PidExistsStartTimeMismatch_ReturnsFalse()
    {
        var current = Process.GetCurrentProcess();
        Assert.False(ParentProcessWatcher.DefaultIsAlive(current.Id, current.StartTime.AddSeconds(1)));
    }

    [Fact]
    public void DefaultIsAlive_InvalidPid_ReturnsFalse()
    {
        Assert.False(ParentProcessWatcher.DefaultIsAlive(int.MaxValue, DateTime.Now));
    }

    [Fact]
    public void DefaultIsAlive_ExpiredPid_ReturnsFalse()
    {
        Assert.False(ParentProcessWatcher.DefaultIsAlive(999999, DateTime.Now));
    }
}