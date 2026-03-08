import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_cart/features/carts/saved_lists_screen.dart';
import 'package:smart_cart/features/preferences/preferences_screen.dart';
import 'package:smart_cart/features/profile/user_profile_screen.dart';

class CartsScreen extends StatelessWidget {
  const CartsScreen({super.key});

  static const Color _pageBackground = Color(0xFFF4F5F9);
  static const Color _headerBlue = Color(0xFF1800AD);
  static const Color _accentOrange = Color(0xFFFF751F);
  static const Color _textDark = Color(0xFF141414);

  static const List<({String name, String asset})> _stores = [
    (name: 'Lidl', asset: 'lib/app/assets/lidl.png'),
    (name: 'Kaufland', asset: 'lib/app/assets/kaufland.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w900),
        child: Stack(
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
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supermarkets',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SupermarketGroup(
                        stores: _stores,
                        onTapStore: (store) => _openStore(context, store),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.center,
                        child: _NewListPill(
                          onTap: () => _openPreferences(context),
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
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  tooltip: 'Menu',
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) {
                    if (value == 'profile') {
                      _openProfile(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Text(
                        'User page',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ],
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.chevron_up,
                      color: _textDark,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserProfileScreen(),
      ),
    );
  }

  void _openPreferences(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PreferencesScreen(),
      ),
    );
  }

  void _openStore(BuildContext context, String store) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SavedListsScreen(store: store)),
    );
  }

  Widget _buildHeader(double topInset) {
    return Container(
      height: 150 + topInset,
      padding: EdgeInsets.fromLTRB(24, topInset + 2, 24, 0),
      decoration: const BoxDecoration(color: _headerBlue),
      child: Align(
        alignment: const Alignment(0, -0.45),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                'lib/app/assets/logo_smart_cart.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
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

class _SupermarketGroup extends StatelessWidget {
  final List<({String name, String asset})> stores;
  final ValueChanged<String> onTapStore;

  const _SupermarketGroup({required this.stores, required this.onTapStore});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Column(
          children: [
            for (var i = 0; i < stores.length; i += 1)
              _SupermarketRow(
                name: stores[i].name,
                assetPath: stores[i].asset,
                isFirst: i == 0,
                isLast: i == stores.length - 1,
                onTap: () => onTapStore(stores[i].name),
              ),
          ],
        ),
      ),
    );
  }
}

class _SupermarketRow extends StatelessWidget {
  final String name;
  final String assetPath;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _SupermarketRow({
    required this.name,
    required this.assetPath,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rowRadius = BorderRadius.only(
      topLeft: isFirst ? const Radius.circular(22) : Radius.zero,
      topRight: isFirst ? const Radius.circular(22) : Radius.zero,
      bottomLeft: isLast ? const Radius.circular(22) : Radius.zero,
      bottomRight: isLast ? const Radius.circular(22) : Radius.zero,
    );

    return InkWell(
      borderRadius: rowRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          border: !isLast
              ? const Border(bottom: BorderSide(color: Color(0xFFE8EDF4)))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 54,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  CupertinoIcons.shopping_cart,
                  size: 18,
                  color: CartsScreen._textDark,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: CartsScreen._textDark,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CartsScreen._accentOrange,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewListPill extends StatelessWidget {
  final VoidCallback onTap;

  const _NewListPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: CartsScreen._accentOrange),
          ),
          child: const Text(
            '+ New list',
            style: TextStyle(
              color: CartsScreen._accentOrange,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
