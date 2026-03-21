import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/task.dart';
import '../models/focus_session.dart';

class ExportService {
  // ─── CSV ─────────────────────────────────────────────────────────────────────

  Future<void> exportTasksToCSV(List<Task> tasks) async {
    final rows = [
      ['ID', 'Title', 'Description', 'Due Date', 'Priority', 'Status', 'Tags'],
      ...tasks.map((t) => [
            t.id,
            t.title,
            t.description ?? '',
            t.dueDate?.toIso8601String() ?? '',
            t.priority.name,
            t.status.name,
            t.tags.join(';'),
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/rise_tomorrow_tasks.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Rise Tomorrow - Tasks Export',
    );
  }

  Future<void> exportSessionsToCSV(List<FocusSession> sessions) async {
    final rows = [
      ['ID', 'Name', 'Type', 'Start', 'End', 'Duration (min)', 'Completed'],
      ...sessions.map((s) => [
            s.id,
            s.sessionName,
            s.type.label,
            s.startTime.toIso8601String(),
            s.endTime.toIso8601String(),
            s.actualDuration.toString(),
            s.completed.toString(),
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/rise_tomorrow_sessions.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Rise Tomorrow - Focus Sessions Export',
    );
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────────

  Future<void> exportTasksToPDF(List<Task> tasks) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Rise Tomorrow — Task Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated: ${DateTime.now().toLocal().toString().split('.').first}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Task', 'Priority', 'Due Date', 'Status'],
            data: tasks
                .map((t) => [
                      t.title,
                      t.priority.name.toUpperCase(),
                      t.dueDate?.toLocal().toString().split(' ').first ?? '—',
                      t.status.name,
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF6366F1)),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB)),
              ),
            ),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'rise_tomorrow_tasks.pdf',
    );
  }
}
