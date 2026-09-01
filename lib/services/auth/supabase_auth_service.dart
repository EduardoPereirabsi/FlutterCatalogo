import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/app_user.dart';
import '../supabase_service.dart';
import 'auth_service.dart';

/// RF07 (BONUS) - autenticacao real com Supabase Auth.
///
/// Implementa exatamente o mesmo contrato do login local, entao as telas de
/// login e cadastro sao reaproveitadas sem uma unica linha condicional.
class SupabaseAuthService implements AuthService {
  @override
  bool get isCloud => true;

  sb.GoTrueClient get _auth => SupabaseService.instance.client.auth;

  @override
  Future<AppUser?> currentUser() async {
    final sb.User? user = _auth.currentUser;
    return user == null ? null : _toUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final sb.AuthResponse response = await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final sb.User? user = response.user;
      if (user == null) throw const AuthException('Nao foi possivel entrar.');
      return _toUser(user);
    } on sb.AuthException catch (error) {
      throw AuthException(_translate(error.message));
    }
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final sb.AuthResponse response = await _auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: <String, dynamic>{'display_name': name.trim()},
      );
      final sb.User? user = response.user;
      if (user == null) {
        throw const AuthException(
          'Conta criada. Confirme o e-mail antes de entrar.',
        );
      }
      return _toUser(user);
    } on sb.AuthException catch (error) {
      throw AuthException(_translate(error.message));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AppUser _toUser(sb.User user) => AppUser(
        id: user.id,
        email: user.email ?? '',
        displayName: (user.userMetadata?['display_name'] ??
                user.email ??
                'Usuario')
            .toString(),
        isCloud: true,
      );

  /// Traduz as mensagens do Supabase (em ingles) para o usuario final.
  String _translate(String message) {
    final String lower = message.toLowerCase();
    if (lower.contains('invalid login')) return 'E-mail ou senha invalidos.';
    if (lower.contains('already registered')) {
      return 'Ja existe uma conta com este e-mail.';
    }
    if (lower.contains('password')) {
      return 'A senha precisa ter ao menos 6 caracteres.';
    }
    if (lower.contains('email')) return 'Informe um e-mail valido.';
    return 'Nao foi possivel completar a operacao. Tente novamente.';
  }
}
