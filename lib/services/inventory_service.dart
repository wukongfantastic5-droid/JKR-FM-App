import 'package:flutter/foundation.dart' show debugPrint;
import '../data/inventory_data.dart';
import 'repo_service.dart';

class InventoryService {
  static final bool _debug = true;
  static List<InventoryItem> _items = [];

  static void _log(String msg) {
    if (_debug) debugPrint('[Inventory] $msg');
  }

  static List<InventoryItem> get items => List.unmodifiable(_items);

  static Future<void> load() async {
    try {
      final data = await RepoService.readFile('inventory.json');
      if (data is List) {
        _items = data.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
        _log('loaded ${_items.length} items');
      }
    } catch (e) {
      _log('load error: $e');
    }
  }

  static Future<void> _save() async {
    try {
      await RepoService.writeFile('inventory.json', _items.map((e) => e.toJson()).toList());
    } catch (e) {
      _log('save error: $e');
    }
  }

  static Future<void> add(InventoryItem item) async {
    _items.add(item);
    await _save();
    _log('added "${item.name}"');
  }

  static Future<void> update(InventoryItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _items[i] = item;
      await _save();
      _log('updated "${item.name}"');
    }
  }

  static Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
    _log('deleted item $id');
  }
}
