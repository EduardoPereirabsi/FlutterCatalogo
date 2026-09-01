import 'package:flutter/material.dart';

/// RF09 - os tres estados visuais de qualquer tela que fala com a API:
/// carregando, erro e vazio. Centralizar aqui garante que login, catalogo,
/// detalhes, favoritos e vistos deem exatamente o mesmo feedback.

/// Spinner centralizado com legenda. A legenda tambem e o `semanticLabel`, de
/// modo que o leitor de tela anuncia o que esta acontecendo (RF10).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Carregando...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensagem de erro amigavel com acao de recuperacao.
///
/// Nunca mostramos o texto tecnico da excecao: a `ApiException` ja chega aqui
/// traduzida ("Sem conexao com a internet...", "O servidor esta fora do ar...").
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Tentar de novo',
    this.icon = Icons.cloud_off_outlined,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // `liveRegion` faz o leitor de tela anunciar o erro assim que ele
            // aparece, sem o usuario precisar navegar ate o texto.
            Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 56, color: scheme.error, semanticLabel: 'Erro'),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vazio (nenhum favorito, nenhum item visto).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Icone decorativo: o titulo logo abaixo ja diz tudo, entao
            // removemos o no da arvore semantica em vez de dar a ele um
            // rotulo vazio.
            ExcludeSemantics(
              child: Icon(icon, size: 64, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Faixa de aviso nao bloqueante (ex.: falha ao sincronizar com a nuvem
/// enquanto a gravacao local ja foi concluida).
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel = 'Tentar de novo',
    this.isError = true,
  });

  final String message;
  final VoidCallback? onAction;
  final String actionLabel;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background =
        isError ? scheme.errorContainer : scheme.secondaryContainer;
    final Color foreground =
        isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      isError ? Icons.error_outline : Icons.info_outline,
                      size: 20,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(fontSize: 14, color: foreground),
                    ),
                  ),
                ],
              ),
            ),
            if (onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
