import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/collection_provider.dart';
import '../widgets/character_card.dart';
import '../widgets/feedback_views.dart';
import 'detail_screen.dart';
import 'favorites_screen.dart';
import 'watched_screen.dart';

/// RF01 (catalogo + paginacao), RF02 (navegacao) e RF08 (busca).
///
/// Tela principal exibida assim que existe sessao valida.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // A primeira carga precisa acontecer depois do primeiro frame: chamar um
    // metodo que faz `notifyListeners()` durante o `build` lanca excecao.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final CatalogProvider catalog = context.read<CatalogProvider>();
      if (catalog.items.isEmpty) catalog.loadFirstPage();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Acoes
  // ---------------------------------------------------------------------------

  /// RF02 - abre a Tela de Detalhes empilhando uma nova rota.
  void _openDetail(Character character) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(
          characterId: character.id,
          preview: character,
        ),
      ),
    );
  }

  /// RF08 - dispara a busca e, encontrando resultado, vai DIRETO para os
  /// detalhes do item, conforme o enunciado.
  Future<void> _runSearch() async {
    final String term = _searchController.text.trim();
    _searchFocus.unfocus();

    if (term.isEmpty) {
      _showMessage('Digite um nome para buscar.');
      return;
    }

    final CatalogProvider catalog = context.read<CatalogProvider>();
    final Character? found = await catalog.search(term);

    if (!mounted) return;
    if (found == null) {
      _showMessage(catalog.lastSearchError ?? 'Nada encontrado.');
      return;
    }
    _openDetail(found);
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text(
          'Seus favoritos continuam salvos e voltam quando voce entrar de novo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    // Basta limpar a sessao: o `AuthGate` devolve o usuario ao login.
    await context.read<AuthProvider>().signOut();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final CatalogProvider catalog = context.watch<CatalogProvider>();
    final CollectionProvider collection = context.watch<CollectionProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo do Multiverso'),
        actions: <Widget>[
          _CounterAction(
            icon: Icons.star_outline,
            activeIcon: Icons.star,
            count: collection.favoritesCount,
            tooltip: 'Favoritos',
            semanticLabel:
                'Favoritos, ${collection.favoritesCount} itens salvos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
            ),
          ),
          _CounterAction(
            icon: Icons.visibility_outlined,
            activeIcon: Icons.visibility,
            count: collection.watchedCount,
            tooltip: 'Ja vi',
            semanticLabel:
                'Personagens que ja vi, ${collection.watchedCount} itens',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WatchedScreen()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Conta',
            icon: const Icon(Icons.account_circle_outlined,
                semanticLabel: 'Menu da conta'),
            onSelected: (String value) {
              if (value == 'logout') _confirmLogout();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      auth.user?.displayName ?? 'Usuario',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      auth.user?.email ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      collection.isCloudSession
                          ? 'Sincronizado na nuvem'
                          : 'Salvo neste aparelho',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _SearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              isSearching: catalog.isSearching,
              onSubmit: _runSearch,
            ),
            if (collection.syncError != null)
              InlineNotice(
                message: collection.syncError!,
                onAction: collection.retrySync,
              ),
            Expanded(child: _buildBody(catalog)),
          ],
        ),
      ),
    );
  }

  /// RF09 - os tres estados possiveis do catalogo.
  Widget _buildBody(CatalogProvider catalog) {
    if (catalog.isLoadingFirstPage && catalog.items.isEmpty) {
      return const LoadingView(message: 'Carregando o catalogo...');
    }

    if (catalog.firstPageError != null && catalog.items.isEmpty) {
      return ErrorView(
        message: catalog.firstPageError!,
        onRetry: catalog.loadFirstPage,
      );
    }

    if (catalog.items.isEmpty) {
      return EmptyView(
        icon: Icons.inbox_outlined,
        title: 'Catalogo vazio',
        description: 'Nao recebemos itens da API neste momento.',
        action: ElevatedButton.icon(
          onPressed: catalog.loadFirstPage,
          icon: const Icon(Icons.refresh),
          label: const Text('Recarregar'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: catalog.loadFirstPage,
      child: _CatalogGrid(
        catalog: catalog,
        onOpen: _openDetail,
      ),
    );
  }
}

/// RF01 - a grade em si, com o rodape de paginacao.
class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.catalog, required this.onOpen});

  final CatalogProvider catalog;
  final void Function(Character) onOpen;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;

    // Layout responsivo: de 2 colunas no celular ate 5 no tablet/desktop.
    final int columns = width >= 1000
        ? 5
        : width >= 760
            ? 4
            : width >= 520
                ? 3
                : 2;

    // RF10 - quando o usuario aumenta a fonte do sistema, a celula fica mais
    // ALTA (proporcao menor) para caber o texto ampliado. Sem este ajuste o
    // nome do personagem seria cortado.
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double aspectRatio =
        (0.68 - (textScale - 1) * 0.24).clamp(0.40, 0.80).toDouble();

    return CustomScrollView(
      // `always` garante que o pull-to-refresh funcione mesmo com poucos itens.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final Character character = catalog.items[index];
                return CharacterCard(
                  key: ValueKey<int>(character.id),
                  character: character,
                  onTap: () => onOpen(character),
                );
              },
              childCount: catalog.items.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _PaginationFooter(catalog: catalog),
        ),
      ],
    );
  }
}

