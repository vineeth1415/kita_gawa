import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/item.dart';
import '../../repositories/item_repository.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

/// Create or edit an item: code, name, description — plus an opening stock
/// figure on creation only.
class ItemFormScreen extends StatefulWidget {
  final Item? existing;

  const ItemFormScreen({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ItemRepository();

  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _openingStockController = TextEditingController(text: '0');

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _codeController = TextEditingController(text: existing?.code ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _openingStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (widget.isEditing) {
        await _repository.updateDefinition(
          itemId: widget.existing!.id,
          name: _nameController.text,
          description: _descriptionController.text,
        );
      } else {
        await _repository.create(
          code: _codeController.text,
          name: _nameController.text,
          description: _descriptionController.text,
          openingStock: int.parse(_openingStockController.text.trim()),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ItemCodeTakenException catch (e) {
      _snack('Code "${e.code}" is already used by another item');
    } catch (error) {
      _snack('Could not save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit item' : 'New item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSizes.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _codeController,
                  // The code is the document id, so changing it would orphan
                  // the item's movement history.
                  readOnly: widget.isEditing,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Code',
                    helperText: widget.isEditing
                        ? 'The code cannot be changed once movements exist'
                        : 'Unique. Letters, numbers, dot, dash, underscore',
                    prefixIcon: const Icon(Icons.qr_code),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9._\-]'),
                    ),
                    TextInputFormatter.withFunction(
                      (_, next) => next.copyWith(text: next.text.toUpperCase()),
                    ),
                  ],
                  validator: validateItemCode,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) => requiredField(v, label: 'Name'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                if (!widget.isEditing) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _openingStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Opening stock',
                      helperText:
                          'Stock on the shelf right now. Later changes must '
                          'go through inward, dispatch or an audit.',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: validateNonNegativeQuantity,
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing ? 'Save changes' : 'Create item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
