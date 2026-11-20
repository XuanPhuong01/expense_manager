import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel_community/excel_community.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// A row in the exported monthly report (wallet opening balance is NOT income).
class ReportTransaction {
  const ReportTransaction({
    required this.date,
    required this.walletName,
    required this.type,
    required this.category,
    required this.amount,
    required this.note,
  });

  final DateTime date;
  final String walletName;
  final String type;
  final String category;
  final int amount;
  final String note;

  bool get isIncome => type == 'income';
  int get signedAmount => isIncome ? amount : -amount;
}

class MonthlyExportReport {
  const MonthlyExportReport({
    required this.month,
    required this.walletLabel,
    required this.rows,
    required this.totalIncome,
    required this.totalExpense,
  });

  final DateTime month;
  final String walletLabel;
  final List<ReportTransaction> rows;
  final int totalIncome;
  final int totalExpense;
  int get difference => totalIncome - totalExpense;

  /// Use the same Firestore snapshot and wallet filter as StatisticsScreen.
  factory MonthlyExportReport.fromFirestore({
    required DateTime month,
    required String? walletId,
    required Map<String, String> walletNames,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  }) {
    final rows = <ReportTransaction>[];
    var income = 0;
    var expense = 0;

    for (final doc in documents) {
      final data = doc.data();
      final id = data['walletId'];
      final kind = data['type'];
      final rawAmount = data['amount'];
      final rawDate = data['createdAt'];
      if (id is! String ||
          (walletId != null && id != walletId) ||
          (kind != 'expense' && kind != 'income') ||
          rawAmount is! num ||
          rawAmount <= 0 ||
          rawDate is! Timestamp) {
        continue;
      }
      final amount = rawAmount.toInt();
      final date = rawDate.toDate().toLocal();

      // Chỉ lấy giao dịch thuộc tháng cần xuất báo cáo.
      if (date.year != month.year || date.month != month.month) {
        continue;
      }
      final category = data['category'] is String
          ? (data['category'] as String).trim()
          : '';
      final note = data['note'] is String ? data['note'] as String : '';
      rows.add(
        ReportTransaction(
          date: date,
          walletName: walletNames[id] ?? 'Ví đã xóa',
          type: kind as String,
          category: category.isEmpty ? 'Khác' : category,
          amount: amount,
          note: note,
        ),
      );
      if (kind == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    rows.sort((a, b) => a.date.compareTo(b.date));
    return MonthlyExportReport(
      month: DateTime(month.year, month.month),
      walletLabel: walletId == null
          ? 'Tất cả ví'
          : (walletNames[walletId] ?? 'Ví đã xóa'),
      rows: rows,
      totalIncome: income,
      totalExpense: expense,
    );
  }
}

class ReportExportService {
  const ReportExportService._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year} '
      '${_two(date.hour)}:${_two(date.minute)}';

  static String _money(int amount) {
    final digits = amount.abs().toString();
    final spaced = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '${amount < 0 ? '-' : ''}$spaced đ';
  }

  static String _filename(MonthlyExportReport report, String extension) {
    final suffix = report.walletLabel == 'Tất cả ví' ? 'tat_ca' : 'mot_vi';
    return 'thu_chi_${report.month.year}_${_two(report.month.month)}_'
        '${suffix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  /// File is created in temporary app storage and exposed using Android Share.
  /// The user selects a target app/location to retain the generated report.
  static Future<void> shareExcel(MonthlyExportReport report) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Giao dich');
    final sheet = excel['Giao dich'];
    sheet.appendRow([
      TextCellValue(
        'BÁO CÁO THU CHI THÁNG ${_two(report.month.month)}/${report.month.year}',
      ),
    ]);
    sheet.appendRow([TextCellValue('Ví'), TextCellValue(report.walletLabel)]);
    sheet.appendRow([
      TextCellValue('Tổng thu (VND)'),
      IntCellValue(report.totalIncome),
    ]);
    sheet.appendRow([
      TextCellValue('Tổng chi (VND)'),
      IntCellValue(report.totalExpense),
    ]);
    sheet.appendRow([
      TextCellValue('Chênh lệch (VND)'),
      IntCellValue(report.difference),
    ]);
    sheet.appendRow([
      TextCellValue('Số giao dịch'),
      IntCellValue(report.rows.length),
    ]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Ngày giờ'),
      TextCellValue('Ví'),
      TextCellValue('Loại'),
      TextCellValue('Danh mục'),
      TextCellValue('Số tiền (+thu/-chi) VND'),
      TextCellValue('Ghi chú'),
    ]);
    for (final row in report.rows) {
      sheet.appendRow([
        TextCellValue(_date(row.date)),
        TextCellValue(row.walletName),
        TextCellValue(row.isIncome ? 'Khoản thu' : 'Khoản chi'),
        TextCellValue(row.category),
        IntCellValue(row.signedAmount),
        TextCellValue(row.note),
      ]);
    }
    sheet.setColumnWidth(0, 21);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 29);
    sheet.setColumnWidth(5, 38);
    final header = sheet.row(7);
    for (final cell in header) {
      cell?.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('DDE7FF'),
      );
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Không thể tạo file Excel.');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_filename(report, 'xlsx')}');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Báo cáo thu chi Excel',
      ),
    );
  }

  static Future<void> sharePdf(MonthlyExportReport report) async {
    // Downloaded on first use and cached by printing. Vietnamese Unicode needs
    // a Unicode font; default PDF Helvetica is not sufficient.
    final normal = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final document = pw.Document();
    final rows = report.rows;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: normal, bold: bold),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Trang ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            'BÁO CÁO THU CHI THÁNG ${_two(report.month.month)}/${report.month.year}',
            style: pw.TextStyle(
              font: bold,
              fontSize: 18,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Phạm vi: ${report.walletLabel}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 13),
          pw.Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              pw.Text('Tổng thu: ${_money(report.totalIncome)}'),
              pw.Text('Tổng chi: ${_money(report.totalExpense)}'),
              pw.Text('Chênh lệch: ${_money(report.difference)}'),
              pw.Text('Số giao dịch: ${rows.length}'),
            ],
          ),
          pw.SizedBox(height: 16),
          if (rows.isEmpty)
            pw.Text('Không có giao dịch trong kỳ này.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Ngày giờ',
                'Ví',
                'Loại',
                'Danh mục',
                'Số tiền (VND)',
                'Ghi chú',
              ],
              data: rows
                  .map(
                    (r) => <String>[
                      _date(r.date),
                      r.walletName,
                      r.isIncome ? 'Thu' : 'Chi',
                      r.category,
                      _money(r.signedAmount),
                      r.note,
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                font: bold,
                fontSize: 8,
                color: PdfColors.blue900,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
            ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Lưu ý: Số dư ban đầu của ví không được tính là thu nhập.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    final bytes = await document.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_filename(report, 'pdf')}');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Báo cáo thu chi PDF',
      ),
    );
  }
}
