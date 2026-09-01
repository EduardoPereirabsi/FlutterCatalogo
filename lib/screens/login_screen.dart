import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/feedback_views.dart';
import 'register_screen.dart';

/// RF07 - porta de entrada do aplicativo. Sem sessao valida o catalogo nao e
/// exibido: quem decide isso e o `AuthGate` em `main.dart`, que renderiza esta
/// tela enquanto `AuthStatus` for `signedOut`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // Em caso de sucesso NAO chamamos Navigator aqui: o `AuthGate` observa o
    // `AuthProvider` e troca a tela sozinho. Isso elimina a classe de bug em
    // que o botao "voltar" do Android devolve o usuario para o login depois de
    // autenticado.
    await context.read<AuthProvider>().signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          // RF10 - toda a tela rola. Com a fonte do sistema no maximo o
          // conteudo continua acessivel em vez de estourar o layout.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      Icons.travel_explore,
                      size: 64,
                      color: scheme.primary,
                      semanticLabel: 'Logotipo do Catalogo do Multiverso',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Catalogo do Multiverso',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entre para explorar, favoritar e marcar os personagens '
                      'que voce ja viu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'voce@exemplo.com',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe seu e-mail.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        // RF10 - o botao de mostrar/ocultar tem rotulo proprio
                        // e area de toque de 48dp.
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            semanticLabel: _obscurePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                          ),
                          tooltip:
                              _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                        ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe sua senha.';
                        }
                        return null;
                      },
                    ),

                    if (auth.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      InlineNotice(message: auth.errorMessage!),
                    ],

                    const SizedBox(height: 24),

                    // RF09 - o botao vira spinner enquanto a autenticacao roda
                    // e fica desabilitado para evitar duplo envio.
                    ElevatedButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton(
                      onPressed: auth.busy
                          ? null
                          : () {
                              context.read<AuthProvider>().clearError();
                              // RF02 - navegacao empilhada: o cadastro entra
                              // por cima do login e volta com `pop`.
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text('Criar uma conta'),
                    ),

                    const SizedBox(height: 24),
                    _SessionModeChip(isCloud: auth.isCloudSession),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deixa explicito qual modo de autenticacao esta ativo. E util na
/// apresentacao: prova que o mesmo binario roda em modo local (baseline) ou em
/// modo autenticado na nuvem (bonus) conforme as credenciais informadas.
class _SessionModeChip extends StatelessWidget {
  const _SessionModeChip({required this.isCloud});

  final bool isCloud;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = isCloud
        ? 'Autenticacao real (Supabase) - dados sincronizados na nuvem'
        : 'Modo local - contas e dados salvos neste aparelho';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isCloud ? Icons.cloud_done_outlined : Icons.phone_android,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
