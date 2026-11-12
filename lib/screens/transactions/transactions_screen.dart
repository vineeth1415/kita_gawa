import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/movement.dart';
import '../../repositories/movement_repository.dart';
import '../../utils/business_date.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_tile.dart';

/// The live ledger, for the read-only login.
///
/// Every inward and outward entry, newest first, each stamped with the part
/// code, reference, who recorded it (name and login ID) and when — the trail
/// management and audit verify against. A date filter narrows it to one
/// working day; without one the most recent entries across days are shown.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repository = MovementRepository();
  String? _date;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date == null ? today : parseBusinessDate(_date!),
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: 'Show transactions for',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = businessDateOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;

    return AppScaffold(
      title: 'Transactions',
      actions: [
        IconButton(
          tooltip: 'Filter by date',
          icon: const Icon(Icons.calendar_month),
          onPressed: _pickDate,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: date == null
                  ? const Text(
                      'Most recent entries, all days',
                      style: TextStyle(color: Color(0xFF6B6B75)),
                    )
                  : InputChip(
                      avatar: const Icon(Icons.event, size: 18),
                      label: Text(
                        DateFormat(
                          'EEE, d MMM yyyy',
                        ).format(parseBusinessDate(date)),
                      ),
                      onDeleted: () => setState(() => _date = null),
                      deleteButtonTooltipMessage: 'Show all days',
                    ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Movement>>(
              key: ValueKey(date),
              stream: date == null
                  ? _repository.watchRecent()
                  : _repository.watchForBusinessDate(date),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    message: 'Could not load transactions.\n${snapshot.error}',
                  );
                }
                final movements = snapshot.data ?? const <Movement>[];
                if (movements.isEmpty) {
                  return EmptyState(
                    icon: Icons.list_alt,
                    message: date == null
                        ? 'No transactions recorded yet.'
                        : 'No transactions on this day.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => MovementTile(
                    movement: movements[index],
                    showDate: date == null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
