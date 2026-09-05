import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One labeled table within a report PDF - mirrors the shared `_breakdownTable` widget's shape
/// (title, columns, rows) so exporting a report tab is just handing it the same data already
/// computed for the on-screen view.
class ReportPdfSection {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  ReportPdfSection({required this.title, required this.columns, required this.rows});
}

/// Builds a simple one-page-per-section PDF (title, summary stat row, then each table section)
/// and opens the OS print/save dialog via the `printing` package - the same renderer already used
/// for invoice/quotation PDFs, so there's no dependency on the .NET Host being reachable to export
/// a report someone is already looking at on screen.
Future<void> exportReportPdf({
  required String title,
  required List<(String label, String value)> stats,
  required List<ReportPdfSection> sections,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Generated ${DateTime.now().toLocal()}'.split('.').first, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        if (stats.isNotEmpty)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              for (final (label, value) in stats)
                pw.Container(
                  margin: const pw.EdgeInsets.only(right: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        for (final section in sections) ...[
          pw.SizedBox(height: 20),
          pw.Text(section.title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (section.rows.isEmpty)
            pw.Text('No data.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headers: section.columns,
              data: section.rows,
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: null,
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            ),
        ],
      ],
    ),
  );

  await Printing.layoutPdf(name: '${title.replaceAll(' ', '_')}.pdf', onLayout: (_) async => doc.save());
}
