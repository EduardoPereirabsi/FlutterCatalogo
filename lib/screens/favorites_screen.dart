import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/collection_provider.dart';
import '../widgets/collection_list.dart';
import '../widgets/feedback_views.dart';
import 'detail_screen.dart';

/// RF05 - Tela de Favoritos.
///
/// A tela nao guarda estado nenhum: ela apenas *observa* o [CollectionProvider].
/// Por isso, desfavoritar um item aqui - ou na Tela de Detalhes, ou pelo
/// catalogo - remove a linha da lista imediatamente, sem nenhum `setState`.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CollectionProvider collection = context.watch<CollectionProvider>();
    final List<Character> favorites = collection.favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        actions: <Widget>[
          if (collection.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (collection.syncError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InlineNotice(
                message: collection.syncError!,
                onAction: collection.retrySync,
              ),
            ),
          Expanded(
            child: _buildBody(context, collection, favorites),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CollectionProvider collection,
    List<Character> favorites,
  ) {
    // RF09 - enquanto a colecao persistida esta sendo lida.
    if (collection.isLoading) {
      return const LoadingView(message: 'Carregando seus favoritos...');
    }

    if (favorites.isEmpty) {
      return EmptyView(
        icon: Icons.star_outline,
        title: 'Nenhum favorito ainda',
        description:
            'Abra um personagem no catalogo e toque em "Favoritar" para '
            've-lo aqui.',
        action: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.grid_view),
          label: const Text('Voltar ao catalogo'),
        ),
      );
    }

    return CollectionList(
      items: favorites,
      removeIcon: Icons.star,
      removeTooltip: 'Remover dos favoritos',
      removeSemanticPrefix: 'Remover dos favoritos',
      onOpen: (Character character) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(
            characterId: character.id,
            preview: character,
          ),
        ),
      ),
      onRemove: (Character character) async {
        await collection.toggleFavorite(character);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${character.name} removido dos favoritos.'),
              action: SnackBarAction(
                label: 'Desfazer',
                onPressed: () => collection.toggleFavorite(character),
              ),
            ),
          );
      },
    );
  }
}
