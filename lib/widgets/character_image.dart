import 'package:flutter/material.dart';

import '../models/character.dart';

/// RF01 (placeholder) + RF09 (progresso) + RF10 (leitor de tela).
///
/// Um unico widget resolve os tres casos de uma imagem remota:
///   - a API nao mandou URL  -> desenha o placeholder;
///   - a URL falhou ao baixar -> `errorBuilder` cai no mesmo placeholder;
///   - download em andamento  -> `loadingBuilder` mostra progresso.
///
/// Em nenhum desses caminhos a tela quebra, que e exatamente o que o RF01
/// exige para itens sem imagem disponivel.
class CharacterImage extends StatelessWidget {
  const CharacterImage({
    super.key,
    required this.character,
    this.fit = BoxFit.cover,
    this.showProgress = true,
  });

  final Character character;
  final BoxFit fit;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    // RF10 - a imagem e anunciada pelo TalkBack/VoiceOver com uma descricao
    // util ("Foto de Rick Sanchez, Human, status Vivo"), nunca como
    // "imagem sem rotulo".
    return Semantics(
      image: true,
      label: character.hasImage
          ? character.accessibleDescription
          : 'Imagem nao disponivel para ${character.name}',
      child: ExcludeSemantics(
        child: character.hasImage
            ? Image.network(
                character.imageUrl,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                // Cai no placeholder em vez de estourar excecao na arvore.
                errorBuilder: (BuildContext context, Object error,
                        StackTrace? stack) =>
                    const _Placeholder(),
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null || !showProgress) return child;
                  return _LoadingBox(
                    value: progress.expectedTotalBytes == null
                        ? null
                        : progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!,
                  );
                },
              )
            : const _Placeholder(),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  /// Abaixo desta altura nao cabe icone + legenda; mostramos so o icone.
  static const double _alturaMinimaComLegenda = 96;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // O placeholder aparece em caixas de tamanhos muito diferentes: 64x64 na
    // lista de favoritos e a tela inteira nos detalhes. Sem se adaptar, a
    // versao com legenda estoura o layout na miniatura - e "item sem imagem
    // nao pode quebrar a tela" e justamente o que o RF01 exige.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double altura = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : _alturaMinimaComLegenda;
        final double largura = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _alturaMinimaComLegenda;
        final double menorLado = altura < largura ? altura : largura;
        final bool compacto = menorLado < _alturaMinimaComLegenda;

        return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
          child: Center(
            child: compacto
                ? Icon(
                    Icons.person_off_outlined,
                    size: menorLado * 0.45,
                    color: scheme.onSurfaceVariant,
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.person_off_outlined,
                          size: 32,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            'Sem imagem',
                            textAlign: TextAlign.center,
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
                  ),
          ),
        );
      },
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, value: value),
        ),
      ),
    );
  }
}
