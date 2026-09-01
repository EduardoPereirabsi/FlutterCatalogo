import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/feedback_views.dart';

/// RF07 - cadastro de usuario.
///
/// Usa o MESMO `AuthProvider` do login. Se o Supabase estiver configurado a
/// conta e criada no servidor (bonus); caso contrario ela e gravada localmente
/// com a senha protegida por hash. Esta tela nao sabe qual dos dois ocorreu.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final bool created = await context.read<AuthProvider>().signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

    // `mounted` protege contra usar o `context` depois que a tela saiu da
    // arvore (o usuario pode ter voltado enquanto a requisicao corria).
    if (!mounted || !created) return;

    // Cadastro ja cria a sessao, entao removemos esta rota da pilha e deixamos
    // o `AuthGate` mostrar o catalogo.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (String? value) =>
                          (value == null || value.trim().length < 2)
                              ? 'Informe seu nome completo.'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (String? value) {
                        final String email = (value ?? '').trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Informe um e-mail valido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        helperText: 'Minimo de 6 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            semanticLabel:
                                _obscure ? 'Mostrar senha' : 'Ocultar senha',
                          ),
                        ),
                      ),
                      validator: (String? value) =>
                          (value == null || value.length < 6)
                              ? 'A senha precisa ter ao menos 6 caracteres.'
                              : null,
                    ),
                    if (auth.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      InlineNotice(message: auth.errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Criar conta e entrar'),
                    ),
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
