import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:smart_cart/core/db/collections/shopping_item_entity.dart';
import 'package:smart_cart/core/db/product_cache_store.dart';
import 'package:smart_cart/core/db/shopping_list_repository.dart';
import 'package:smart_cart/core/preferences.dart';
import 'package:smart_cart/core/product.dart';
import 'package:smart_cart/core/shopping_item.dart';
import 'package:smart_cart/core/weekly_plan.dart';

class ShoppingListScreen extends StatefulWidget {
  final WeeklyPlan plan;
  final Preferences preferences;
  final int? savedListId;
  final String? fetchedAt;

  const ShoppingListScreen({
    super.key,
    required this.plan,
    required this.preferences,
    this.savedListId,
    this.fetchedAt,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  static const Color _pageBackground = Color(0xFFF4F5F9);
  static const Color _headerBlue = Color(0xFF1800AD);
  static const Color _accentOrange = Color(0xFFFF751F);
  static const Color _textDark = Color(0xFF141414);
  static const Color _textMuted = Color(0xFF74788C);

  final ShoppingListRepository _repository = ShoppingListRepository();
  final ProductCacheStore _productCacheStore = ProductCacheStore();
  late List<ShoppingItem> _items;
  List<Product>? _cachedProducts;
  bool _isLoadingCachedProducts = false;
  Timer? _saveDebounce;
  bool _isSaving = false;
  final Set<ShoppingItem> _completingItems = <ShoppingItem>{};
  final Set<ShoppingItem> _deletingItems = <ShoppingItem>{};
  bool _showCompleted = false;
  _ShoppingTab _activeTab = _ShoppingTab.list;
  int _selectedRecipeDay = 1;
  bool _showRecipeDayPicker = false;

  @override
  void initState() {
    super.initState();
    _items = List<ShoppingItem>.from(widget.plan.items);
    _loadSavedItems();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  String _formatRon(double value) => '${value.toStringAsFixed(2)} RON';

  String _formatUpdatedAt(String? fetchedAt) {
    if (fetchedAt == null || fetchedAt.isEmpty) {
      return 'Unknown';
    }

    final parsed = DateTime.tryParse(fetchedAt);
    if (parsed == null) return fetchedAt;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = (local.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  String? _storeLogoFor(String store) {
    switch (store) {
      case 'Kaufland':
        return 'lib/app/assets/kaufland.png';
      case 'Lidl':
        return 'lib/app/assets/lidl.png';
      default:
        return null;
    }
  }

  String _displayNameFor(ShoppingItem item) {
    return item.product.name.replaceFirst(RegExp(r'^\s*-\s*'), '').trim();
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) return true;
    }
    return false;
  }

  _NutritionInfo _nutritionInfoFor(ShoppingItem item) {
    final name = item.product.name.toLowerCase();
    final category = item.product.category.toLowerCase();

    if (_containsAny(name, const ['pui', 'chicken', 'piept', 'tuna', 'ton'])) {
      return const _NutritionInfo(
        protein: 24,
        carbs: 5,
        fats: 5,
        fiber: 0,
        calories: 165,
        description:
            'High-quality lean protein option, useful for muscle support and satiety.',
      );
    }
    if (_containsAny(name, const ['ovaz', 'oats', 'fasole', 'linte', 'naut'])) {
      return const _NutritionInfo(
        protein: 10,
        carbs: 30,
        fats: 5,
        fiber: 8,
        calories: 220,
        description:
            'Complex carbs and fiber help with sustained energy and digestion.',
      );
    }
    if (_containsAny(name, const ['avocado', 'nuci', 'migdale', 'ulei', 'olive'])) {
      return const _NutritionInfo(
        protein: 3,
        carbs: 6,
        fats: 20,
        fiber: 4,
        calories: 230,
        description:
            'Rich in unsaturated fats that can support heart and hormonal health.',
      );
    }
    if (_containsAny(category, const ['fruit', 'fruct', 'vegetable', 'legume'])) {
      return const _NutritionInfo(
        protein: 2,
        carbs: 12,
        fats: 1,
        fiber: 4,
        calories: 80,
        description:
            'Fresh produce tends to provide vitamins, minerals, and useful dietary fiber.',
      );
    }
    return const _NutritionInfo(
      protein: 6,
      carbs: 14,
      fats: 6,
      fiber: 2,
      calories: 140,
      description:
          'Balanced placeholder nutrition profile. AI nutrition estimates will refine this.',
    );
  }

  Future<void> _showProductDetails(ShoppingItem item) async {
    final displayName = _displayNameFor(item);
    final info = _nutritionInfoFor(item);
    final mealGroup = _mealBucketFor(item);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        Widget macroTile(String label, int value, Color color) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$value g',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Approx. ${info.calories} kcal per serving',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'List group: $mealGroup',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _textMuted,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Store category: ${item.product.category}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    macroTile('Protein', info.protein, const Color(0xFFFBE2CF)),
                    const SizedBox(width: 8),
                    macroTile('Carbs', info.carbs, const Color(0xFFDDEAFE)),
                    const SizedBox(width: 8),
                    macroTile('Fats', info.fats, const Color(0xFFF9F1C9)),
                    if (info.fiber > 0) ...[
                      const SizedBox(width: 8),
                      macroTile('Fiber', info.fiber, const Color(0xFFDDF6E8)),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  info.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<ShoppingItem>> _groupedItems() {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in _items.where((item) => !item.checked)) {
      final group = _mealBucketFor(item);
      grouped.putIfAbsent(group, () => <ShoppingItem>[]).add(item);
    }
    final ordered = <String, List<ShoppingItem>>{};
    const order = ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Misc'];
    for (final key in order) {
      if (grouped.containsKey(key)) {
        ordered[key] = grouped[key]!;
      }
    }
    for (final entry in grouped.entries) {
      if (!ordered.containsKey(entry.key)) {
        ordered[entry.key] = entry.value;
      }
    }
    return ordered;
  }

  List<ShoppingItem> get _completedItems =>
      _items.where((item) => item.checked).toList(growable: false);

  String _mealBucketFor(ShoppingItem item) {
    final name = item.product.name.toLowerCase();
    final category = item.product.category.toLowerCase();
    final text = '$name $category';

    if (_containsAny(text, const [
      'chips',
      'snack',
      'biscuit',
      'cookie',
      'ciocol',
      'chocolate',
      'candy',
      'cola',
      'suc',
      'juice',
      'bar',
      'nuci',
      'nuts',
    ])) {
      return 'Snacks';
    }

    if (_containsAny(text, const [
      'ovaz',
      'oats',
      'cereal',
      'musli',
      'lapte',
      'milk',
      'iaurt',
      'yogurt',
      'oua',
      'egg',
      'paine',
      'bread',
      'croissant',
      'cafea',
      'coffee',
      'ceai',
      'tea',
      'gem',
      'jam',
      'miere',
      'honey',
      'patiserie',
    ])) {
      return 'Breakfast';
    }

    if (_containsAny(text, const [
      'pui',
      'chicken',
      'curcan',
      'turkey',
      'vita',
      'beef',
      'porc',
      'fish',
      'peste',
      'ton',
      'tuna',
      'somon',
      'salmon',
      'orez',
      'rice',
      'paste',
      'pasta',
      'supa',
      'soup',
      'fasole',
      'linte',
      'naut',
      'congelat',
    ])) {
      return 'Lunch';
    }

    if (_containsAny(text, const [
      'legume',
      'salata',
      'rosii',
      'tomato',
      'castrav',
      'broccoli',
      'spanac',
      'spinach',
      'ardei',
      'fruct',
      'apple',
      'banana',
      'avocado',
      'branza',
      'cheese',
      'mozzarella',
      'telemea',
    ])) {
      return 'Dinner';
    }

    return 'Misc';
  }

  double get _total => _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  void _increase(ShoppingItem item) {
    setState(() => item.quantity += 1);
    _scheduleSave();
  }

  void _decrease(ShoppingItem item) {
    if (item.quantity <= 1) return;
    setState(() => item.quantity -= 1);
    _scheduleSave();
  }

  void _toggleChecked(ShoppingItem item) {
    if (item.checked) {
      setState(() => item.checked = false);
      _scheduleSave();
      return;
    }

    setState(() {
      _completingItems.add(item);
    });

    Future.delayed(const Duration(milliseconds: 760), () {
      if (!mounted) return;
      setState(() {
        _completingItems.remove(item);
        item.checked = true;
      });
      _scheduleSave();
    });
  }

  void _deleteItem(ShoppingItem item) {
    if (_deletingItems.contains(item)) return;
    setState(() {
      _deletingItems.add(item);
    });

    Future.delayed(const Duration(milliseconds: 760), () {
      if (!mounted) return;
      setState(() {
        _deletingItems.remove(item);
        _items.remove(item);
      });
      _scheduleSave();
    });
  }

  Future<void> _showReplaceSheet(ShoppingItem currentItem) async {
    setState(() {
      _isLoadingCachedProducts = true;
    });
    _cachedProducts ??= await _productCacheStore.getCachedProducts('Lidl');
    if (!mounted) return;
    setState(() {
      _isLoadingCachedProducts = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _ReplaceItemBottomSheet(
          currentItem: currentItem,
          allProducts: _cachedProducts ?? const [],
          onSelect: (candidate) {
            _replaceItem(currentItem, candidate);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  void _replaceItem(ShoppingItem currentItem, Product replacement) {
    final index = _items.indexOf(currentItem);
    if (index < 0) return;

    final updatedItem = ShoppingItem(
      product: replacement,
      quantity: currentItem.quantity,
      checked: currentItem.checked,
    );

    setState(() {
      _items[index] = updatedItem;
    });
    _scheduleSave();

    final overBy = _total - widget.preferences.budgetWeekly;
    if (overBy > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Over budget by ${_formatRon(overBy)}')),
      );
    }
  }

  void _scheduleSave() {
    if (widget.savedListId == null) return;
    _saveDebounce?.cancel();
    setState(() {
      _isSaving = true;
    });
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _persistEdits();
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    });
  }

  Future<void> _persistEdits() async {
    final id = widget.savedListId;
    if (id == null) return;

    final entity = await _repository.getById(id);
    if (entity == null) return;

    entity.items = _items.map((item) {
      return ShoppingItemEntity()
        ..name = item.product.name
        ..price = item.product.price
        ..quantity = item.quantity
        ..checked = item.checked
        ..category = item.product.category;
    }).toList();

    await _repository.save(entity);
  }

  Future<void> _loadSavedItems() async {
    final id = widget.savedListId;
    if (id == null) return;

    final entity = await _repository.getById(id);
    if (entity == null || !mounted) return;

    setState(() {
      _items = entity.items.map((item) {
        final unitSuffix = (item.unit == null || item.unit!.isEmpty)
            ? ''
            : '-${item.unit}';
        return ShoppingItem(
          product: Product(
            id: '${item.name}$unitSuffix',
            name: item.name,
            category: item.category ?? 'Other',
            price: item.price,
            store: entity.store ?? widget.preferences.supermarket,
          ),
          quantity: item.quantity,
          checked: item.checked,
        );
      }).toList(growable: true);
    });
  }

  Widget _buildHeader(double topInset) {
    return Container(
      height: 128 + topInset,
      padding: EdgeInsets.fromLTRB(24, topInset + 2, 24, 0),
      decoration: const BoxDecoration(color: _headerBlue),
      child: const Align(
        alignment: Alignment(0, -0.72),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Image(
                image: AssetImage('lib/app/assets/logo_smart_cart.png'),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'SmartCart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String? logoPath) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: logoPath == null
                    ? const Icon(
                        CupertinoIcons.shopping_cart,
                        color: _textMuted,
                      )
                    : Image.asset(logoPath, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.preferences.supermarket,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
              _buildQuestionBubble(onTap: _showAiReasoningSheet, size: 24),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDDF6E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Prices Updated: ${_formatUpdatedAt(widget.fetchedAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B9E45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiReasoningSheet() async {
    final stores = widget.preferences.selectedSupermarkets;
    final storesText = stores.join(', ');
    final budgetText = widget.preferences.budgetWeekly.toStringAsFixed(0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How AI chose this list',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),
                _sheetInfoPill('Budget: $budgetText RON'),
                const SizedBox(height: 8),
                _sheetInfoPill('Period: ${widget.preferences.shoppingDays} days'),
                const SizedBox(height: 8),
                _sheetInfoPill('Stores: $storesText'),
                const SizedBox(height: 14),
                const Text(
                  'AI reasoning placeholder: items were selected to stay close to your budget, fit your selected time period, and prioritize practical staples from the selected store(s). As AI planning improves, this section will include more detailed trade-offs, nutrition decisions, and replacement logic.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetInfoPill(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _textMuted,
        ),
      ),
    );
  }

  Widget _buildQuestionBubble({required VoidCallback onTap, double size = 28}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE4E8F1)),
        ),
        child: Icon(
          CupertinoIcons.question,
          size: size <= 24 ? 13 : 16,
          color: _textMuted,
        ),
      ),
    );
  }

  Future<void> _showRecipeReasoningSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How AI chose these meals',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),
                _sheetInfoPill('Day: $_selectedRecipeDay of $_recipeDaysCount'),
                const SizedBox(height: 8),
                _sheetInfoPill('Goal: ${widget.preferences.goal}'),
                const SizedBox(height: 8),
                _sheetInfoPill(
                  'Period: ${widget.preferences.shoppingDays} days',
                ),
                const SizedBox(height: 14),
                const Text(
                  'AI meal reasoning placeholder: recipes are currently demo suggestions. In a later update, this section will explain nutrition targets, budget constraints, ingredient reuse across days, and why each meal was selected.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemGroup(List<ShoppingItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index += 1)
            _buildItemCard(
              items[index],
              groupedStyle: true,
              isFirstInGroup: index == 0,
              isLastInGroup: index == items.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    ShoppingItem item, {
    bool groupedStyle = false,
    bool isFirstInGroup = false,
    bool isLastInGroup = false,
  }) {
    final displayName = _displayNameFor(item);
    final isCompleting = _completingItems.contains(item);
    final isDeleting = _deletingItems.contains(item);
    final isAnimatingOut = isCompleting || isDeleting;
    final rowBorderRadius = groupedStyle
        ? BorderRadius.only(
            topLeft: isFirstInGroup ? const Radius.circular(22) : Radius.zero,
            topRight: isFirstInGroup ? const Radius.circular(22) : Radius.zero,
            bottomLeft: isLastInGroup ? const Radius.circular(22) : Radius.zero,
            bottomRight: isLastInGroup ? const Radius.circular(22) : Radius.zero,
          )
        : BorderRadius.circular(22);
    final deleteActionBorderRadius = groupedStyle
        ? BorderRadius.only(
            topRight: isFirstInGroup ? const Radius.circular(22) : Radius.zero,
            bottomRight: isLastInGroup ? const Radius.circular(22) : Radius.zero,
          )
        : const BorderRadius.only(
            topRight: Radius.circular(22),
            bottomRight: Radius.circular(22),
          );

    final itemWidget = Slidable(
        key: ObjectKey(item),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.34,
          children: [
            CustomSlidableAction(
              onPressed: (_) {
                if (isAnimatingOut) return;
                _showReplaceSheet(item);
              },
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFF2B6EEB),
              borderRadius: BorderRadius.zero,
              child: const Icon(
                CupertinoIcons.arrow_2_circlepath,
                color: Colors.white,
                size: 28,
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _deleteItem(item),
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFFD64545),
              borderRadius: deleteActionBorderRadius,
              child: const Icon(
                CupertinoIcons.delete,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onLongPress: () {
            if (isAnimatingOut) return;
            _showProductDetails(item);
          },
          child: AnimatedScale(
            scale: isAnimatingOut ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: AnimatedSlide(
              offset: isCompleting
                  ? const Offset(0.65, 0)
                  : isDeleting
                  ? const Offset(-0.65, 0)
                  : Offset.zero,
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: isAnimatingOut ? 0 : 1,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeIn,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: isCompleting
                        ? const Color(0xFF9EF2BF)
                        : isDeleting
                        ? const Color(0xFFFFC6C6)
                        : groupedStyle
                        ? Colors.transparent
                        : Colors.white,
                    borderRadius: rowBorderRadius,
                    border: groupedStyle && !isLastInGroup && !isAnimatingOut
                        ? const Border(
                            bottom: BorderSide(color: Color(0xFFE8EDF4)),
                          )
                        : null,
                    boxShadow: groupedStyle
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (isAnimatingOut) return;
                    _toggleChecked(item);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.checked ? _accentOrange : Colors.transparent,
                      border: Border.all(
                        color: item.checked
                            ? _accentOrange
                            : const Color(0xFFBAC1CF),
                        width: 1.5,
                      ),
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: item.checked || isCompleting || isDeleting ? 1 : 0,
                      child: Icon(
                        isDeleting
                            ? CupertinoIcons.delete
                            : CupertinoIcons.check_mark,
                        color: Colors.black,
                        size: isDeleting ? 14 : 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textDark.withValues(
                            alpha: item.checked ? 0.55 : 1,
                          ),
                          decoration: item.checked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.black,
                          decorationThickness: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatRon(item.lineTotal),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              onPressed: isAnimatingOut
                                  ? null
                                  : () => _decrease(item),
                              icon: const Icon(
                                CupertinoIcons.minus,
                                size: 12,
                                color: _accentOrange,
                              ),
                            ),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              onPressed: isAnimatingOut
                                  ? null
                                  : () => _increase(item),
                              icon: const Icon(
                                CupertinoIcons.plus,
                                size: 12,
                                color: _accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    if (groupedStyle) return itemWidget;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: itemWidget,
    );
  }

  int get _recipeDaysCount {
    final days = widget.preferences.shoppingDays;
    return days < 1 ? 1 : days;
  }

  String _ingredientPreviewForDay(int day) {
    final allActiveNames = _items
        .where((item) => !item.checked)
        .map((item) => _displayNameFor(item))
        .toList(growable: false);

    if (allActiveNames.isEmpty) {
      return 'Built from your generated shopping list';
    }

    final start = (day - 1) % allActiveNames.length;
    final rotated = <String>[];
    for (var i = 0; i < allActiveNames.length; i += 1) {
      rotated.add(allActiveNames[(start + i) % allActiveNames.length]);
    }

    return rotated.take(4).join(' • ');
  }

  Map<String, List<_RecipePlaceholder>> _buildPlaceholderRecipesByMeal({
    required int day,
  }) {
    final ingredientPreview = _ingredientPreviewForDay(day);
    final isEvenDay = day % 2 == 0;
    final breakfastTitle = isEvenDay ? 'Greek Yogurt Power Bowl' : 'Protein Oats Bowl';
    final lunchTitle = isEvenDay ? 'Chicken Rice Plate' : 'Protein Bowl';
    final dinnerTitle = isEvenDay ? 'Salmon Veggie Plate' : 'Veggie Pasta';
    final snackTitle = isEvenDay ? 'Crunchy Nuts Mix' : 'Yogurt Fruit Snack';

    return {
      'Breakfast': [
        _RecipePlaceholder(
          title: breakfastTitle,
          subtitle: 'Quick morning meal',
          duration: '15 min',
          difficulty: 'Easy',
          calories: 420,
          description:
              'Day $day placeholder breakfast. This will be personalized from your list and nutrition goals.',
          mealInfo:
              'A balanced breakfast placeholder focused on slow carbs and protein for sustained energy.',
          ingredientsPreview: ingredientPreview,
        ),
      ],
      'Lunch': [
        _RecipePlaceholder(
          title: lunchTitle,
          subtitle: 'Balanced midday option',
          duration: '25 min',
          difficulty: 'Medium',
          calories: 560,
          description:
              'Day $day placeholder lunch. Future AI will optimize ingredients, portions, and prices across selected stores.',
          mealInfo:
              'Lunch placeholder with a protein base, vegetables, and a carb side for better satiety.',
          ingredientsPreview: ingredientPreview,
        ),
      ],
      'Dinner': [
        _RecipePlaceholder(
          title: dinnerTitle,
          subtitle: 'Light dinner option',
          duration: '35 min',
          difficulty: 'Medium',
          calories: 510,
          description:
              'Day $day placeholder dinner. AI will later adapt this using your available products and preferences.',
          mealInfo:
              'Dinner placeholder designed to be lighter while still covering key macro needs.',
          ingredientsPreview: ingredientPreview,
        ),
      ],
      'Snacks': [
        _RecipePlaceholder(
          title: snackTitle,
          subtitle: 'Simple snack idea',
          duration: '10 min',
          difficulty: 'Easy',
          calories: 230,
          description:
              'Day $day placeholder snack. AI will later suggest budget-friendly snack alternatives.',
          mealInfo:
              'Snack placeholder centered on a quick, practical option between main meals.',
          ingredientsPreview: ingredientPreview,
        ),
      ],
    };
  }

  Widget _buildRecipesSection({bool includeTitle = true}) {
    final recipesByMeal = _buildPlaceholderRecipesByMeal(day: _selectedRecipeDay);
    const mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        if (includeTitle)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Recipes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
          ),
        const SizedBox(height: 2),
        _buildRecipeDaySelector(),
        const SizedBox(height: 8),
        for (final meal in mealOrder) ...[
          if ((recipesByMeal[meal] ?? const []).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      meal,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                  ),
                  if (meal == 'Breakfast')
                    _buildQuestionBubble(
                      onTap: _showRecipeReasoningSheet,
                      size: 24,
                    ),
                ],
              ),
            ),
          ...(recipesByMeal[meal] ?? const []).map(
            (recipe) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onLongPress: () => _showRecipeDetails(recipe, meal),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recipe.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _recipePill(
                            recipe.duration,
                            type: _RecipePillType.duration,
                          ),
                          const SizedBox(width: 8),
                          _recipePill(
                            recipe.difficulty,
                            type: _RecipePillType.difficulty,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        recipe.description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.ingredientsPreview,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecipeDaySelector() {
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _showRecipeDayPicker ? 230 : 0,
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: _showRecipeDayPicker ? 6 : 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE4E8F1)),
            ),
            child: ClipRect(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _showRecipeDayPicker ? 1 : 0,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recipeDaysCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => _buildRecipeDayChip(day: index + 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showRecipeDayPicker = !_showRecipeDayPicker;
              });
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE4E8F1)),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 17,
                color: _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeDayChip({required int day}) {
    final isActive = day == _selectedRecipeDay;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRecipeDay = day;
          _showRecipeDayPicker = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? _accentOrange : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? _accentOrange : const Color(0xFFE4E8F1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'Day $day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isActive ? Colors.white : _textMuted,
          ),
        ),
      ),
    );
  }

  Widget _recipePill(String text, {required _RecipePillType type}) {
    final bgColor = _recipePillColor(type: type, text: text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _textMuted,
        ),
      ),
    );
  }

  Color _recipePillColor({
    required _RecipePillType type,
    required String text,
  }) {
    const pastelGreen = Color(0xFFDDF6E8);
    const pastelYellow = Color(0xFFF9F1C9);
    const pastelRed = Color(0xFFFBE2E2);

    if (type == _RecipePillType.difficulty) {
      final value = text.toLowerCase();
      if (value.contains('easy')) return pastelGreen;
      if (value.contains('medium')) return pastelYellow;
      if (value.contains('hard')) return pastelRed;
      return pastelYellow;
    }

    final minutes = _durationToMinutes(text);
    if (minutes <= 20) return pastelGreen;
    if (minutes <= 60) return pastelYellow;
    return pastelRed;
  }

  int _durationToMinutes(String text) {
    final value = text.toLowerCase();
    final numbers = RegExp(r'\d+')
        .allMatches(value)
        .map((m) => int.tryParse(m.group(0) ?? '') ?? 0)
        .toList();
    if (numbers.isEmpty) return 30;

    final hasHour = value.contains('hour') || value.contains('h');
    final hasMin = value.contains('min');

    if (hasHour && hasMin && numbers.length >= 2) {
      return (numbers[0] * 60) + numbers[1];
    }
    if (hasHour) {
      return numbers[0] * 60;
    }
    return numbers[0];
  }

  Future<void> _showRecipeDetails(
    _RecipePlaceholder recipe,
    String mealGroup,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recipe.calories} kcal per serving',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _sheetPill('Meal: $mealGroup'),
                    _recipePill(
                      recipe.duration,
                      type: _RecipePillType.duration,
                    ),
                    _recipePill(
                      recipe.difficulty,
                      type: _RecipePillType.difficulty,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  recipe.mealInfo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  recipe.ingredientsPreview,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _textMuted,
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTabButton('Shopping List', _ShoppingTab.list),
          _buildTabButton('Recipes', _ShoppingTab.recipes),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, _ShoppingTab tab) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isActive ? _textDark : _textMuted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final grouped = _groupedItems();
    final completedItems = _completedItems;
    final logoPath = _storeLogoFor(widget.preferences.supermarket);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _saveDebounce?.cancel();
        unawaited(_persistEdits());
      },
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: Stack(
          children: [
            Container(color: _pageBackground),
            _buildHeader(topInset),
            Positioned(
              top: 92 + topInset,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopTabs(),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 700),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final showingShopping =
                              _activeTab == _ShoppingTab.list &&
                              child.key == const ValueKey('shopping_tab');
                          final showingRecipes =
                              _activeTab == _ShoppingTab.recipes &&
                              child.key == const ValueKey('recipes_tab');
                          final beginX = (showingShopping || !showingRecipes)
                              ? -0.06
                              : 0.06;
                          final offset = Tween<Offset>(
                            begin: Offset(beginX, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        },
                        child: _activeTab == _ShoppingTab.list
                            ? KeyedSubtree(
                                key: const ValueKey('shopping_tab'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSummaryCard(logoPath),
                                    if (_isLoadingCachedProducts) ...[
                                      const SizedBox(height: 10),
                                      const LinearProgressIndicator(
                                        color: _accentOrange,
                                        backgroundColor: Color(0xFFE9ECF3),
                                        minHeight: 2,
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    for (final entry in grouped.entries) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          bottom: 10,
                                          top: 6,
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _textDark,
                                          ),
                                        ),
                                      ),
                                      _buildItemGroup(entry.value),
                                      const SizedBox(height: 12),
                                    ],
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0F000000),
                                            blurRadius: 12,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ExpansionTile(
                                        key: ValueKey(completedItems.length),
                                        title: Text(
                                          'Completed (${completedItems.length})',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: _textMuted,
                                          ),
                                        ),
                                        initiallyExpanded: _showCompleted,
                                        onExpansionChanged: (value) {
                                          setState(() {
                                            _showCompleted = value;
                                          });
                                        },
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(
                                              12,
                                              4,
                                              12,
                                              8,
                                            ),
                                        collapsedShape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        children: completedItems.isEmpty
                                            ? const [
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 10,
                                                  ),
                                                  child: Text(
                                                    'No checked items yet.',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ]
                                            : [
                                                _buildItemGroup(completedItems),
                                              ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('recipes_tab'),
                                child: _buildRecipesSection(includeTitle: false),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_activeTab == _ShoppingTab.list)
              Positioned(
                right: 20,
                bottom: 20 + MediaQuery.of(context).padding.bottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatRon(_total),
                        style: const TextStyle(
                          color: _accentOrange,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (widget.savedListId != null) const SizedBox(height: 2),
                      if (widget.savedListId != null)
                        Text(
                          _isSaving ? 'Saving...' : 'Saved',
                          style: TextStyle(
                            color: _isSaving
                                ? const Color(0xFFF2B705)
                                : const Color(0xFF1B9E45),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ShoppingTab { list, recipes }

enum _RecipePillType { duration, difficulty }

class _NutritionInfo {
  const _NutritionInfo({
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.calories,
    required this.description,
  });

  final int protein;
  final int carbs;
  final int fats;
  final int fiber;
  final int calories;
  final String description;
}

class _RecipePlaceholder {
  const _RecipePlaceholder({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.difficulty,
    required this.calories,
    required this.description,
    required this.mealInfo,
    required this.ingredientsPreview,
  });

  final String title;
  final String subtitle;
  final String duration;
  final String difficulty;
  final int calories;
  final String description;
  final String mealInfo;
  final String ingredientsPreview;
}

class _ReplaceItemBottomSheet extends StatefulWidget {
  const _ReplaceItemBottomSheet({
    required this.currentItem,
    required this.allProducts,
    required this.onSelect,
  });

  final ShoppingItem currentItem;
  final List<Product> allProducts;
  final ValueChanged<Product> onSelect;

  @override
  State<_ReplaceItemBottomSheet> createState() =>
      _ReplaceItemBottomSheetState();
}

class _ReplaceItemBottomSheetState extends State<_ReplaceItemBottomSheet> {
  static const Color _textDark = Color(0xFF141414);
  static const Color _textMuted = Color(0xFF74788C);
  static const Color _accentOrange = Color(0xFFFF751F);

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _onlyCheaperOrEqual = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _candidates() {
    final currentProduct = widget.currentItem.product;
    final category = currentProduct.category.trim();

    final filtered = widget.allProducts.where((product) {
      if (product.store.toLowerCase() != 'lidl') return false;

      final sameCategory = category.isEmpty || product.category == category;
      if (!sameCategory) return false;

      final sameProduct =
          product.id == currentProduct.id ||
          product.name.toLowerCase() == currentProduct.name.toLowerCase();
      if (sameProduct) return false;

      if (_onlyCheaperOrEqual && product.price > currentProduct.price) {
        return false;
      }

      if (_searchText.trim().isNotEmpty &&
          !product.name.toLowerCase().contains(_searchText.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) => a.price.compareTo(b.price));
    return filtered;
  }

  String _unitForProduct(Product product) {
    if (product.id.startsWith('${product.name}-')) {
      final unit = product.id.substring(product.name.length + 1);
      if (unit.isNotEmpty) return unit;
    }
    return 'unit';
  }

  @override
  Widget build(BuildContext context) {
    final results = _candidates();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Replace item',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchText = value),
              decoration: InputDecoration(
                hintText: 'Search products',
                hintStyle: const TextStyle(
                  color: _textMuted,
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(
                  CupertinoIcons.search,
                  color: _textMuted,
                ),
                filled: true,
                fillColor: const Color(0xFFF2F3F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SwitchListTile(
              value: _onlyCheaperOrEqual,
              onChanged: (value) => setState(() => _onlyCheaperOrEqual = value),
              title: const Text(
                'Only show items cheaper or equal',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              activeThumbColor: _accentOrange,
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${results.length} options',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: results.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No results',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = results[index];
                        return Material(
                          color: const Color(0xFFF7F8FB),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelect(product),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _textDark,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          product.category,
                                          style: const TextStyle(
                                            color: _textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${product.price.toStringAsFixed(2)} RON / ${_unitForProduct(product)}',
                                    style: const TextStyle(
                                      color: _accentOrange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
