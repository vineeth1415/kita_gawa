import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';

/// Quantity entry with oversized +/- buttons flanking a typed value.
///
/// Both affordances matter on a warehouse floor: tapping is faster for the
/// common small counts, typing is the only sane option for a pallet of 250.
class QuantityStepper extends StatelessWidget {
  final TextEditingController controller;
  final int min;
  final int? max;
  final String label;

  /// Validation lives on this widget's own field. An earlier version kept a
  /// separate hidden TextFormField for it, which crashed: Flutter asserts
  /// that a TextStyle fontSize is null or greater than zero, and the trick
  /// for hiding the field was fontSize: 0.
  final String? Function(String?)? validator;

  const QuantityStepper({
    super.key,
    required this.controller,
    this.min = 1,
    this.max,
    this.label = 'Quantity',
    this.validator,
  });

  int get _value => int.tryParse(controller.text.trim()) ?? 0;

  void _nudge(int by) {
    var next = _value + by;
    if (next < min) next = min;
    if (max != null && next > max!) next = max!;
    controller.text = '$next';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StepButton(icon: Icons.remove, onPressed: () => _nudge(-1)),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(labelText: label),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: validator,
          ),
        ),
        const SizedBox(width: 12),
        _StepButton(icon: Icons.add, onPressed: () => _nudge(1)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(64, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: AppSizes.buttonIconSize),
      ),
    );
  }
}
