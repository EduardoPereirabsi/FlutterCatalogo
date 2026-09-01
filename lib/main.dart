import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/collection_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Necessario porque usamos plugins (shared_preferences, supabase) antes de
  // `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

  // BONUS RF06/RF07 - inicializa o Supabase apenas se as credenciais foram
  // passadas por `--dart-define`. Sem elas o app roda inteiro em modo local.
  await SupabaseService.instance.initialize();

  runApp(const CatalogoMultiversoApp());
}

class CatalogoMultiversoApp extends StatelessWidget {
  const CatalogoMultiversoApp({super.key, this.apiOverride});

  /// Permite injetar um [ApiService] falso nos testes de widget, sem tocar em
  /// nenhuma tela. Em producao fica `null` e o app cria o service real.
  @visibleForTesting
  final ApiService? apiOverride;

  @override
  Widget build(BuildContext context) {
    // Toda a injecao de dependencia do app acontece aqui, em um unico lugar.
    // Nenhuma tela instancia service por conta propria - o que torna cada uma
    // delas testavel com um service falso.
    return MultiProvider(
      providers: [
        // Service sem estado observavel: `Provider` simples basta.
        Provider<ApiService>(
          create: (_) => apiOverride ?? ApiService(),
          // So fechamos o cliente HTTP que nos mesmos criamos: quem injetou o
          // service (o teste) e responsavel pelo ciclo de vida dele.
          dispose: (_, ApiService api) {
            if (apiOverride == null) api.dispose();
          },
        ),

        // RF07 - sessao do usuario.
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),

        // RF01 - catalogo paginado; depende do ApiService.
        ChangeNotifierProvider<CatalogProvider>(
          create: (BuildContext context) =>
              CatalogProvider(context.read<ApiService>()),
        ),

        // RF04/RF05/RF06/RF07 - colecao pessoal.
        //
        // `ChangeNotifierProxyProvider` amarra a colecao a sessao: toda vez que
        // o usuario entra ou sai, `syncWithUser` recarrega (ou limpa) os dados.
        // E isso que garante que dois usuarios no mesmo aparelho nao enxerguem
        // os favoritos um do outro.
        ChangeNotifierProxyProvider<AuthProvider, CollectionProvider>(
          create: (_) => CollectionProvider(),
          update: (
            _,
            AuthProvider auth,
            CollectionProvider? collection,
          ) =>
              (collection ?? CollectionProvider())..syncWithUser(auth.user),
        ),
      ],
      child: MaterialApp(
        title: 'Catalogo do Multiverso',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Acompanha a preferencia do sistema: os dois temas foram montados
        // com contraste conferido (ver app_theme.dart).
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// RF07 - navegacao condicional pela sessao.
///
/// Optamos por um "gate" reativo em vez de `Navigator.pushReplacement` depois
/// do login. Motivos:
///
///   - a troca de tela passa a ser consequencia do ESTADO, nao de uma chamada
///     imperativa espalhada por varias telas;
///   - logout funciona de qualquer lugar da pilha, sem precisar saber quantas
///     rotas existem acima;
///   - elimina o bug classico de o botao "voltar" do Android reexibir o login
///     depois de autenticado.
///
/// `Navigator` continua sendo usado normalmente para o resto do fluxo:
/// `push` para detalhes/favoritos/vistos e `pop` para voltar.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthStatus status =
        context.select<AuthProvider, AuthStatus>((AuthProvider a) => a.status);

    switch (status) {
      case AuthStatus.checking:
        return const _SplashScreen();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const HomeScreen();
    }
  }
}

/// Exibida no instante em que o app le a sessao salva no disco.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.travel_explore,
              size: 64,
              color: scheme.primary,
              semanticLabel: 'Catalogo do Multiverso',
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
