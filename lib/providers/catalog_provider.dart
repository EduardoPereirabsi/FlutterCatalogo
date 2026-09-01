import 'package:flutter/foundation.dart';

import '../models/character.dart';
import '../services/api_service.dart';

/// RF01 + RF08 - estado do catalogo paginado e da busca.
///
/// Por que este estado NAO vive dentro de um `FutureBuilder`:
/// o catalogo e uma lista que *acumula* paginas. Um `FutureBuilder` recria o
/// resultado a cada novo `Future`, entao ele descartaria as paginas anteriores
/// a cada "Carregar Mais". Aqui a lista e acumulada em memoria e o widget so
/// reage as flags de carregamento. (O `FutureBuilder` continua sendo usado na
/// Tela de Detalhes, onde ele e a ferramenta certa - ver `detail_screen.dart`.)
class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._api);

  final ApiService _api;

  final List<Character> _items = <Character>[];
  final Set<int> _knownIds = <int>{};

  int _currentPage = 0;
  bool _hasNextPage = true;
  int _totalCount = 0;

  bool _isLoadingFirstPage = false;
  bool _isLoadingMore = false;
  String? _firstPageError;
  String? _loadMoreError;

  bool _isSearching = false;

  /// Lista imutavel exposta a UI - o widget nao consegue alterar por engano.
  List<Character> get items => List<Character>.unmodifiable(_items);

  bool get hasNextPage => _hasNextPage;
  int get totalCount => _totalCount;
  int get loadedCount => _items.length;

  /// RF09 - carregamento inicial (spinner que ocupa a tela toda).
  bool get isLoadingFirstPage => _isLoadingFirstPage;

  /// RF09 - carregamento da proxima pagina (spinner dentro do botao).
  bool get isLoadingMore => _isLoadingMore;

  /// RF09 - busca em andamento.
  bool get isSearching => _isSearching;

  /// RF09 - erro que impede exibir o catalogo (tela de erro + botao Tentar de novo).
  String? get firstPageError => _firstPageError;

  /// RF09 - erro no "Carregar Mais": a lista ja carregada permanece na tela.
  String? get loadMoreError => _loadMoreError;

  bool get isEmpty => _items.isEmpty && !_isLoadingFirstPage && _firstPageError == null;

  /// RF01 - primeira carga (tambem usada pelo "Tentar de novo" e pelo
  /// pull-to-refresh). Zera tudo antes de buscar a pagina 1.
  Future<void> loadFirstPage() async {
    if (_isLoadingFirstPage) return;

    _isLoadingFirstPage = true;
    _firstPageError = null;
    _loadMoreError = null;
    notifyListeners();

    try {
      final CharacterPage page = await _api.fetchCharacters(page: 1);
      _items
        ..clear()
        ..addAll(page.items);
      _knownIds
        ..clear()
        ..addAll(page.items.map((Character c) => c.id));
      _currentPage = 1;
      _hasNextPage = page.hasNextPage;
      _totalCount = page.totalCount;
    } on ApiException catch (error) {
      _firstPageError = error.message;
    } catch (_) {
      _firstPageError = 'Nao foi possivel carregar o catalogo.';
    } finally {
      _isLoadingFirstPage = false;
      notifyListeners();
    }
  }

  /// RF01 - botao "Carregar Mais": busca a proxima pagina e ANEXA os
  /// resultados a lista existente, sem recarregar o que ja esta na tela.
  ///
  /// Se a rede cair no meio da sessao, o catalogo ja carregado continua
  /// visivel e utilizavel; apenas uma faixa de erro aparece sobre o botao.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoadingFirstPage || !_hasNextPage) return;

    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final CharacterPage page = await _api.fetchCharacters(page: _currentPage + 1);

      // Guarda contra duplicatas: se a mesma pagina for pedida duas vezes por
      // um toque duplo, os itens repetidos sao ignorados em vez de duplicar
      // chaves na GridView.
      for (final Character character in page.items) {
        if (_knownIds.add(character.id)) _items.add(character);
      }

      _currentPage += 1;
      _hasNextPage = page.hasNextPage;
      _totalCount = page.totalCount;
    } on ApiException catch (error) {
      _loadMoreError = error.message;
    } catch (_) {
      _loadMoreError = 'Nao foi possivel carregar mais itens.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void dismissLoadMoreError() {
    if (_loadMoreError == null) return;
    _loadMoreError = null;
    notifyListeners();
  }

  /// RF08 - busca pelo nome. Devolve o personagem encontrado para que a tela
  /// navegue direto para os Detalhes, ou `null` quando houve erro/nada achado
  /// (a mensagem fica disponivel em [lastSearchError]).
  String? lastSearchError;

  Future<Character?> search(String term) async {
    _isSearching = true;
    lastSearchError = null;
    notifyListeners();

    try {
      return await _api.searchFirstByName(term);
    } on ApiException catch (error) {
      lastSearchError = error.message;
      return null;
    } catch (_) {
      lastSearchError = 'Nao foi possivel realizar a busca.';
      return null;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}
