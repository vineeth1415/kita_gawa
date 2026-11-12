import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/working_day_provider.dart';
import '../utils/business_date.dart';
import '../utils/constants.dart';

/// Shows which working day is selected, or that none is.
///
/// Every role sees this, because the working day decides what the app will
/// let the store do: nothing can be recorded until a date is selected.
class DayStatusBanner extends StatelessWidget {
  final Widget? trailing;

  const DayStatusBanner({super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final day = context.watch<WorkingDayProvider>();

    late final Color background;
    late final Color foreground;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (day.loading) {
      background = Colors.grey.shade200;
      foreground = Colors.grey.shade800;
      icon = Icons.hourglass_empty;
      title = 'Checking the working day…';
      subtitle = '';
    } else if (day.isDayOpen) {
      final date = DateFormat(
        'EEE, d MMM yyyy',
      ).format(parseBusinessDate(day.businessDate!));
      if (day.isStale) {
        background = Colors.amber.withValues(alpha: 0.20);
        foreground = const Color(0xFF8A6100);
        icon = Icons.warning_amber_rounded;
        title = 'Working day: $date';
        subtitle = 'This is not today — close it to move on.';
      } else {
        background = AppColors.inward.withValues(alpha: 0.12);
        foreground = AppColors.inward;
        icon = Icons.event_available;
        title = 'Working day: $date';
        final openedAt = day.shift?.openedAt;
        subtitle = openedAt == null
            ? 'Started by ${day.shift?.openedByName ?? ''}'
            : 'Started ${DateFormat('h:mm a').format(openedAt)} '
                  'by ${day.shift?.openedByName ?? ''}';
      }
    } else {
      background = Colors.grey.shade200;
      foreground = Colors.grey.shade800;
      icon = Icons.event_busy;
      title = 'No working day selected';
      subtitle = 'The store selects the date before recording stock.';
    }

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
