import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/reports_provider.dart';
import '../../utils/business_date.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'report_detail_screen.dart';

/// Every sealed day, newest first. Visible to all roles: a report is the
/// shared record of what happened, not a store-private document.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final dateFormat = DateFormat('EEE, d MMM yyyy');

    return AppScaffold(
      title: 'Reports',
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.reports.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              message:
                  'No reports yet.\n'
                  'A report is saved when the store closes a working day.',
            )
          : ListView.separated(
              itemCount: provider.reports.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final report = provider.reports[index];
                final totals = report.totals;
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7F0F9),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppColors.brandBlue,
                    ),
                  ),
                  title: Text(
                    dateFormat.format(parseBusinessDate(report.businessDate)),
                  ),
                  subtitle: Text(
                    '+${totals.inwardQty} in · -${totals.dispatchQty} out · '
                    '${totals.movementCount} movements',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReportDetailScreen(businessDate: report.businessDate),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
