import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_cart/core/services/supabase_client.dart';
import 'package:smart_cart/features/carts/saved_lists_screen.dart';
import 'package:smart_cart/features/preferences/preferences_screen.dart';
import 'package:smart_cart/features/profile/user_profile_screen.dart';

typedef _StoreEntry = ({String name, String asset});

class CartsScreen extends StatelessWidget {
  const CartsScreen({super.key});

  static const Color _pageBackground = Color(0xFFF4F5F9);
  static const Color _headerBlue = Color(0xFF1800AD);
  static const Color _accentOrange = Color(0xFFFF751F);
  static const Color _textDark = Color(0xFF141414);
  static const Color _textMuted = Color(0xFF74788C);

  static const List<_StoreEntry> _favoriteStores = [
    (name: 'Lidl', asset: 'lib/app/assets/lidl.png'),
    (name: 'Kaufland', asset: 'lib/app/assets/kaufland.png'),
  ];

  // Keep this list as the app expands; favorites are rendered separately.
  static const List<_StoreEntry> _supportedStores = [
    (name: 'Lidl', asset: 'lib/app/assets/lidl.png'),
    (name: 'Kaufland', asset: 'lib/app/assets/kaufland.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final favoriteStoreNames = _favoriteStores
        .map((store) => store.name)
        .toSet();
    final otherStores = _supportedStores
        .where((store) => !favoriteStoreNames.contains(store.name))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w900),
        child: Stack(
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
                      const Text(
                        'Favorites',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SupermarketGroup(
                        stores: _favoriteStores,
                        onTapStore: (store) => _openStore(context, store),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Other',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (otherStores.isEmpty)
                        const _EmptySupermarketsCard()
                      else
                        _SupermarketGroup(
                          stores: otherStores,
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
                    unawaited(_handleMenuAction(context, value));
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: _textDark,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'User page',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'support',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.support_agent_outlined,
                            size: 16,
                            color: _textDark,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Support',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'sign_out',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout, size: 16, color: _textDark),
                          SizedBox(width: 8),
                          Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: const Center(
                    child: Icon(Icons.menu_rounded, color: _textDark, size: 18),
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
      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String value) async {
    if (value == 'profile') {
      _openProfile(context);
      return;
    }
    if (value == 'support') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support will be available soon.')),
      );
      return;
    }
    if (value == 'sign_out') {
      try {
        await supabase.auth.signOut();
      } on AuthException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _openPreferences(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PreferencesScreen()),
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
      height: 128 + topInset,
      padding: EdgeInsets.fromLTRB(24, topInset + 2, 24, 0),
      decoration: const BoxDecoration(color: _headerBlue),
      child: Align(
        alignment: const Alignment(0, -0.72),
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
  final List<_StoreEntry> stores;
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

class _EmptySupermarketsCard extends StatelessWidget {
  const _EmptySupermarketsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: const Text(
        'More supermarkets will appear here as support is added.',
        style: TextStyle(
          color: CartsScreen._textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w800,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE8EDF4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
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