/// RF01 + RF09 - botao "Carregar Mais" com spinner e tratamento de erro.
///
/// Se a API cair durante a paginacao, os itens ja carregados permanecem na
/// tela: exibimos apenas um aviso acima do botao, que continua clicavel.
class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.catalog});

  final CatalogProvider catalog;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        children: <Widget>[
          if (catalog.loadMoreError != null) ...<Widget>[
            InlineNotice(
              message: catalog.loadMoreError!,
              onAction: catalog.loadMore,
            ),
          ],
          Semantics(
            liveRegion: true,
            child: Text(
              'Exibindo ${catalog.loadedCount} de ${catalog.totalCount} personagens',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          if (catalog.hasNextPage)
            ElevatedButton.icon(
              // Desabilitado durante a requisicao: evita disparar duas paginas.
              onPressed: catalog.isLoadingMore ? null : catalog.loadMore,
              icon: catalog.isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                catalog.isLoadingMore ? 'Carregando...' : 'Carregar Mais',
              ),
            )
          else
            Text(
              'Voce chegou ao fim do catalogo.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// RF08 - `TextField` + `TextEditingController` + botao "Buscar".
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: <Widget>[
          // RF10 - o proprio `TextField` publica um no semantico de campo de
          // texto a partir do `labelText`. Envolve-lo em outro `Semantics`
          // faria o leitor de tela anunciar o campo duas vezes.
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Buscar personagem',
                hintText: 'Digite o nome, por exemplo: Morty',
                prefixIcon: const ExcludeSemantics(child: Icon(Icons.search)),
                isDense: true,
                // O botao de limpar aparece so quando ha texto. O
                // `ValueListenableBuilder` reconstroi apenas este sufixo,
                // nao a barra inteira, a cada tecla digitada.
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: controller.clear,
                      icon: const Icon(
                        Icons.close,
                        semanticLabel: 'Limpar campo de busca',
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // RF09 - o proprio botao vira indicador de progresso e fica
          // desabilitado durante a requisicao.
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isSearching ? null : onSubmit,
              child: isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Buscar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icone da AppBar com contador (favoritos / ja vistos).
class _CounterAction extends StatelessWidget {
  const _CounterAction({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final IconData activeIcon;
  final int count;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      // O contador entra no proprio rotulo semantico, para o leitor de tela
      // anunciar "Favoritos, 3 itens salvos" em uma unica leitura.
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        child: Icon(
          count > 0 ? activeIcon : icon,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
