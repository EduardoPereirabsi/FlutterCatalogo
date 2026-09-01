import '../../models/app_user.dart';

/// Erro de autenticacao ja traduzido para o usuario final (RF09).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Contrato unico de autenticacao (RF07).
///
/// Existem duas implementacoes: `LocalAuthService` (baseline obrigatorio) e
/// `SupabaseAuthService` (bonus). O restante do aplicativo depende apenas desta
/// interface, entao trocar de um modo para o outro nao altera nenhuma tela -
/// e o principio de inversao de dependencia aplicado na pratica.
abstract class AuthService {
  /// Indica se a sessao e autenticada de verdade contra um servidor.
  bool get isCloud;

  /// Sessao ja existente ao abrir o app (`null` = precisa fazer login).
  Future<AppUser?> currentUser();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();
}
