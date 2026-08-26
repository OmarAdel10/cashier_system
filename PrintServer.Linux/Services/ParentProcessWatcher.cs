using System.ComponentModel;
using System.Diagnostics;
using Microsoft.Extensions.Hosting;

namespace PrintServer.Linux.Services;

/// <summary>
/// Watches for the parent (cashier app) process to exit and stops the host so
/// port 5150 is released even when the app crashes or is killed without
/// cleanup. Without this, an orphaned PrintServer keeps the port bound and the
/// next app launch crashes with an unhandled bind exception (0xE0434352).
/// </summary>
public sealed class ParentProcessWatcher : BackgroundService
{
    private readonly int _parentPid;
    private readonly IHostApplicationLifetime _lifetime;
    private readonly TimeSpan _pollInterval;
    private readonly Func<int, bool> _isAlive;

    public ParentProcessWatcher(
        int parentPid,
        IHostApplicationLifetime lifetime,
        TimeSpan? pollInterval = null,
        Func<int, bool>? isAlive = null)
    {
        if (parentPid <= 0)
            throw new ArgumentOutOfRangeException(nameof(parentPid), "Parent PID must be positive.");
        _parentPid = parentPid;
        _lifetime = lifetime;
        _pollInterval = pollInterval ?? TimeSpan.FromSeconds(2);
        _isAlive = isAlive ?? DefaultIsAlive;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            if (!_isAlive(_parentPid))
            {
                Console.WriteLine($"[PrintServer] Parent process {_parentPid} exited; shutting down.");
                _lifetime.StopApplication();
                return;
            }

            await Task.Delay(_pollInterval, stoppingToken);
        }
    }

    private static bool DefaultIsAlive(int pid)
    {
        try
        {
            using var process = Process.GetProcessById(pid);
            return !process.HasExited;
        }
        catch (ArgumentException)
        {
            // No process with that PID exists.
            return false;
        }
        catch (InvalidOperationException)
        {
            // Process has already exited.
            return false;
        }
        catch (Win32Exception)
        {
            // No access or other transient error — assume alive to stay safe.
            return true;
        }
    }
}
