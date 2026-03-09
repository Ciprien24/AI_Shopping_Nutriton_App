import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_cart/core/services/supabase_client.dart';

Future<void> ensureProfileRow({User? user}) async {
  final authUser = user ?? supabase.auth.currentUser;
  if (authUser == null) return;

  final displayName = (authUser.userMetadata?['display_name'] as String?)
      ?.trim();

  await supabase.from('profiles').upsert({
    'id': authUser.id,
    'display_name': (displayName?.isNotEmpty ?? false) ? displayName : null,
  });
}
