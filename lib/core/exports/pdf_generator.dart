import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a minimal table-based PDF file from [data].
/// [data] is a list of lists where:
/// - data[0] = column headers (optional, will be rendered as bold)
/// - data[i] (i > 0) = table row data
/// [title] optional document title (appears at top)
/// Returns bytes representing the PDF.
Future<List<int>> generateTablePdf(
  List<List<String>> data, {
  String? title,
}) async {
  final pdf = pw.Document();

  // Add a simple page with margins
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        final pages = <pw.Widget>[];

        // Title (if provided)
        if (title != null && title.isNotEmpty) {
          pages.add(
            pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
          pages.add(pw.SizedBox(height: 16));
        }

        // Table
        if (data.isNotEmpty) {
          final headers = data[0];
          final rows = data.skip(1).where((row) => row.isNotEmpty).toList();

          if (rows.isNotEmpty || headers.isNotEmpty) {
            // Table styles
            final headerStyle = pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFFFFFFFF),
            );
            final cellStyle = pw.TextStyle(fontSize: 10);
            final rowDecoration = pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFFFFF),
            );
            final headerDecoration = pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF4F46E5),
            );

            // Header row
            final headerCells = <pw.Widget>[];
            for (final header in headers) {
              headerCells.add(
                pw.Container(
                  decoration: headerDecoration,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4.0),
                    child: pw.Text(header, style: headerStyle),
                  ),
                ),
              );
            }

            pages.add(
              pw.Table(
                children: [
                  // Header row
                  pw.TableRow(children: headerCells),
                  // Data rows
                  ...rows.map(
                    (row) => pw.TableRow(
                      children: _buildRowCells(row, cellStyle, rowDecoration),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return pw.Column(children: pages);
      },
    ),
  );

  return pdf.save();
}

/// Builds a single table row cells.
List<pw.Widget> _buildRowCells(
  List<String> cells,
  pw.TextStyle cellStyle,
  pw.BoxDecoration rowDecoration,
) {
  final result = <pw.Widget>[];
  for (final cell in cells) {
    result.add(
      pw.Container(
        decoration: rowDecoration,
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(4.0),
          child: pw.Text(cell, style: cellStyle),
        ),
      ),
    );
  }
  return result;
}

/// Creates a simple PDF with just text content.
/// Useful for simple reports or when table formatting is not needed.
Future<List<int>> generateSimplePdf(
  List<String> lines, {
  String? title,
  pw.Font? font,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        final pages = <pw.Widget>[];

        if (title != null && title.isNotEmpty) {
          pages.add(
            pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
          pages.add(pw.SizedBox(height: 16));
        }

        for (final line in lines) {
          pages.add(
            pw.Center(
              child: pw.Text(
                line,
                style: pw.TextStyle(fontSize: 12, font: font),
              ),
            ),
          );
        }

        return pw.Column(children: pages);
      },
    ),
  );

  return pdf.save();
}
