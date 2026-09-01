import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import 'auth_service.dart';

/// RF07 (baseline obrigatorio) - cadastro e login locais.
///
/// Nao ha servidor: os usuarios ficam em `shared_preferences`. Ainda assim a
/// senha NUNCA e gravada em texto puro - guardamos `sha256(salt + senha)` com
/// um salt aleatorio por usuario. Nao substitui autenticacao real, mas evita
/// que qualquer um leia as senhas abrindo o arquivo de preferencias.
class LocalAuthService implements AuthService {
  static const String _usersKey = 'local_users';
  static const String _sessionKey = 'local_session_email';

  @override
  bool get isCloud => false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<AppUser?> currentUser() async {
    final SharedPreferences prefs = await _prefs;
    final String? email = prefs.getString(_sessionKey);
    if (email == null) return null;

    final Map<String, dynamic> users = _readUsers(prefs);
    final Map<String, dynamic>? record = users[email] as Map<String, dynamic>?;
    if (record == null) {
      await prefs.remove(_sessionKey);
      return null;
    }
    return _toUser(email, record);
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final String normalized = _normalize(email);
    _validate(name: name, email: normalized, password: password);

    final SharedPreferences prefs = await _prefs;
    final Map<String, dynamic> users = _readUsers(prefs);

    if (users.containsKey(normalized)) {
      throw const AuthException('Ja existe uma conta com este e-mail.');
    }

    final String salt = _newSalt();
    users[normalized] = <String, dynamic>{
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'name': name.trim(),
      'salt': salt,
      'hash': _hash(password, salt),
    };

    await prefs.setString(_usersKey, jsonEncode(users));
    await prefs.setString(_sessionKey, normalized);
    return _toUser(normalized, users[normalized] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final String normalized = _normalize(email);
    if (normalized.isEmpty || password.isEmpty) {
      throw const AuthException('Informe e-mail e senha.');
    }

    final SharedPreferences prefs = await _prefs;
    final Map<String, dynamic> users = _readUsers(prefs);
    final Map<String, dynamic>? record =
        users[normalized] as Map<String, dynamic>?;

    // Mensagem generica de proposito: nao revelamos se o e-mail existe.
    const AuthException invalid = AuthException('E-mail ou senha invalidos.');
    if (record == null) throw invalid;

    final String salt = (record['salt'] ?? '').toString();
    if (_hash(password, salt) != record['hash']) throw invalid;

    await prefs.setString(_sessionKey, normalized);
    return _toUser(normalized, record);
  }

  @override
  Future<void> signOut() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_sessionKey);
  }

  // ---------------------------------------------------------------------------

  Map<String, dynamic> _readUsers(SharedPreferences prefs) {
    final String? raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  AppUser _toUser(String email, Map<String, dynamic> record) => AppUser(
        id: (record['id'] ?? email).toString(),
        email: email,
        displayName: (record['name'] ?? email).toString(),
        isCloud: false,
      );

  String _normalize(String email) => email.trim().toLowerCase();

  String _newSalt() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  void _validate({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().length < 2) {
      throw const AuthException('Informe seu nome completo.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const AuthException('Informe um e-mail valido.');
    }
    if (password.length < 6) {
      throw const AuthException('A senha precisa ter ao menos 6 caracteres.');
    }
  }
}
