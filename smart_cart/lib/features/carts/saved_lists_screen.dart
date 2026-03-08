import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_cart/core/db/collections/shopping_list_entity.dart';
import 'package:smart_cart/core/db/shopping_list_mapper.dart';
import 'package:smart_cart/core/db/shopping_list_repository.dart';
import 'package:smart_cart/features/shopping_list/shopping_list_screen.dart';

class SavedListsScreen extends StatefulWidget {
  final String store;

  const SavedListsScreen({super.key, required this.store});

  @override
  State<SavedListsScreen> createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen> {
  static const Color _pageBackground = Color(0xFFF4F5F9);
  static const Color _headerBlue = Color(0xFF1800AD);
  static const Color _accentOrange = Color(0xFFFF751F);
  static const Color _textDark = Color(0xFF141414);
  static const Color _textMuted = Color(0xFF74788C);

  final ShoppingListRepository _repository = ShoppingListRepository();
  List<ShoppingListEntity> _savedLists = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedLists();
  }

  Future<void> _loadSavedLists() async {
    final lists = await _repository.getAll();
    final filtered = lists.where((l) => l.store == widget.store).toList();
    if (!mounted) return;
    setState(() {
      _savedLists = filtered;
      _isLoading = false;
    });
  }

  Future<bool> _deleteSavedList(ShoppingListEntity entity) async {
    try {
      await _repository.deleteById(entity.id);
      if (!mounted) return false;
      setState(() {
        _savedLists.removeWhere((list) => list.id == entity.id);
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete list. Please try again.')),
      );
      return false;
    }
  }

  void _openSavedList(ShoppingListEntity entity) {
    final mapped = ShoppingListMapper.toDomain(entity);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(
          plan: mapped.plan,
          preferences: mapped.preferences,
          savedListId: entity.id,
          fetchedAt: entity.fetchedAt,
        ),
      ),
    );
  }

  String _formatCreatedDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final yy = (value.year % 100).toString().padLeft(2, '0');
    return '$d/$m/$yy';
  }

  String _storeLogoFor(String store) {
    switch (store) {
      case 'Kaufland':
        return 'lib/app/assets/kaufland.png';
      case 'Lidl':
      default:
        return 'lib/app/assets/lidl.png';
    }
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.store} Lists',
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _accentOrange,
                              ),
                            )
                          : _savedLists.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              itemBuilder: (context, index) {
                                final list = _savedLists[index];
                                return Dismissible(
                                  key: ValueKey(list.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) => _deleteSavedList(list),
                                  background: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD64545),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    child: const Icon(
                                      CupertinoIcons.delete,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  child: _SavedListCard(
                                    createdDate: _formatCreatedDate(
                                      list.createdAt,
                                    ),
                                    logoPath: _storeLogoFor(widget.store),
                                    onTap: () => _openSavedList(list),
                                  ),
                                );
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemCount: _savedLists.length,
                            ),
                    ),
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

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'No saved shopping lists for this store yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: _textMuted,
        ),
      ),
    );
  }
}

class _SavedListCard extends StatelessWidget {
  static const Color _textDark = Color(0xFF141414);
  static const Color _accentOrange = Color(0xFFFF751F);

  final String createdDate;
  final String logoPath;
  final VoidCallback onTap;

  const _SavedListCard({
    required this.createdDate,
    required this.logoPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Image.asset(logoPath, fit: BoxFit.contain),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      createdDate,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
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
}
