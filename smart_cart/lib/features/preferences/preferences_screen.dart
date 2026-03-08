import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_cart/core/preferences.dart';
import 'package:smart_cart/core/db/product_cache_store.dart';
import 'package:smart_cart/features/planner/lidl_prices_api.dart';
import 'package:smart_cart/features/planner/plan_generator.dart';
import 'package:smart_cart/core/db/shopping_list_mapper.dart';
import 'package:smart_cart/core/db/shopping_list_repository.dart';
import 'package:smart_cart/features/shopping_list/shopping_list_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const String _lidlUrl =
      'https://raw.githubusercontent.com/Ciprien24/SmartCart_Backend/refs/heads/main/data/lidl/latest.json';
  static const Color _pageBackground = Color(0xFFF4F5F9);
  static const Color _headerBlue = Color(0xFF1800AD);
  static const Color _accentOrange = Color(0xFFFF751F);
  static const Color _textDark = Color(0xFF141414);
  static const Color _textMuted = Color(0xFF74788C);
  static const Color _divider = Color(0xFFE9ECF3);
  static const Color _error = Color(0xFFD64545);

  final List<String> _supermarkets = const ['Lidl', 'Kaufland'];
  double? _budget;
  String? _selectedSupermarket;
  List<String> _selectedMultipleStores = const [];
  int _shoppingDays = 7;
  bool _multipleStores = false;
  String? _budgetError;
  String? _supermarketError;
  String? _generateError;
  bool _isLoading = false;
  final ProductCacheStore _productCacheStore = ProductCacheStore();

  Future<void> _openBudgetSheet() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double selectedBudget = _budget ?? 200;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${selectedBudget.toStringAsFixed(0)} RON',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  Slider(
                    min: 50,
                    max: 1000,
                    divisions: 190,
                    activeColor: _accentOrange,
                    value: selectedBudget.clamp(50, 1000),
                    onChanged: (value) {
                      setModalState(() {
                        selectedBudget = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(selectedBudget),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _budgetError = 'Please enter a valid budget';
      });
      return;
    }

    setState(() {
      _budget = result;
      _budgetError = null;
    });
  }

  Future<void> _openSupermarketPicker() async {
    final result = await showModalBottomSheet<String>(
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
                  'Preferred Supermarket',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),
                ..._supermarkets.map(
                  (market) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      market,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    trailing: _selectedSupermarket == market
                        ? const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: _accentOrange,
                          )
                        : const Icon(
                            CupertinoIcons.circle,
                            color: _textMuted,
                          ),
                    onTap: () => Navigator.of(context).pop(market),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _selectedSupermarket = result;
      _supermarketError = null;
    });
  }

  Future<List<String>?> _openMultipleStoresPicker() async {
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final tempSelected = _selectedMultipleStores.toSet();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Multiple Stores',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._supermarkets.map((market) {
                      return CheckboxListTile(
                        value: tempSelected.contains(market),
                        activeColor: _accentOrange,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          market,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              tempSelected.add(market);
                            } else {
                              tempSelected.remove(market);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(tempSelected.toList()),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleMultipleStores(bool enabled) async {
    if (!enabled) {
      setState(() {
        _multipleStores = false;
      });
      return;
    }

    final result = await _openMultipleStoresPicker();
    if (!mounted) return;
    if (result == null || result.isEmpty) {
      setState(() {
        _multipleStores = false;
      });
      return;
    }

    final sorted = [...result]..sort();
    setState(() {
      _multipleStores = true;
      _selectedMultipleStores = sorted;
      if (_selectedSupermarket == null || !sorted.contains(_selectedSupermarket)) {
        _selectedSupermarket = sorted.first;
      }
      _supermarketError = null;
    });
  }

  Future<void> _showMultipleStoresInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Multiple Stores',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'When enabled, AI will compare prices across your selected '
                'supermarkets and prefer more budget-friendly alternatives while '
                'still matching your goals.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDurationPicker() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double selectedDays = _shoppingDays.toDouble();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shopping Period',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${selectedDays.toStringAsFixed(0)} days',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  Slider(
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: _accentOrange,
                    value: selectedDays.clamp(1, 30),
                    onChanged: (value) {
                      setModalState(() {
                        selectedDays = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(selectedDays.round()),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _shoppingDays = result;
    });
  }

  Future<void> _continue() async {
    setState(() {
      _budgetError = (_budget == null || _budget! <= 0)
          ? 'Please enter a valid budget'
          : null;
      _supermarketError = _selectedSupermarket == null
          ? 'Please choose a supermarket'
          : null;
      _generateError = null;
    });

    if (_budgetError != null || _supermarketError != null) return;

    final primaryStore = _selectedSupermarket!;
    final preferences = Preferences(
      budgetWeekly: _budget!,
      supermarket: primaryStore,
      supermarkets: _multipleStores ? _selectedMultipleStores : [primaryStore],
      goal: 'Maintain',
      shoppingDays: _shoppingDays,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await fetchLidlSnapshot(_lidlUrl);
      final products = snapshot.products;
      final fetchedAt = snapshot.fetchedAt;
      await _productCacheStore.saveCachedProducts('Lidl', fetchedAt, products);
      if (!mounted) return;
      final plan = PlanGenerator().generateFromProducts(preferences, products);
      final entity = ShoppingListMapper.toEntity(
        plan: plan,
        preferences: preferences,
        fetchedAt: fetchedAt,
      );
      final savedId = await ShoppingListRepository().save(entity);
      entity.id = savedId;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShoppingListScreen(
            plan: plan,
            preferences: preferences,
            savedListId: savedId,
            fetchedAt: fetchedAt,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _generateError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate list: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildValueCard({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 78,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: _accentOrange,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          Container(color: _pageBackground),
          _buildHeader(topInset),
          Positioned(
            top: 110 + topInset,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preferences',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Set Your Preferences',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildValueCard(
                      label: 'Budget',
                      value: _budget == null
                          ? 'Enter Budget'
                          : '${_budget!.toStringAsFixed(0)} RON',
                      onTap: _openBudgetSheet,
                    ),
                    if (_budgetError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 8),
                        child: Text(
                          _budgetError!,
                          style: const TextStyle(
                            color: _error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    _buildValueCard(
                      label: 'Supermarket',
                      value: _multipleStores && _selectedMultipleStores.isNotEmpty
                          ? _selectedMultipleStores.join(', ')
                          : (_selectedSupermarket ?? 'Choose Supermarket'),
                      onTap: _openSupermarketPicker,
                    ),
                    if (_supermarketError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 8),
                        child: Text(
                          _supermarketError!,
                          style: const TextStyle(
                            color: _error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    _buildValueCard(
                      label: 'Duration',
                      value: '$_shoppingDays days',
                      onTap: _openDurationPicker,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 78,
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Text(
                              'Multiple stores',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F3F8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: _showMultipleStoresInfo,
                                icon: const Icon(
                                  CupertinoIcons.question_circle_fill,
                                  size: 18,
                                  color: _textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CupertinoSwitch(
                              activeTrackColor: _accentOrange,
                              value: _multipleStores,
                              onChanged: _toggleMultipleStores,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_generateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 8),
                        child: Text(
                          _generateError!,
                          style: const TextStyle(
                            color: _error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Divider(color: _divider),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: _accentOrange,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.maybePop(context),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.back,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: _accentOrange,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isLoading ? null : _continue,
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.sparkles,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double topInset) {
    return Container(
      height: 150 + topInset,
      padding: EdgeInsets.fromLTRB(24, topInset + 2, 24, 0),
      decoration: const BoxDecoration(color: _headerBlue),
      child: const Align(
        alignment: Alignment(0, -0.45),
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
}
