import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/audit_session.dart';
import '../../models/item.dart';
import '../../providers/items_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/working_day_provider.dart';
import '../../repositories/audit_repository.dart';
import '../../utils/constants.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';

/// The count sheet: walk the catalogue, enter what is physically on the
/// shelf, and see the variance against the system figure immediately.
class AuditCountScreen extends StatefulWidget {
  final AuditSession session;

  const AuditCountScreen({super.key, required this.session});

  @override
  State<AuditCountScreen> createState() => _AuditCountScreenState();
}

class _AuditCountScreenState extends State<AuditCountScreen> {
  final _repository = AuditRepository();
  String _query = '';
  bool _submitting = false;

  bool get _readOnly => !widget.session.isOpen;

  Future<void> _enterCount(Item item, AuditCount? existing) async {
    // The dialog owns its own controller (see [_CountEntryDialog]) rather
    // than being handed one created here. Disposing a controller straight
    // after `showDialog` returns crashes: the dialog is still animating out
    // and its TextField still depends on the controller.
    final counted = await showDialog<int>(
      context: context,
      builder: (_) => _CountEntryDialog(item: item, existing: existing),
    );

    if (counted == null) return;
    try {
      await _repository.recordCount(
        sessionId: widget.session.id,
        item: item,
        countedStock: counted,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save the count: $error'),
          backgroundColor: AppColors.dispatch,
        ),
      );
    }
  }

  Future<void> _submit(List<AuditCount> counts) async {
    final withVariance = counts.where((c) => c.hasVariance).toList();

    final applyCorrections = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit verification?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${counts.length} items counted, '
              '${withVariance.length} with a variance.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Correcting stock posts an audit adjustment for each variance, '
              'so the change stays traceable in the ledger. Submitting '
              'without correcting records the count only.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5B5B66)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Record only'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.audit),
            child: const Text('Correct stock'),
          ),
        ],
      ),
    );
    if (applyCorrections == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await _repository.submitSession(
        session: widget.session,
        user: context.read<SessionProvider>().user!,
        applyCorrections: applyCorrections,
        shiftId: context.read<WorkingDayProvider>().openShiftId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.audit,
          content: Text(
            applyCorrections
                ? 'Verification submitted and stock corrected'
                : 'Verification submitted',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit: $error'),
          backgroundColor: AppColors.dispatch,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ItemsProvider>().search(_query);

    return Scaffold(
      appBar: AppBar(title: Text(_readOnly ? 'Verification' : 'Count stock')),
      body: StreamBuilder<List<AuditCount>>(
        stream: _repository.watchCounts(widget.session.id),
        builder: (context, snapshot) {
          final counts = snapshot.data ?? const <AuditCount>[];
          final byItem = {for (final c in counts) c.itemId: c};
          final varianceCount = counts.where((c) => c.hasVariance).length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.audit.withValues(alpha: 0.10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check, color: AppColors.audit),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${counts.length} of ${items.length} counted'
                        '${varianceCount > 0 ? ' · $varianceCount with variance' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.audit,
                        ),
                      ),
                    ),
                    if (_readOnly)
                      const Text(
                        'Submitted',
                        style: TextStyle(color: AppColors.audit),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: AppSizes.screenPadding,
                child: SearchField(
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'No items to count.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final count = byItem[item.id];
                          return _CountRow(
                            item: item,
                            count: count,
                            readOnly: _readOnly,
                            onTap: _readOnly
                                ? null
                                : () => _enterCount(item, count),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _readOnly
          ? null
          : StreamBuilder<List<AuditCount>>(
              stream: _repository.watchCounts(widget.session.id),
              builder: (context, snapshot) {
                final counts = snapshot.data ?? const <AuditCount>[];
                return FloatingActionButton.extended(
                  backgroundColor: counts.isEmpty
                      ? Colors.grey
                      : AppColors.audit,
                  foregroundColor: Colors.white,
                  onPressed: (counts.isEmpty || _submitting)
                      ? null
                      : () => _submit(counts),
                  icon: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.done_all),
                  label: Text(
                    _submitting ? 'Submitting…' : 'Submit verification',
                  ),
                );
              },
            ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final Item item;
  final AuditCount? count;
  final bool readOnly;
  final VoidCallback? onTap;

  const _CountRow({
    required this.item,
    required this.count,
    required this.readOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counted = count;
    final variance = counted?.variance ?? 0;
    final hasVariance = counted != null && counted.hasVariance;

    return ListTile(
      title: Text(item.code, style: AppTextStyles.partCode),
      subtitle: Text(
        counted == null
            ? '${item.name} · system ${item.currentStock}'
            : '${item.name} · system ${counted.systemStock} · '
                  'counted ${counted.countedStock}',
      ),
      trailing: counted == null
          ? Chip(
              label: const Text('Not counted'),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.grey.shade200,
              side: BorderSide.none,
            )
          : Chip(
              label: Text(
                hasVariance
                    ? (variance > 0 ? '+$variance' : '$variance')
                    : 'Match',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasVariance ? AppColors.dispatch : AppColors.inward,
                ),
              ),
              visualDensity: VisualDensity.compact,
              backgroundColor: hasVariance
                  ? AppColors.dispatch.withValues(alpha: 0.10)
                  : AppColors.inward.withValues(alpha: 0.10),
              side: BorderSide.none,
            ),
      onTap: onTap,
    );
  }
}

/// The count-entry dialog.
///
/// Stateful purely so that the TextEditingController's lifetime is tied to
/// the dialog's own element: it is disposed when the dialog is unmounted,
/// which is after the exit animation, not before it.
class _CountEntryDialog extends StatefulWidget {
  final Item item;
  final AuditCount? existing;

  const _CountEntryDialog({required this.item, required this.existing});

  @override
  State<_CountEntryDialog> createState() => _CountEntryDialogState();
}

class _CountEntryDialogState extends State<_CountEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.existing == null ? '' : '${widget.existing!.countedStock}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final text = (value ?? _controller.text).trim();
    Navigator.of(context).pop(int.tryParse(text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.code, style: AppTextStyles.partCode),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.item.name} · system says ${widget.item.currentStock}',
            style: const TextStyle(color: Color(0xFF6B6B75)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: 'Counted on shelf'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: _submit,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: () => _submit(), child: const Text('Save count')),
      ],
    );
  }
}
