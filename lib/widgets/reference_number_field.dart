import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/validators.dart';

/// The reference-number input, defined once so every screen that moves stock
/// collects it identically.
///
/// Input formatters do the shaping — strip anything non-alphanumeric, force
/// upper case, cap the length — so the operator physically cannot type an
/// invalid reference. The validator still runs, and firestore.rules checks the
/// format again server-side.
class ReferenceNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String? helperText;
  final void Function(String)? onFieldSubmitted;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  const ReferenceNumberField({
    super.key,
    required this.controller,
    this.helperText,
    this.onFieldSubmitted,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
      decoration: InputDecoration(
        labelText: 'Reference number',
        hintText: 'e.g. INV2024001',
        helperText:
            helperText ??
            'Letters and numbers, '
                '$kReferenceMinLength–$kReferenceMaxLength characters',
        prefixIcon: const Icon(Icons.tag),
        counterText: '',
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        LengthLimitingTextInputFormatter(kReferenceMaxLength),
        TextInputFormatter.withFunction(
          (_, next) => next.copyWith(text: next.text.toUpperCase()),
        ),
      ],
      validator: validateReferenceNumber,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
