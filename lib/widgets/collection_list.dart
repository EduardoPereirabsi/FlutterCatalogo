import 'package:flutter/material.dart';

import '../models/character.dart';
import 'character_image.dart';

/// RF05 / RF07 - lista usada tanto pelos Favoritos quanto pelos itens "Ja vi".
///
/// As duas telas exibem a mesma estrutura mudando apenas o icone de acao, por
/// isso o widget e parametrizado em vez de duplicado.
class CollectionList extends StatelessWidget {
  const CollectionList({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onRemove,
    required this.removeIcon,
    required this.removeTooltip,
    required this.removeSemanticPrefix,
  });

  final List<Character> items;
  final void Function(Character) onOpen;
  final void Function(Character) onRemove;
  final IconData removeIcon;
  final String removeTooltip;

  /// Ex.: 'Remover dos favoritos' - completado com o nome do personagem para
  /// o leitor de tela (RF10).
  final String removeSemanticPrefix;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Character character = items[index];
        return _CollectionTile(
          character: character,
          onOpen: () => onOpen(character),
          onRemove: () => onRemove(character),
          removeIcon: removeIcon,
          removeTooltip: removeTooltip,
          removeSemanticLabel: '$removeSemanticPrefix ${character.name}',
        );
      },
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.character,
    required this.onOpen,
    required this.onRemove,
    required this.removeIcon,
    required this.removeTooltip,
    required this.removeSemanticLabel,
  });

  final Character character;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final IconData removeIcon;
  final String removeTooltip;
  final String removeSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // RF10 - a miniatura acompanha o tamanho da fonte do sistema. Com fonte
    // grande a linha inteira cresce junto, em vez de cortar o texto.
    final double thumbSize =
        MediaQuery.textScalerOf(context).scale(64).clamp(64.0, 108.0).toDouble();

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              // RF10 - a linha expoe DOIS nos semanticos, nao um:
              //   1) "abrir os detalhes", que cobre miniatura + textos;
              //   2) "remover", no `IconButton` a direita.
              // Por isso o `excludeSemantics` fica restrito a este trecho: se
              // envolvesse a linha inteira, o botao de remover desapareceria
              // para o leitor de tela.
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${character.name}, ${character.speciesLabel}, '
                      'status ${character.statusLabel}',
                  hint: 'Abre os detalhes',
                  onTap: onOpen,
                  excludeSemantics: true,
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: thumbSize,
                          height: thumbSize,
                          child: CharacterImage(
                            character: character,
                            showProgress: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              character.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${character.statusLabel} - ${character.speciesLabel}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // RF10 - `IconButton` ja nasce com 48x48 pelo tema; o
              // `semanticLabel` do icone diz exatamente o que a acao faz.
              IconButton(
                onPressed: onRemove,
                icon: Icon(removeIcon, semanticLabel: removeSemanticLabel),
                tooltip: removeTooltip,
                color: scheme.primary,
                iconSize: 24,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
