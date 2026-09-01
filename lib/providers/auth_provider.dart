import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/local_auth_service.dart';
import '../services/auth/supabase_auth_service.dart';
import '../services/supabase_service.dart';

/// Estados possiveis da sessao (RF07 - navegacao condicional).
enum AuthStatus {
  /// Ainda estamos verificando se existe sessao salva - mostra splash.
  checking,

  /// Sem sessao - o `AuthGate` renderiza a tela de login.
  signedOut,

  /// Sessao ativa - o `AuthGate` renderiza o catalogo.
  signedIn,
}

/// RF07 - estado global da sessao do usuario.
///
/// Escolhe automaticamente a implementacao de [AuthService]: se as credenciais
/// do Supabase foram informadas via `--dart-define`, usa autenticacao real
/// (bonus); caso contrario cai no login local (baseline). Nenhuma tela precisa
/// saber qual dos dois esta ativo.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? service})
      : _service = service ??
            (SupabaseService.instance.isEnabled
                ? SupabaseAuthService()
                : LocalAuthService()) {
    _restoreSession();
  }

  final AuthService _service;

  AuthStatus _status = AuthStatus.checking;
  AppUser? _user;
  bool _busy = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// RF09 - a tela de login mostra `CircularProgressIndicator` enquanto `true`.
  bool get busy => _busy;

  /// RF09 - mensagem amigavel exibida abaixo do formulario.
  String? get errorMessage => _errorMessage;

  /// `true` quando a sessao e autenticada de verdade (bonus ativo).
  bool get isCloudSession => _service.isCloud;

  /// Le a sessao persistida ao abrir o app: quem ja entrou continua entrando
  /// direto no catalogo.
  Future<void> _restoreSession() async {
    try {
      _user = await _service.currentUser();
    } catch (_) {
      _user = null;
    }
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => _service.signIn(email: email, password: password));
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => _service.signUp(name: name, email: email, password: password),
    );
  }

  Future<void> signOut() async {
    await _service.signOut();
    _user = null;
    _errorMessage = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Executa uma operacao de autenticacao controlando `busy` e `errorMessage`
  /// em um so lugar - as telas apenas reagem a esses dois campos.
  Future<bool> _run(Future<AppUser> Function() operation) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await operation();
      _status = AuthStatus.signedIn;
      return true;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage =
          'Nao foi possivel conectar. Verifique sua internet e tente de novo.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
