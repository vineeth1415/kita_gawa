import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../providers/items_provider.dart';
import '../../repositories/item_repository.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import '../../widgets/stock_badge.dart';
import 'item_form_screen.dart';

/// Admin-only catalogue management.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _repository = ItemRepository();
  String _query = '';

  Future<void> _confirmDelete(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.code}?'),
        content: Text(
          item.currentStock > 0
              ? 'This item still has ${item.currentStock} in stock. '
                    'Its movement history is kept, but the item will no longer '
                    'be available for new entries.'
              : 'Its movement history is kept, but the item will no longer be '
                    'available for new entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dispatch),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.delete(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${item.code} deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $error'),
          backgroundColor: AppColors.dispatch,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final items = provider.search(_query);

    return AppScaffold(
      title: 'Items',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ItemFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New item'),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSizes.screenPadding,
            child: SearchField(
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? EmptyState(
                    icon: Icons.category_outlined,
                    message: _query.isEmpty
                        ? 'No items yet.\nAdd the first one to get started.'
                        : 'No item matches "$_query".',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.code, style: AppTextStyles.partCode),
                        subtitle: Text(
                          item.description.isEmpty
                              ? item.name
                              : '${item.name} · ${item.description}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StockBadge(quantity: item.currentStock),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ItemFormScreen(existing: item),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  _confirmDelete(item);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
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
