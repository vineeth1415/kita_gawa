import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/movement.dart';
import '../../models/shift_report.dart';
import '../../repositories/report_repository.dart';
import '../../services/csv_export_service.dart';
import '../../services/share_service.dart';
import '../../utils/business_date.dart';
import '../../utils/constants.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_tile.dart';

/// A sealed day, in full: headline totals, the per-item breakdown, and the
/// underlying ledger — plus CSV export so the record can leave the device.
class ReportDetailScreen extends StatefulWidget {
  final String businessDate;

  const ReportDetailScreen({super.key, required this.businessDate});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _repository = ReportRepository();
  final _csv = CsvExportService();
  final _share = ShareService();

  ShiftReport? _report;
  List<ShiftReportLine> _lines = const [];
  List<Movement> _movements = const [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await _repository.fetch(widget.businessDate);
    final lines = report == null
        ? <ShiftReportLine>[]
        : await _repository.fetchLines(widget.businessDate);
    final movements = report == null
        ? <Movement>[]
        : await _repository.fetchMovements(widget.businessDate);
    if (!mounted) return;
    setState(() {
      _report = report;
      _lines = lines;
      _movements = movements;
      _loading = false;
    });
  }

  Future<void> _export() async {
    final report = _report;
    if (report == null) return;
    setState(() => _exporting = true);
    try {
      final summary = await _csv.buildSummaryCsv(report: report, lines: _lines);
      final ledger = await _csv.buildMovementsCsv(
        report: report,
        movements: _movements,
      );
      await _share.shareFiles([
        summary,
        ledger,
      ], subject: 'Kitagawa stock report ${report.businessDate}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export: $error'),
          backgroundColor: AppColors.dispatch,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final title = DateFormat(
      'd MMM yyyy',
    ).format(parseBusinessDate(widget.businessDate));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (report != null)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.ios_share),
              tooltip: 'Export CSV',
              onPressed: _exporting ? null : _export,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const EmptyState(
              icon: Icons.hourglass_empty,
              message:
                  'No report for this day yet.\n'
                  'It is saved when the store closes the working day.',
            )
          : ListView(
              padding: AppSizes.screenPadding,
              children: [
                _HeaderCard(report: report),
                const SizedBox(height: 20),
                _TotalsCard(totals: report.totals),
                if (report.auditSessionsSubmitted > 0) ...[
                  const SizedBox(height: 20),
                  _AuditCard(report: report),
                ],
                if (report.lateEntryDates.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _LateEntriesCard(dates: report.lateEntryDates),
                ],
                const SizedBox(height: 24),
                const _SectionTitle('Per item'),
                const SizedBox(height: 8),
                _LinesTable(lines: _lines),
                const SizedBox(height: 24),
                _SectionTitle('Movements (${_movements.length})'),
                const SizedBox(height: 8),
                if (_movements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No stock moved on this day.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B6B75)),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < _movements.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          MovementTile(movement: _movements[i]),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                if (report.referenceNumbers.isNotEmpty) ...[
                  const _SectionTitle('References'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ref in report.referenceNumbers)
                        Chip(
                          label: Text(ref),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );
}

class _HeaderCard extends StatelessWidget {
  final ShiftReport report;
  const _HeaderCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppColors.inward, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Sealed report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  report.businessDate,
                  style: const TextStyle(color: Color(0xFF6B6B75)),
                ),
              ],
            ),
            const Divider(height: 20),
            _row(
              'Opened',
              report.openedAt == null
                  ? '—'
                  : '${timeFormat.format(report.openedAt!)} by ${report.openedByName}',
            ),
            _row(
              'Closed',
              report.closedAt == null
                  ? '—'
                  : '${timeFormat.format(report.closedAt!)} by ${report.closedByName}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6B6B75), fontSize: 15),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    ),
  );
}

class _TotalsCard extends StatelessWidget {
  final ShiftReportTotals totals;
  const _TotalsCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _stat('Inward', '+${totals.inwardQty}', AppColors.inward),
                _stat(
                  'Dispatched',
                  '-${totals.dispatchQty}',
                  AppColors.dispatch,
                ),
                _stat(
                  'Adjusted',
                  totals.adjustmentQty >= 0
                      ? '+${totals.adjustmentQty}'
                      : '${totals.adjustmentQty}',
                  AppColors.audit,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _stat(
                  'Movements',
                  '${totals.movementCount}',
                  AppColors.brandBlue,
                ),
                _stat(
                  'Items touched',
                  '${totals.itemsTouched}',
                  AppColors.brandBlue,
                ),
                _stat(
                  'Net change',
                  totals.netChange >= 0
                      ? '+${totals.netChange}'
                      : '${totals.netChange}',
                  AppColors.ink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B75)),
        ),
      ],
    ),
  );
}

class _AuditCard extends StatelessWidget {
  final ShiftReport report;
  const _AuditCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.fact_check, color: AppColors.audit),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock verification',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${report.auditSessionsSubmitted} audit '
                    '${report.auditSessionsSubmitted == 1 ? 'session' : 'sessions'} '
                    'submitted · ${report.auditVariancesFound} '
                    '${report.auditVariancesFound == 1 ? 'item' : 'items'} with a variance',
                    style: const TextStyle(color: Color(0xFF5B5B66)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LateEntriesCard extends StatelessWidget {
  final List<String> dates;
  const _LateEntriesCard({required this.dates});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.watch_later_outlined, color: Color(0xFF8A6100)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Late entries recorded',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock was recorded against ${dates.join(', ')} after '
                    'that day had already been closed. Those sealed reports '
                    'were left untouched — the movements appear here instead.',
                    style: const TextStyle(color: Color(0xFF5B5B66)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  final List<ShiftReportLine> lines;
  const _LinesTable({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No items on this report.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B6B75)),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      // Wide numeric tables scroll inside their own box rather than making
      // the whole page scroll sideways.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Open'), numeric: true),
            DataColumn(label: Text('In'), numeric: true),
            DataColumn(label: Text('Out'), numeric: true),
            DataColumn(label: Text('Adj'), numeric: true),
            DataColumn(label: Text('Close'), numeric: true),
          ],
          rows: [
            for (final line in lines)
              DataRow(
                cells: [
                  DataCell(Text(line.code, style: AppTextStyles.partCode)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(line.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(Text('${line.openingStock}')),
                  DataCell(
                    Text(
                      line.inwardQty == 0 ? '—' : '+${line.inwardQty}',
                      style: TextStyle(
                        color: line.inwardQty == 0 ? null : AppColors.inward,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      line.dispatchQty == 0 ? '—' : '-${line.dispatchQty}',
                      style: TextStyle(
                        color: line.dispatchQty == 0
                            ? null
                            : AppColors.dispatch,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      line.adjustmentQty == 0
                          ? '—'
                          : (line.adjustmentQty > 0
                                ? '+${line.adjustmentQty}'
                                : '${line.adjustmentQty}'),
                      style: TextStyle(
                        color: line.adjustmentQty == 0 ? null : AppColors.audit,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${line.closingStock}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
