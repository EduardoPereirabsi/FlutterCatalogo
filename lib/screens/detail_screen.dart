import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/collection_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_image.dart';
import '../widgets/feedback_views.dart';

/// Dados agregados da tela de detalhes: o personagem completo mais o primeiro
/// episodio em que ele aparece (duas chamadas distintas a API).
class _DetailData {
  const _DetailData({required this.character, this.firstEpisode});

  final Character character;
  final Episode? firstEpisode;
}

/// RF03 (detalhes), RF04 (favoritar) e RF07 (marcar como visto).
///
/// Aqui o `FutureBuilder` e a ferramenta certa: e uma requisicao unica, cujo
/// resultado nao precisa ser compartilhado com nenhuma outra tela e morre junto
/// com a rota. Seria desperdicio criar um provider global so para isso.
class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.characterId,
    this.preview,
  });

  final int characterId;

  /// Dados que ja temos do card do catalogo. Servem para desenhar a tela
  /// imediatamente enquanto a requisicao completa acontece.
  final Character? preview;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  /// O `Future` e criado UMA vez, no `initState`.
  ///
  /// Se ele fosse criado dentro do `build`, cada `setState` (inclusive o
  /// disparado por favoritar) refaria a requisicao HTTP. Este e o erro mais
  /// comum no uso de `FutureBuilder`.
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final ApiService api = context.read<ApiService>();

    // 1a requisicao: dados completos do personagem.
    final Character character = await api.fetchCharacterById(widget.characterId);

    // 2a requisicao: primeiro episodio. Uma falha aqui NAO derruba a tela -
    // apenas omitimos a secao do episodio.
    Episode? episode;
    if (character.episodeUrls.isNotEmpty) {
      try {
        episode = await api.fetchEpisode(character.episodeUrls.first);
      } catch (_) {
        episode = null;
      }
    }

    return _DetailData(character: character, firstEpisode: episode);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preview?.name ?? 'Detalhes'),
      ),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_DetailData> snapshot) {
          // RF09 - estado 1: carregando.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Carregando os detalhes...');
          }

          // RF09 - estado 2: erro amigavel com acao de recuperacao.
          if (snapshot.hasError) {
            final Object error = snapshot.error!;
            final String message = error is ApiException
                ? error.message
                : 'Nao foi possivel carregar os detalhes deste personagem.';
            return ErrorView(message: message, onRetry: _retry);
          }

          // RF09 - estado 3: sucesso.
          final _DetailData data = snapshot.data!;
          return _DetailBody(
            character: data.character,
            firstEpisode: data.firstEpisode,
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.character, this.firstEpisode});

  final Character character;
  final Episode? firstEpisode;

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // `watch` aqui e proposital: quando o usuario favorita, o Provider notifica
    // e SOMENTE esta arvore e reconstruida - o `Future` nao e refeito.
    final CollectionProvider collection = context.watch<CollectionProvider>();
    final bool isFavorite = collection.isFavorite(character.id);
    final bool isWatched = collection.isWatched(character.id);

    // RF10 - limita a altura da imagem para que, em telas pequenas com fonte
    // grande, o conteudo de texto continue alcancavel sem rolagem infinita.
    final double imageHeight =
        (MediaQuery.sizeOf(context).height * 0.38).clamp(200.0, 380.0).toDouble();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        // RF03 - imagem em tamanho maior.
        SizedBox(
          height: imageHeight,
          child: CharacterImage(character: character, fit: BoxFit.cover),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                character.name,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${character.statusLabel} - ${character.speciesLabel}',
                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // RF04 / RF07 - as duas acoes que gravam na colecao.
              // `Wrap` em vez de `Row`: com fonte grande os botoes quebram para
              // a linha de baixo em vez de estourar a largura (RF10).
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _ActionButton(
                    active: isFavorite,
                    activeIcon: Icons.star,
                    inactiveIcon: Icons.star_outline,
                    activeLabel: 'Favorito',
                    inactiveLabel: 'Favoritar',
                    semanticLabel: isFavorite
                        ? 'Remover ${character.name} dos favoritos'
                        : 'Adicionar ${character.name} aos favoritos',
                    onPressed: () async {
                      final bool now =
                          await collection.toggleFavorite(character);
                      if (!context.mounted) return;
                      _showMessage(
                        context,
                        now
                            ? '${character.name} adicionado aos favoritos.'
                            : '${character.name} removido dos favoritos.',
                      );
                    },
                  ),
                  _ActionButton(
                    active: isWatched,
                    activeIcon: Icons.visibility,
                    inactiveIcon: Icons.visibility_outlined,
                    activeLabel: 'Ja vi',
                    inactiveLabel: 'Marcar como visto',
                    semanticLabel: isWatched
                        ? 'Desmarcar ${character.name} como ja visto'
                        : 'Marcar ${character.name} como ja visto',
                    onPressed: () async {
                      final bool now =
                          await collection.toggleWatched(character);
                      if (!context.mounted) return;
                      _showMessage(
                        context,
                        now
                            ? '${character.name} marcado como ja visto.'
                            : '${character.name} removido da lista de vistos.',
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Ficha do personagem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // RF03 - principais atributos do item.
        _AttributeRow(
          icon: Icons.favorite_outline,
          label: 'Status',
          value: character.statusLabel,
        ),
        _AttributeRow(
          icon: Icons.category_outlined,
          label: 'Especie',
          value: character.speciesLabel,
        ),
        _AttributeRow(
          icon: Icons.science_outlined,
          label: 'Subtipo',
          value: character.typeLabel,
        ),
        _AttributeRow(
          icon: Icons.wc_outlined,
          label: 'Genero',
          value: character.genderLabel,
        ),
        _AttributeRow(
          icon: Icons.public_outlined,
          label: 'Origem',
          value: character.originName,
        ),
        _AttributeRow(
          icon: Icons.place_outlined,
          label: 'Ultima localizacao',
          value: character.locationName,
        ),
        _AttributeRow(
          icon: Icons.movie_outlined,
          label: 'Aparicoes',
          value: '${character.episodeCount} episodio(s)',
        ),
        if (firstEpisode != null)
          _AttributeRow(
            icon: Icons.play_circle_outline,
            label: 'Primeiro episodio',
            value: '${firstEpisode!.code} - ${firstEpisode!.name}'
                '${firstEpisode!.airDate.isEmpty ? '' : ' (${firstEpisode!.airDate})'}',
          ),
      ],
    );
  }
}

/// Botao de acao da colecao. Muda de aparencia conforme o estado global.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.active,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool active;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String activeLabel;
  final String inactiveLabel;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget botao = active
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(activeIcon),
            label: Text(activeLabel),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(inactiveIcon),
            label: Text(inactiveLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(64, AppTheme.minTapTarget),
            ),
          );

    // RF10 - `toggled` faz o leitor de tela anunciar "selecionado" / "nao
    // selecionado", e nao apenas o texto do botao. O `onTap` deste no e
    // necessario porque `excludeSemantics` descarta a acao do botao interno.
    return Semantics(
      button: true,
      toggled: active,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTheme.minTapTarget),
        child: botao,
      ),
    );
  }
}

/// Linha de atributo. Usa `Wrap`/`Expanded` no lugar de larguras fixas para
/// nao cortar o texto quando a fonte do sistema aumenta (RF10).
class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurface,
                      ),
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
