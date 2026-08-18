namespace PrintServer.Services;

/// <summary>
/// Raised when a logo was provided but could not be validated, parsed or
/// rasterized. Propagates to the API layer so the cashier app receives a
/// non-200 response with a human-readable body instead of a silently
/// missing logo on the receipt.
/// </summary>
public sealed class LogoRenderException : Exception
{
    public LogoRenderException(string message)
        : base(message)
    {
    }

    public LogoRenderException(string message, Exception inner)
        : base(message, inner)
    {
    }
}