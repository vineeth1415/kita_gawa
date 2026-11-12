import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../models/movement.dart';
import '../../providers/session_provider.dart';
import '../../providers/working_day_provider.dart';
import '../../repositories/movement_repository.dart';
import '../../repositories/report_repository.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/quantity_stepper.dart';
import '../../widgets/reference_number_field.dart';
import '../../widgets/stock_badge.dart';
import 'item_picker_screen.dart';

/// The one screen that records stock movement, inward or outward.
///
/// The two directions differ only in sign and in the stock ceiling, so they
/// share this form rather than each having a near-copy. That keeps the
/// reference-number rule enforced in exactly one place. Both directions file
/// against the store's selected working day and refuse to save without one.
class MovementEntryScreen extends StatefulWidget {
  final MovementType type;
  final Item? preselectedItem;

  const MovementEntryScreen({
    super.key,
    required this.type,
    this.preselectedItem,
  });

  bool get isInward => type == MovementType.inward;

  @override
  State<MovementEntryScreen> createState() => _MovementEntryScreenState();
}

class _MovementEntryScreenState extends State<MovementEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _referenceController = TextEditingController();
  final _repository = MovementRepository();
  final _reportRepository = ReportRepository();

  Item? _item;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _item = widget.preselectedItem;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Color get _accent => widget.isInward ? AppColors.inward : AppColors.dispatch;

  String get _actionLabel => widget.isInward ? 'Record Inward' : 'Dispatch';

  Future<void> _pickItem() async {
    final picked = await Navigator.of(context).push<Item>(
      MaterialPageRoute(
        builder: (_) => ItemPickerScreen(
          title: widget.isInward ? 'Item coming in' : 'Item to dispatch',
          onlyInStock: !widget.isInward,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _item = picked);
    }
  }

  Future<void> _submit() async {
    final item = _item;
    if (item == null) {
      _snack('Choose an item first');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantityController.text.trim());
    final reference = normalizeReferenceNumber(_referenceController.text);
    final session = context.read<SessionProvider>();
    final day = context.read<WorkingDayProvider>();
    final user = session.user!;

    final shiftId = day.openShiftId;
    if (shiftId == null) {
      _snack('Select the working day before recording stock');
      return;
    }

    setState(() => _submitting = true);
    try {
      // A movement filed against a day whose report is already sealed is
      // flagged rather than refused: refusing would lose a real event, and
      // amending the sealed report would make it untrustworthy.
      final businessDate = shiftId;
      final alreadyReported =
          await _reportRepository.fetch(businessDate) != null;

      final movement = widget.isInward
          ? await _repository.recordInward(
              itemId: item.id,
              quantity: quantity,
              referenceNumber: reference,
              user: user,
              shiftId: shiftId,
              businessDate: businessDate,
              lateEntry: alreadyReported,
            )
          : await _repository.recordDispatch(
              itemId: item.id,
              quantity: quantity,
              referenceNumber: reference,
              user: user,
              shiftId: shiftId,
              businessDate: businessDate,
            );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(movement);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _accent,
          content: Text(
            '${widget.isInward ? 'Received' : 'Dispatched'} $quantity × '
            '${item.code} · ${item.currentStock} → ${movement.resultingStock}',
          ),
        ),
      );
    } on InsufficientStockException catch (e) {
      _snack('Only ${e.available} in stock — cannot dispatch ${e.requested}');
    } on ItemMissingException {
      _snack('That item no longer exists');
    } catch (error) {
      _snack('Could not save: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dispatch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final blockedForClosedDay = !context.watch<WorkingDayProvider>().isDayOpen;

    return Scaffold(
      appBar: AppBar(title: Text(_actionLabel)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSizes.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (blockedForClosedDay)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF8A6100)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No working day is selected. Select the date '
                            'on the Entry tab before recording stock.',
                            style: TextStyle(color: Color(0xFF8A6100)),
                          ),
                        ),
                      ],
                    ),
                  ),

                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _accent.withValues(alpha: 0.12),
                      child: Icon(
                        widget.isInward ? Icons.south_west : Icons.north_east,
                        color: _accent,
                      ),
                    ),
                    title: Text(
                      item?.code ?? 'Choose an item',
                      style: item == null ? null : AppTextStyles.partCode,
                    ),
                    subtitle: Text(
                      item == null ? 'Tap to search the catalogue' : item.name,
                    ),
                    trailing: item == null
                        ? const Icon(Icons.chevron_right)
                        : StockBadge(quantity: item.currentStock),
                    onTap: _submitting ? null : _pickItem,
                  ),
                ),
                const SizedBox(height: 24),

                QuantityStepper(
                  controller: _quantityController,
                  label: widget.isInward
                      ? 'Quantity received'
                      : 'Quantity to dispatch',
                  max: widget.isInward ? null : item?.currentStock,
                  validator: (value) {
                    final base = validatePositiveQuantity(value);
                    if (base != null) return base;
                    if (!widget.isInward && item != null) {
                      final qty = int.parse(value!.trim());
                      if (qty > item.currentStock) {
                        return 'Only ${item.currentStock} in stock';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                ReferenceNumberField(
                  controller: _referenceController,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: (_submitting || blockedForClosedDay)
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _accent),
                  icon: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          widget.isInward ? Icons.south_west : Icons.north_east,
                        ),
                  label: Text(_submitting ? 'Saving…' : _actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
