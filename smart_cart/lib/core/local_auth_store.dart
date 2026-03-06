import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalAuthStore {
  static const String _fileName = 'auth_credentials.json';

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({'email': email.trim().toLowerCase(), 'password': password}),
    );
  }

  Future<({String email, String password})?> loadCredentials() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final email = (map['email'] as String?)?.trim().toLowerCase();
      final password = map['password'] as String?;
      if (email == null || email.isEmpty || password == null) return null;
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
}
