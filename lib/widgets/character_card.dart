import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/collection_provider.dart';
import 'character_image.dart';

/// RF01 - celula da `GridView` do catalogo.
///
/// O card observa o [CollectionProvider] para desenhar os selos de favorito e
/// de "ja vi". Isso mostra na pratica por que o estado precisa ser global: o
/// toque acontece na Tela de Detalhes, mas quem precisa se redesenhar e este
/// widget, que esta em outro galho da arvore.
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
  });

  final Character character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // `select` reconstroi este card apenas quando os dois marcadores DESTE
    // personagem mudam - nao a cada alteracao em qualquer item da colecao.
    final bool isFavorite = context.select<CollectionProvider, bool>(
      (CollectionProvider c) => c.isFavorite(character.id),
    );
    final bool isWatched = context.select<CollectionProvider, bool>(
      (CollectionProvider c) => c.isWatched(character.id),
    );

    // RF10 - um unico rotulo descreve o card inteiro para o leitor de tela,
    // incluindo os marcadores, em vez de anunciar icones soltos.
    final String semanticLabel = <String>[
      character.name,
      character.speciesLabel,
      'status ${character.statusLabel}',
      if (isFavorite) 'favoritado',
      if (isWatched) 'ja visto',
    ].join(', ');

    // RF10 - o card e UM unico no semantico:
    //   `excludeSemantics` descarta os nos internos (imagem, textos, selos)
    //   para o leitor de tela nao ler cinco coisas soltas;
    //   `onTap` neste no e OBRIGATORIO - como a acao do `InkWell` foi excluida
    //   junto, sem ele o TalkBack leria o rotulo mas o gesto "toque duplo para
    //   ativar" nao faria nada.
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: 'Abre os detalhes',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CharacterImage(character: character),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (isWatched)
                            const _Badge(
                              icon: Icons.visibility,
                              color: Color(0xFF8FB7FF),
                            ),
                          if (isFavorite)
                            const _Badge(
                              icon: Icons.star,
                              color: Color(0xFFFFC46B),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      character.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        _StatusDot(status: character.status),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${character.statusLabel} - ${character.speciesLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: Color(0xCC0E1620),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// Indicador de status. A cor NUNCA e a unica portadora da informacao: o texto
/// ao lado repete "Vivo / Morto / Desconhecido" - requisito de acessibilidade
/// para daltonicos (WCAG 1.4.1).
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'alive':
        color = const Color(0xFF46D6A6);
        break;
      case 'dead':
        color = const Color(0xFFFF8A80);
        break;
      default:
        color = const Color(0xFFA9BACB);
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
