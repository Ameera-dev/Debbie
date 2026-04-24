import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/transactions_repository.dart';
import '../data/repositories/values_repository.dart';
import '../providers/database_provider.dart';

class ExportService {
  const ExportService(this._txRepo, this._valuesRepo);

  final TransactionsRepository _txRepo;
  final ValuesRepository _valuesRepo;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Export all transactions as CSV and share via system share sheet.
  Future<void> exportCsv() async {
    final rows = await _buildRows();
    final csvData = const ListToCsvConverter().convert(rows);
    final file = await _writeToFile(csvData, 'debbie-transactions.csv');
    await Share.shareXFiles([XFile(file.path)]);
  }

  /// Export all transactions as Excel (.xlsx) and share via system share sheet.
  Future<void> exportExcel() async {
    final rows = await _buildRows();
    final bytes = _buildExcelBytes(rows);
    final file = await _writeBytesToFile(bytes, 'debbie-transactions.xlsx');
    await Share.shareXFiles([XFile(file.path)]);
  }

  // ---------------------------------------------------------------------------
  // Build flat rows (shared between CSV and Excel)
  // ---------------------------------------------------------------------------

  Future<List<List<String>>> _buildRows() async {
    final transactions = await _txRepo.getAll();
    final values = await _valuesRepo.getAll();
    final valueById = {for (final v in values) v.id: v};

    // Header row
    final headers = [
      'Date',
      'Type',
      'Session Title',
      'Item Description',
      'Amount (IDR)',
      'Value',
      'Tags',
      'Goal ID',
      'Session Note',
    ];

    final rows = <List<String>>[headers];
    final dateFmt = DateFormat('yyyy-MM-dd');

    for (final tx in transactions) {
      for (final item in tx.items) {
        final value = item.valueId != null ? valueById[item.valueId] : null;
        rows.add([
          dateFmt.format(tx.date),
          tx.type,
          tx.displayTitle,
          item.description,
          item.amount.toString(),
          value?.name ?? '',
          item.tags.join(', '),
          item.goalId ?? '',
          tx.notes ?? '',
        ]);
      }
    }

    return rows;
  }

  // ---------------------------------------------------------------------------
  // Excel builder
  // ---------------------------------------------------------------------------

  List<int> _buildExcelBytes(List<List<String>> rows) {
    final excel = Excel.createExcel();
    const sheetName = 'Transactions';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    // Header style
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#3E6C7E'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Write header row
    final headers = rows.first;
    for (var col = 0; col < headers.length; col++) {
      final cell = CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0);
      sheet.updateCell(
        cell,
        TextCellValue(headers[col]),
        cellStyle: headerStyle,
      );
    }

    // Write data rows
    for (var rowIdx = 1; rowIdx < rows.length; rowIdx++) {
      final row = rows[rowIdx];
      for (var col = 0; col < row.length; col++) {
        final cell = CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: rowIdx,
        );

        // Amount column (index 4) as integer for proper Excel handling
        if (col == 4) {
          final amount = int.tryParse(row[col]);
          if (amount != null) {
            sheet.updateCell(cell, IntCellValue(amount));
            continue;
          }
        }

        sheet.updateCell(cell, TextCellValue(row[col]));
      }
    }

    // Set reasonable column widths
    const widths = [12.0, 8.0, 24.0, 24.0, 16.0, 14.0, 20.0, 12.0, 30.0];
    for (var col = 0; col < widths.length; col++) {
      sheet.setColumnWidth(col, widths[col]);
    }

    return excel.encode()!;
  }

  // ---------------------------------------------------------------------------
  // File I/O helpers
  // ---------------------------------------------------------------------------

  Future<File> _writeToFile(String content, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(content);
  }

  Future<File> _writeBytesToFile(List<int> bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(transactionsRepositoryProvider),
    ref.watch(valuesRepositoryProvider),
  );
});
