import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/items_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/search_field.dart';
import '../../widgets/stock_badge.dart';
import 'item_detail_screen.dart';

/// Read-only view of current stock, available to every role.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemsProvider>();
    final items = provider.search(_query);

    return AppScaffold(
      title: 'Current Stock',
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
                    message: _query.isEmpty
                        ? 'No items yet.\nAn administrator adds them from the Items tab.'
                        : 'No item matches "$_query".',
                  )
                : ListView.separated(
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
                        trailing: StockBadge(quantity: item.currentStock),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(itemId: item.id),
                          ),
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
