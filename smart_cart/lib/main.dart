import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_cart/core/config/supabase_config.dart';
import 'package:smart_cart/core/candidates/candidate_builder.dart';
import 'package:smart_cart/core/db/normalized_product_repository.dart';
import 'package:smart_cart/core/db/product_cache_store.dart';
import 'package:smart_cart/core/normalization/normalization_debug.dart';
import 'package:smart_cart/core/services/supabase_client.dart';
import 'package:smart_cart/features/auth/login_screen.dart';
import 'package:smart_cart/features/carts/carts_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  if (kDebugMode) {
    unawaited(_debugNormalizationFromCachedLidl());
    unawaited(_debugCandidateStats());
  }
  runApp(const SmartCartApp());
}

Future<void> _debugNormalizationFromCachedLidl() async {
  try {
    final products = await ProductCacheStore().getCachedProducts('Lidl');
    debugPrint(
      '[Normalization Debug] Loaded ${products.length} cached Lidl products',
    );
    debugPrintNormalizationSummary(products);
  } catch (error) {
    debugPrint('[Normalization Debug] Failed to inspect cache: $error');
  }
}

Future<void> _debugCandidateStats() async {
  try {
    final cacheStore = ProductCacheStore();
    final cached = await cacheStore.getCachedProducts('Lidl');
    await cacheStore.saveCachedProducts('Lidl', null, cached);

    final repo = NormalizedProductRepository();
    final stored = await repo.getAllForStore('Lidl');
    debugPrint('[Check] normalized stored (Lidl): ${stored.length}');

    final candidates = await CandidateBuilder().buildCandidates(
      store: 'Lidl',
      budget: 300,
      goal: 'Maintain',
      debug: true,
    );
    debugPrint('[Check] candidates returned: ${candidates.length}');
  } catch (error) {
    debugPrint('[Check] candidate stats failed: $error');
  }
}

class SmartCartApp extends StatelessWidget {
  const SmartCartApp({super.key});
  static const Color _primary = Color(0xFFF3F5F8);

  @override
  Widget build(BuildContext context) {
    final montserratFamily = GoogleFonts.montserrat().fontFamily;
    final textTheme = GoogleFonts.montserratTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F15),
      fontFamily: montserratFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8A93A3),
        brightness: Brightness.dark,
      ),
      dividerColor: const Color(0xFF252B36),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A202B),
        contentTextStyle: GoogleFonts.montserrat(
          color: const Color(0xFFF3F5F8),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: _primary,
        textTheme: CupertinoTextThemeData(
          textStyle: GoogleFonts.montserrat(color: _primary),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: darkTheme,
      darkTheme: darkTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return const CartsScreen();
      },
    );
  }
}
