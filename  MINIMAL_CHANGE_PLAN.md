MINIMAL CHANGE PLAN: Add CSV + PDF Export to Inventory Feature
================================================================

TASK: Add export functionality that saves CSV and PDF files of product inventory
FOLLOWING: Minimal Change Engineer discipline - smallest diff, no scope creep
FILE: lib/features/inventory/data/services/barcode_export_service.dart
      lib/features/inventory/presentation/bloc/barcode_export_cubit.dart

CURRENT STATE:
- Existing barcode export: exports single PNG label via RepaintBoundary.toImage()
- Settings: exportDirectoryPath stored in AppSettingsEntity, managed by SettingsBloc
- File picker: used in export_directory_section.dart for choosing directory
- Products: barcode, name, price, stock, notes, isQuickTile, tileColorHex

REQUIREMENT:
- Add export that saves 2 files: CSV and PDF (organized/simple to read)
- Export path from Settings (exportDirectoryPath)
- Minimal changes - follow existing patterns, no major refactors
- Keep existing barcode export functionality intact

MINIMAL CHANGES NEEDED:

1. BARCODE_EXPORT_SERVICE.dart — Add 2 new methods:
   - exportCsv: writes product list as CSV file
   - exportPdf: generates minimal valid PDF with product list
   - Both use exportDirectoryPath from settings, fall back to temp dir

2. BARCODE_EXPORT_CUBIT.dart — Add:
   - New states: BarcodeExportCsvSuccess, BarcodeExportPdfSuccess (or reuse)
   - exportCsv() and exportPdf() methods that emit success/failure states
   - Keep existing export() method intact

3. NO changes to:
   - inventory_event.dart — no new events needed (can reuse existing patterns or add minimal)
   - inventory_state.dart — no new fields needed
   - app_product_model.dart — no changes needed
   - i_inventory_repository.dart — no changes needed

DESIGN RATIONALE:

CSV export: Straightforward — write product fields as comma-separated values.
PDF export: Without adding a 500KB+ PDF library, generate a minimal valid PDF file.
  A PDF is just structured text. The minimal PDF format needs:
  %PDF-1.4 header, object definitions, content stream with text.
  This adds ~40 lines but keeps the PDF self-contained and dependency-free.
  Alternative: render widget to image — but that's misleading as "PDF".

SETTINGS PATH:
- Read exportDirectoryPath from AppSettingsEntity (already available via settings bloc)
- Fallback: use system temp directory (same pattern as receipt_print_helper.dart)

FILE_SAVING APPROACH:
- Use same file_picker pattern as export_directory_section.dart for directory selection
- But since export is programmatic (from inventory screen), read the stored path
- File naming: organized — CSV: inventory_<timestamp>.csv, PDF: inventory_<timestamp>.pdf

DIFF ANALYSIS (expected minimal):
- barcode_export_service.dart: +~35 lines (CSV + PDF methods)
- barcode_export_cubit.dart: +~20 lines (new methods + states)
- Total: ~55 new lines, zero changed lines in other files

This plan follows the Minimal Change Engineer philosophy:
- Touch only what the task requires
- No "while I'm here" refactors
- Three similar lines beats premature abstraction
- Every line justifiable as "task requires it"