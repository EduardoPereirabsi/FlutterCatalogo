import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/collection_provider.dart';
import '../widgets/collection_list.dart';
import '../widgets/feedback_views.dart';
import 'detail_screen.dart';

/// RF07 - Tela dos itens "consumidos".
///
/// No tema escolhido, "consumir" e ter visto o personagem na serie, entao a
/// lista se chama "Ja vi". A mecanica e identica a dos favoritos e usa o mesmo
/// [CollectionProvider] e a mesma persistencia - o que muda e apenas o
/// marcador booleano gravado no registro.
class WatchedScreen extends StatelessWidget {
  const WatchedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CollectionProvider collection = context.watch<CollectionProvider>();
    final List<Character> watched = collection.watched;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ja vi'),
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
          Expanded(child: _buildBody(context, collection, watched)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CollectionProvider collection,
    List<Character> watched,
  ) {
    if (collection.isLoading) {
      return const LoadingView(message: 'Carregando sua lista...');
    }

    if (watched.isEmpty) {
      return EmptyView(
        icon: Icons.visibility_outlined,
        title: 'Voce ainda nao marcou ninguem',
        description:
            'Na tela de detalhes, toque em "Marcar como visto" para montar '
            'seu historico.',
        action: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.grid_view),
          label: const Text('Voltar ao catalogo'),
        ),
      );
    }

    return CollectionList(
      items: watched,
      removeIcon: Icons.visibility_off_outlined,
      removeTooltip: 'Remover da lista de vistos',
      removeSemanticPrefix: 'Remover da lista de vistos',
      onOpen: (Character character) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(
            characterId: character.id,
            preview: character,
          ),
        ),
      ),
      onRemove: (Character character) async {
        await collection.toggleWatched(character);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${character.name} saiu da lista de vistos.'),
              action: SnackBarAction(
                label: 'Desfazer',
                onPressed: () => collection.toggleWatched(character),
              ),
            ),
          );
      },
    );
  }
}
