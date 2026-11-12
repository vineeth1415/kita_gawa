import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/movement.dart';
import '../utils/constants.dart';

class MovementTile extends StatelessWidget {
  final Movement movement;
  final bool showItem;

  /// Print the calendar date with the time. Off in per-day lists where the
  /// date is already the heading; on in the multi-day transactions ledger.
  final bool showDate;

  const MovementTile({
    super.key,
    required this.movement,
    this.showItem = true,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (movement.type) {
      MovementType.inward => AppColors.inward,
      MovementType.dispatch => AppColors.dispatch,
      MovementType.auditAdjustment => AppColors.audit,
    };
    final icon = switch (movement.type) {
      MovementType.inward => Icons.south_west,
      MovementType.dispatch => Icons.north_east,
      MovementType.auditAdjustment => Icons.fact_check_outlined,
    };
    final time = movement.createdAt;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(
        showItem ? movement.itemCode : movement.type.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: showItem ? AppTextStyles.partCode : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showItem)
            Text(
              '${movement.itemName} · ${movement.type.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Row(
            children: [
              const Icon(Icons.tag, size: 14, color: Color(0xFF77777F)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  movement.referenceNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (time != null) ...[
                const Text('  ·  '),
                Text(
                  DateFormat(
                    showDate ? 'd MMM · h:mm a' : 'h:mm a',
                  ).format(time),
                ),
              ],
            ],
          ),
          Text(
            'by ${movement.userName}'
            '${movement.username.isEmpty ? '' : ' (${movement.username})'}'
            '${movement.shiftId == null ? ' · no working day' : ''}'
            '${movement.lateEntry ? ' · late entry' : ''}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            movement.delta > 0 ? '+${movement.delta}' : '${movement.delta}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '→ ${movement.resultingStock}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF77777F)),
          ),
        ],
      ),
    );
  }
}
