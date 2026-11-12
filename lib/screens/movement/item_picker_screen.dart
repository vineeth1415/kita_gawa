import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../providers/items_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import '../../widgets/stock_badge.dart';

/// Choose the item to move. Returns the [Item] via Navigator.pop.
class ItemPickerScreen extends StatefulWidget {
  final String title;

  /// Hides items with nothing on the shelf — used for dispatch, where a
  /// zero-stock item can only produce an error.
  final bool onlyInStock;

  const ItemPickerScreen({
    super.key,
    this.title = 'Select item',
    this.onlyInStock = false,
  });

  @override
  State<ItemPickerScreen> createState() => _ItemPickerScreenState();
}

class _ItemPickerScreenState extends State<ItemPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    var items = provider.search(_query);
    if (widget.onlyInStock) {
      items = items.where((i) => i.currentStock > 0).toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                    icon: Icons.inventory_2_outlined,
                    message: _query.isNotEmpty
                        ? 'No item matches "$_query".'
                        : widget.onlyInStock
                        ? 'Nothing is in stock to dispatch.'
                        : 'No items yet.\nAn administrator adds them from the Items tab.',
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.code, style: AppTextStyles.partCode),
                        subtitle: Text(item.name),
                        trailing: StockBadge(quantity: item.currentStock),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
