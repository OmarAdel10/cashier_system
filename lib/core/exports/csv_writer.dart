import 'dart:io';

/// Writes CSV data to a file using stream-based writing for memory efficiency.
/// Each row in [rows] becomes a CSV line. Strings containing commas, quotes,
/// or newlines are properly escaped per RFC 4180.
Future<void> writeCsvRows(List<List<String>> rows, String filePath) async {
  final file = File(filePath);
  await file.create(recursive: true);

  final sink = file.openWrite();
  try {
    // Write header row if present (first row is typically headers)
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final escaped = row.map((cell) {
        // RFC 4180 escaping: quote if contains comma, quote, or newline
        if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(',');
      sink.writeln(escaped);
    }
  } finally {
    sink.close();
  }
}

/// Reads a CSV file and returns rows as List<List<String>>.
/// Handles RFC 4180 standard escaping (quoted fields, doubled quotes).
Future<List<List<String>>> readCsvRows(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    return [];
  }

  final contents = await file.readAsString();
  if (contents.isEmpty) {
    return [];
  }

  final lines = contents.split('\n');
  final rows = <List<String>>[];

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final cells = <String>[];

    // Simple CSV parsing: split by comma, respect quoted fields
    final parts = <String>[];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        }
      } else if (char == ',' && !inQuotes) {
        parts.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      parts.add(current.toString());
    }

    // Clean up quotes from each cell
    for (int i = 0; i < parts.length; i++) {
      var cell = parts[i];
      if (cell.length >= 2 && cell.startsWith('"') && cell.endsWith('"')) {
        cell = cell.substring(1, cell.length - 1).replaceAll('""', '"');
      }
      cells.add(cell);
    }
    rows.add(cells);
  }

  return rows;
}