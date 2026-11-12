import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movement.dart';
import '../../providers/items_provider.dart';
import '../../repositories/movement_repository.dart';
import '../../utils/constants.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_tile.dart';

/// An item's current stock plus the movements that produced it.
class ItemDetailScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final item = context.watch<ItemsProvider>().byId(itemId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item')),
        body: const EmptyState(
          icon: Icons.help_outline,
          message: 'This item no longer exists.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(item.code, style: AppTextStyles.partCode)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            color: AppColors.surface,
            child: Column(
              children: [
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B6B75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${item.currentStock}',
                  style: const TextStyle(
                    fontSize: AppSizes.quantityFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandBlue,
                  ),
                ),
                const Text(
                  'in stock',
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B6B75)),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Movement history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Movement>>(
              stream: MovementRepository().watchRecentForItem(itemId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final movements = snapshot.data ?? const <Movement>[];
                if (movements.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    message: 'No movements recorded for this item yet.',
                  );
                }
                return ListView.separated(
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      MovementTile(movement: movements[index], showItem: false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
