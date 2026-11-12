import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../repositories/item_repository.dart';

/// Live view of the item catalogue.
///
/// Backed by a Firestore snapshot stream, so a stock figure changed on the
/// one store phone updates the other store phone without a refresh — the
/// multi-device behaviour the old SQLite build could not offer.
class ItemsProvider extends ChangeNotifier {
  final ItemRepository _repository;
  StreamSubscription<List<Item>>? _sub;

  ItemsProvider({ItemRepository? repository})
    : _repository = repository ?? ItemRepository();

  List<Item> _items = const [];
  List<Item> get items => _items;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  void start() {
    _sub ??= _repository.watchAll().listen(
      (value) {
        _items = value;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _error = 'Could not load items';
        notifyListeners();
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _items = const [];
    _loading = true;
  }

  /// Case-insensitive match on code or name, which is how people search for
  /// stock on the floor.
  List<Item> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (i) =>
              i.code.toLowerCase().contains(q) ||
              i.name.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q),
        )
        .toList();
  }

  Item? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
