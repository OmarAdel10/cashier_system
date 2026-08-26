using System.Runtime.InteropServices;
using PrintServer.Linux.Services;

namespace PrintServer.Linux.Tests.Mocks;

internal sealed class MockCupsClient : CupsPrinterService.ICupsNative
{
    [StructLayout(LayoutKind.Sequential)]
    private struct Dest
    {
        public IntPtr Name;
        public IntPtr Instance;
        public int IsDefault;
        public int NumOptions;
        public IntPtr Options;
    }

    public List<string> Printers { get; } = [];
    public string? DefaultPrinter { get; set; }
    public List<(string Printer, string FilePath, string Title)> PrintCalls { get; } = [];
    public int JobIdToReturn { get; set; } = 1;

    private readonly List<IntPtr> _namePtrs = [];
    private IntPtr _destsPtr = IntPtr.Zero;
    private IntPtr _defaultPtr = IntPtr.Zero;

    public int GetDests(out IntPtr dests)
    {
        FreeDests();
        var size = Marshal.SizeOf<Dest>();
        _destsPtr = Printers.Count == 0 ? IntPtr.Zero : Marshal.AllocHGlobal(Printers.Count * size);
        for (var i = 0; i < Printers.Count; i++)
        {
            var namePtr = Marshal.StringToHGlobalAnsi(Printers[i]);
            _namePtrs.Add(namePtr);
            var d = new Dest { Name = namePtr, IsDefault = Printers[i] == DefaultPrinter ? 1 : 0 };
            Marshal.StructureToPtr(d, _destsPtr + i * size, fDeleteOld: false);
        }
        dests = _destsPtr;
        return Printers.Count;
    }

    public void FreeDests(int numDests, IntPtr dests) => FreeDests();

    public IntPtr GetDefault()
    {
        if (_defaultPtr != IntPtr.Zero) Marshal.FreeHGlobal(_defaultPtr);
        _defaultPtr = DefaultPrinter is null ? IntPtr.Zero : Marshal.StringToHGlobalAnsi(DefaultPrinter);
        return _defaultPtr;
    }

    public int PrintFile(string printer, string filename, string title, int numOptions, IntPtr options)
    {
        PrintCalls.Add((printer, filename, title));
        return JobIdToReturn;
    }

    private void FreeDests()
    {
        foreach (var p in _namePtrs) Marshal.FreeHGlobal(p);
        _namePtrs.Clear();
        if (_destsPtr != IntPtr.Zero) Marshal.FreeHGlobal(_destsPtr);
        _destsPtr = IntPtr.Zero;
    }
}
