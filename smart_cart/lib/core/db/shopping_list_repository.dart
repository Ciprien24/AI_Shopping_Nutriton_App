import 'package:smart_cart/core/db/collections/shopping_item_entity.dart';
import 'package:smart_cart/core/db/collections/shopping_list_entity.dart';
import 'package:smart_cart/core/services/supabase_client.dart';

class ShoppingListRepository {
  static final Map<int, String> _remoteIdByLocalId = <int, String>{};
  static final Map<String, int> _localIdByRemoteId = <String, int>{};
  static int _nextLocalId = 1;

  Future<int> save(ShoppingListEntity list, {bool forceCreate = false}) async {
    final userId = _currentUserIdOrThrow();
    final knownRemoteId = _remoteIdByLocalId[list.id];
    final shouldCreate = forceCreate || knownRemoteId == null;

    if (shouldCreate) {
      final inserted = await supabase
          .from('shopping_lists')
          .insert({
            'user_id': userId,
            'title': list.title,
            'budget': list.budget,
            'goal': list.goal,
            'household_size': list.shoppingDays,
          })
          .select('id')
          .single();

      final remoteId = inserted['id'] as String;
      await _replaceItems(remoteId, list);

      final localId = _ensureLocalId(remoteId);
      list.id = localId;
      return localId;
    }

    final remoteId = knownRemoteId;
    await supabase
        .from('shopping_lists')
        .update({
          'title': list.title,
          'budget': list.budget,
          'goal': list.goal,
          'household_size': list.shoppingDays,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
          .eq('id', remoteId);

    await _replaceItems(remoteId, list);
    return list.id;
  }

  Future<List<ShoppingListEntity>> getAll() async {
    final userId = _currentUserIdOrThrow();
    final rows = await supabase
        .from('shopping_lists')
        .select('id, title, budget, goal, household_size, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _listEntityFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<ShoppingListEntity?> getById(int id) async {
    final userId = _currentUserIdOrThrow();
    final remoteId = _remoteIdByLocalId[id];
    if (remoteId == null) return null;

    final listRow = await supabase
        .from('shopping_lists')
        .select('id, title, budget, goal, household_size, created_at')
        .eq('id', remoteId)
        .eq('user_id', userId)
        .maybeSingle();
    if (listRow == null) return null;

    final itemRows = await supabase
        .from('shopping_list_items')
        .select('custom_name, quantity, unit, estimated_price, checked, position')
        .eq('shopping_list_id', remoteId)
        .order('position', ascending: true);

    return _listEntityFromRow(
      Map<String, dynamic>.from(listRow),
      itemRows: itemRows.map((row) => Map<String, dynamic>.from(row)).toList(),
    );
  }

  Future<void> deleteById(int id) async {
    final remoteId = _remoteIdByLocalId[id];
    if (remoteId == null) return;

    await supabase.from('shopping_lists').delete().eq('id', remoteId);
    _remoteIdByLocalId.remove(id);
    _localIdByRemoteId.remove(remoteId);
  }

  String _currentUserIdOrThrow() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user. Please sign in again.');
    }
    return user.id;
  }

  int _ensureLocalId(String remoteId) {
    final existing = _localIdByRemoteId[remoteId];
    if (existing != null) return existing;

    final localId = _nextLocalId++;
    _localIdByRemoteId[remoteId] = localId;
    _remoteIdByLocalId[localId] = remoteId;
    return localId;
  }

  Future<void> _replaceItems(String remoteId, ShoppingListEntity list) async {
    await supabase
        .from('shopping_list_items')
        .delete()
        .eq('shopping_list_id', remoteId);

    if (list.items.isEmpty) return;

    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < list.items.length; i++) {
      final item = list.items[i];
      payload.add({
        'shopping_list_id': remoteId,
        'custom_name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'estimated_price': item.price,
        'checked': item.checked,
        'position': i,
      });
    }

    await supabase.from('shopping_list_items').insert(payload);
  }

  ShoppingListEntity _listEntityFromRow(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>> itemRows = const [],
  }) {
    final remoteId = row['id'] as String;
    final localId = _ensureLocalId(remoteId);
    final title = (row['title'] as String?)?.trim() ?? 'Shopping List';
    final store = _storeFromTitle(title);
    final createdAtRaw = row['created_at'] as String?;
    final createdAt = createdAtRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdAtRaw)?.toLocal() ?? DateTime.now();

    return ShoppingListEntity()
      ..id = localId
      ..title = title
      ..createdAt = createdAt
      ..store = store
      ..multipleStores = false
      ..selectedStores = store.isEmpty ? <String>[] : <String>[store]
      ..goal = row['goal'] as String?
      ..budget = (row['budget'] as num?)?.toDouble()
      ..shoppingDays = (row['household_size'] as num?)?.toInt() ?? 7
      ..items = itemRows.map((itemRow) {
        return ShoppingItemEntity()
          ..name = (itemRow['custom_name'] as String?)?.trim().isNotEmpty == true
              ? (itemRow['custom_name'] as String).trim()
              : 'Unnamed item'
          ..price = (itemRow['estimated_price'] as num?)?.toDouble() ?? 0
          ..quantity = ((itemRow['quantity'] as num?) ?? 1).toInt()
          ..checked = itemRow['checked'] as bool? ?? false
          ..unit = itemRow['unit'] as String?;
      }).toList(growable: false);
  }

  String _storeFromTitle(String title) {
    final index = title.indexOf('•');
    if (index <= 0) return title;
    return title.substring(0, index).trim();
  }
}
