import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/movement.dart';
import '../models/shift_report.dart';

/// Exports a sealed report to CSV so it can leave the phone — mailed to head
/// office, or filed alongside the paperwork the reference numbers point at.
class CsvExportService {
  static final DateFormat _stamp = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Per-item summary: the shape most people want when reconciling a day.
  Future<File> buildSummaryCsv({
    required ShiftReport report,
    required List<ShiftReportLine> lines,
  }) {
    final rows = <List<dynamic>>[
      ['Kitagawa India — Stock Report'],
      ['Business date', report.businessDate],
      ['Opened by', report.openedByName],
      ['Closed by', report.closedByName],
      [
        'Closed at',
        report.closedAt == null ? '' : _stamp.format(report.closedAt!),
      ],
      [],
      [
        'code',
        'name',
        'opening_stock',
        'inward',
        'dispatch',
        'audit_adjustment',
        'closing_stock',
        'net_change',
      ],
      for (final line in lines)
        [
          line.code,
          line.name,
          line.openingStock,
          line.inwardQty,
          line.dispatchQty,
          line.adjustmentQty,
          line.closingStock,
          line.netChange,
        ],
      [],
      ['Total inward', report.totals.inwardQty],
      ['Total dispatched', report.totals.dispatchQty],
      ['Total audit adjustment', report.totals.adjustmentQty],
      ['Net change', report.totals.netChange],
      ['Movements recorded', report.totals.movementCount],
      ['Items touched', report.totals.itemsTouched],
      ['References', report.referenceNumbers.join(' ')],
    ];
    return _write(rows, 'kitagawa_stock_${report.businessDate}.csv');
  }

  /// The full ledger for the day, one row per movement.
  Future<File> buildMovementsCsv({
    required ShiftReport report,
    required List<Movement> movements,
  }) {
    final rows = <List<dynamic>>[
      [
        'timestamp',
        'business_date',
        'type',
        'code',
        'name',
        'quantity',
        'delta',
        'resulting_stock',
        'reference_number',
        'recorded_by',
        'recorded_by_login',
        'role',
        'in_shift',
        'late_entry',
      ],
      for (final m in movements)
        [
          m.createdAt == null ? '' : _stamp.format(m.createdAt!),
          m.businessDate,
          m.type.wireName,
          m.itemCode,
          m.itemName,
          m.quantity,
          m.delta,
          m.resultingStock,
          m.referenceNumber,
          m.userName,
          m.username,
          m.userRole,
          m.shiftId == null ? 'no' : 'yes',
          m.lateEntry ? 'yes' : 'no',
        ],
    ];
    return _write(rows, 'kitagawa_movements_${report.businessDate}.csv');
  }

  Future<File> _write(List<List<dynamic>> rows, String filename) async {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsString(csv);
  }
}
