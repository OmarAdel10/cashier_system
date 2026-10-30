using SkiaSharp;

namespace PrintServer.Linux.Services;

/// <summary>
/// Renders CODE128 barcodes as an SKPath of black bar rects on a white background.
/// No System.Drawing dependency, no external barcode library.
/// </summary>
public sealed class BarcodeRenderer
{
    private const float ModuleWidth = 2f; // px per module
    private const float QuietZone = 10f; // px on each side

    // CODE128 symbol pattern table: each entry is 11 modules (1=bar, 0=space).
    // Index = symbol value 0..106. Start A=103, Start B=104, Start C=105, Stop=106.
    private static readonly string[] Code128Patterns =
    {
        "11011110110", // 0
        "11001111010", // 1
        "11001110110", // 2
        "11011101110", // 3
        "11011100110", // 4
        "11001101110", // 5
        "11010111100", // 6
        "11010011110", // 7
        "11010011011", // 8
        "11011001110", // 9
        "11011011010", // 10
        "11001011011", // 11
        "11010010111", // 12
        "11011001011", // 13
        "11001100111", // 14
        "11010011001", // 15
        "11011010011", // 16
        "11010100111", // 17
        "11010010011", // 18
        "11001001011", // 19
        "11001000101", // 20
        "11010000101", // 21
        "11000100101", // 22
        "11000010011", // 23
        "11000010010", // 24
        "11001000100", // 25
        "11001010000", // 26
        "11000010100", // 27
        "11000001010", // 28
        "11001001000", // 29
        "11000010001", // 30
        "11010001000", // 31
        "11000101000", // 32
        "11101110110", // 33
        "11101011100", // 34
        "11100111100", // 35
        "11100101110", // 36
        "11101110100", // 37
        "11101011100", // 38
        "11100110110", // 39
        "11100101011", // 40
        "11101001110", // 41
        "11100100111", // 42
        "11100010111", // 43
        "11101101000", // 44
        "11101001000", // 45
        "11100100010", // 46
        "11100010010", // 47
        "11101101010", // 48
        "11101010100", // 49
        "11100110100", // 50
        "11100101000", // 51
        "11100011010", // 52
        "11100001101", // 53
        "11101100100", // 54
        "11101000100", // 55
        "11100010010", // 56
        "11100001001", // 57
        "11001010111", // 58
        "11001010011", // 59
        "11001001011", // 60
        "11010010100", // 61
        "11001001100", // 62
        "11000110100", // 63
        "11000101100", // 64
        "11000010110", // 65
        "11000001011", // 66
        "11010010010", // 67
        "11001010010", // 68
        "11000100100", // 69
        "11000010010", // 70
        "11011010100", // 71
        "11011010010", // 72
        "11010011001", // 73
        "11011001001", // 74
        "11001100100", // 75
        "11000110010", // 76
        "11000011001", // 77
        "11000001100", // 78
        "11011011100", // 79
        "11011001110", // 80
        "11001011100", // 81
        "11001001110", // 82
        "11011000110", // 83
        "11000110110", // 84
        "11000011011", // 85
        "11000001101", // 86
        "11010110011", // 87
        "11010011010", // 88
        "11001101100", // 89
        "11000110110", // 90
        "11000011010", // 91
        "11000001101", // 92
        "11010111001", // 93
        "11010011101", // 94
        "11001101110", // 95
        "11000110111", // 96
        "11000011011", // 97
        "11000001110", // 98
        "11010011100", // 99 CODE C switch
        "11010011011", // 100 CODE B switch
        "11001101101", // 101
        "11000110101", // 102
        "11011101110", // 103 Start A
        "11011100110", // 104 Start B
        "11011101010", // 105 Start C
        "11011110110", // 106 Stop
    };

    public BarcodeOutput Render(string barcodeData)
    {
        if (string.IsNullOrEmpty(barcodeData))
            return new BarcodeOutput(new SKPath(), 53f, QuietZone * 2f);

        var symbols = EncodeSymbols(barcodeData);
        var path = new SKPath();
        var x = QuietZone;

        foreach (var symbol in symbols)
        {
            var pattern = Code128Patterns[symbol];
            foreach (var ch in pattern)
            {
                var isBar = ch == '1';
                var width = ModuleWidth;
                if (isBar)
                    path.AddRect(SKRect.Create(x, 0, width, 53f));
                x += width;
            }
        }

        var totalWidth = x + QuietZone;
        return new BarcodeOutput(path, 53f, totalWidth);
    }

    public int[] GetSymbolValues(string barcodeData) => EncodeSymbols(barcodeData);

    private static int[] EncodeSymbols(string barcodeData)
    {
        var symbols = new List<int>();

        // Choose initial code set.
        var useC = barcodeData.Length >= 2 && IsDigitPair(barcodeData, 0);
        symbols.Add(useC ? 105 : 104); // Start C or Start B

        var setC = useC;
        var i = 0;
        while (i < barcodeData.Length)
        {
            if (setC)
            {
                if (i + 1 < barcodeData.Length && IsDigitPair(barcodeData, i))
                {
                    symbols.Add(ParseDigitPair(barcodeData, i));
                    i += 2;
                    continue;
                }
                // Odd trailing digit or non-digit: switch back to B.
                symbols.Add(100); // CODE B
                setC = false;
                continue; // re-process current char in B
            }
            // set B
            if (i + 1 < barcodeData.Length && IsDigitPair(barcodeData, i) && DigitRunLength(barcodeData, i) >= 2)
            {
                symbols.Add(99); // CODE C
                setC = true;
                continue; // re-process current pair in C
            }
            symbols.Add(MapCharB(barcodeData[i]));
            i++;
        }

        // Checksum: standard CODE128 weights start symbol = 1, each subsequent
        // symbol weight increments by 1. Check satisfies:
        // sum_{i=0}^{m-1} (i+1)*symbols[i] + (m+1)*check ≡ 0 (mod 103)
        var m = symbols.Count; // symbols before check
        var weighted = 0;
        for (var idx = 0; idx < m; idx++)
            weighted += (idx + 1) * symbols[idx];
        var checkWeight = m + 1;
        var check = Modulo((103 - (weighted % 103)) % 103 * ModInverse(checkWeight, 103), 103);
        symbols.Add(check);
        symbols.Add(106); // Stop

        return symbols.ToArray();
    }

    private static int DigitRunLength(string data, int start)
    {
        var run = 0;
        while (start + run < data.Length && char.IsDigit(data[start + run]))
            run++;
        return run;
    }

    private static bool IsDigitPair(string data, int i) =>
        i + 1 < data.Length && char.IsDigit(data[i]) && char.IsDigit(data[i + 1]);

    private static int ParseDigitPair(string data, int i) =>
        (data[i] - '0') * 10 + (data[i + 1] - '0');

    private static int MapCharB(char c)
    {
        // Code Set B: ASCII 32..95 map to values 0..63 directly.
        if (c >= ' ' && c <= '_')
            return c - ' ';
        return c - 32 + 96; // ASCII 96..126 -> values 96..126
    }

    private static int ModInverse(int a, int mod)
    {
        a = ((a % mod) + mod) % mod;
        for (var x = 1; x < mod; x++)
            if ((a * x) % mod == 1)
                return x;
        return 1;
    }

    private static int Modulo(int value, int mod) => ((value % mod) + mod) % mod;
}

public readonly record struct BarcodeOutput(SKPath Path, float Height, float Width) : IDisposable
{
    public void Dispose() => Path.Dispose();
}
