import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/character.dart';
import '../models/collection_entry.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

/// RF04 + RF05 + RF06 + RF07 - a colecao pessoal do usuario.
///
/// Este e o estado global do aplicativo. Favoritos e "Ja vi" vivem aqui, e nao
/// dentro do `State` da Tela de Detalhes, por tres motivos concretos:
///
/// 1. A Tela de Favoritos precisa reagir a um toque dado em OUTRA tela. Com
///    `setState` isso exigiria devolver um resultado pelo `Navigator.pop` e
///    repassar manualmente por toda a pilha.
/// 2. O card do catalogo mostra a estrela do item favoritado; ele nao e filho
///    da Tela de Detalhes, entao nao ha `setState` comum entre os dois.
/// 3. O estado precisa sobreviver ao `dispose()` da tela - e a colecao esta
///    ligada a persistencia, nao ao ciclo de vida de um widget.
///
/// Estrategia de gravacao: **local-first**. A escrita local acontece sempre e
/// e ela que confirma a acao para o usuario; o envio para a nuvem acontece em
/// seguida e, se falhar, apenas registra [syncError] - o app continua usavel
/// offline.
class CollectionProvider extends ChangeNotifier {
  CollectionProvider({
    LocalStorageService? storage,
    SupabaseService? cloud,
  })  : _storage = storage ?? LocalStorageService(),
        _cloud = cloud ?? SupabaseService.instance;

  final LocalStorageService _storage;
  final SupabaseService _cloud;

  final Map<int, CollectionEntry> _entries = <int, CollectionEntry>{};

  String? _userId;
  bool _isCloudSession = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _syncError;

  /// RF09 - a Tela de Favoritos mostra spinner enquanto a colecao e lida.
  bool get isLoading => _isLoading;

  /// `true` enquanto ha troca com a nuvem em andamento (bonus).
  bool get isSyncing => _isSyncing;

  /// Ultimo erro de sincronizacao. A UI mostra um aviso discreto - nunca
  /// bloqueia a acao, porque a gravacao local ja foi concluida.
  String? get syncError => _syncError;

  bool get isCloudSession => _isCloudSession && _cloud.isEnabled;

  /// RF05 - lista reativa de favoritos, mais recentes primeiro.
  List<Character> get favorites => _filtered((CollectionEntry e) => e.isFavorite);

  /// RF07 - lista reativa dos itens ja "consumidos" (vistos).
  List<Character> get watched => _filtered((CollectionEntry e) => e.isWatched);

  int get favoritesCount => favorites.length;
  int get watchedCount => watched.length;

  bool isFavorite(int id) => _entries[id]?.isFavorite ?? false;
  bool isWatched(int id) => _entries[id]?.isWatched ?? false;

  List<Character> _filtered(bool Function(CollectionEntry) test) {
    final List<CollectionEntry> selected =
        _entries.values.where(test).toList(growable: false)
          ..sort((CollectionEntry a, CollectionEntry b) =>
              b.updatedAt.compareTo(a.updatedAt));
    return selected
        .map((CollectionEntry e) => e.character)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Ciclo de vida da sessao
  // ---------------------------------------------------------------------------

  /// Chamado pelo `ChangeNotifierProxyProvider` sempre que a sessao muda.
  ///
  /// Roda durante o `build` do `MultiProvider`, por isso nao pode chamar
  /// `notifyListeners()` de forma sincrona - a carga e agendada num microtask.
  void syncWithUser(AppUser? user) {
    final String? incomingId = user?.id;
    if (incomingId == _userId) return;

    _userId = incomingId;
    _isCloudSession = user?.isCloud ?? false;
    _entries.clear();
    _syncError = null;
    _isLoading = incomingId != null;

    scheduleMicrotask(() {
      if (incomingId == null) {
        notifyListeners();
      } else {
        _loadForUser(incomingId);
      }
    });
  }

  /// RF06 - carga da colecao: primeiro o disco (instantaneo, funciona offline)
  /// e depois a nuvem, quando disponivel.
  Future<void> _loadForUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    final Map<int, CollectionEntry> local = await _storage.loadCollection(userId);
    _entries
      ..clear()
      ..addAll(local);
    _isLoading = false;
    notifyListeners();

    if (!isCloudSession) return;
    await _mergeWithCloud(userId, local);
  }

  /// Reconciliacao local x nuvem por *last-write-wins*: para cada item presente
  /// dos dois lados vence o `updatedAt` mais recente. Itens que existem so de
  /// um lado sao mantidos. Depois disso, o que a nuvem ainda nao tem e enviado.
  Future<void> _mergeWithCloud(
    String userId,
    Map<int, CollectionEntry> local,
  ) async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final Map<int, CollectionEntry> remote = await _cloud.fetchCollection(userId);
      final Map<int, CollectionEntry> merged = <int, CollectionEntry>{...local};

      final List<CollectionEntry> toUpload = <CollectionEntry>[];

      for (final int id in <int>{...local.keys, ...remote.keys}) {
        final CollectionEntry? localEntry = local[id];
        final CollectionEntry? remoteEntry = remote[id];

        if (remoteEntry == null) {
          toUpload.add(localEntry!);
        } else if (localEntry == null) {
          merged[id] = remoteEntry;
        } else if (localEntry.updatedAt.isAfter(remoteEntry.updatedAt)) {
          toUpload.add(localEntry);
        } else {
          merged[id] = remoteEntry;
        }
      }

      _entries
        ..clear()
        ..addAll(merged);
      await _storage.saveCollection(userId, _entries);
      notifyListeners();

      for (final CollectionEntry entry in toUpload) {
        await _cloud.upsertEntry(userId, entry);
      }
    } catch (_) {
      _syncError = 'Nao foi possivel sincronizar com a nuvem. '
          'Seus dados continuam salvos neste aparelho.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Acoes do usuario (RF04 / RF07)
  // ---------------------------------------------------------------------------

  /// RF04 - favoritar / desfavoritar. Retorna o novo estado, que a tela usa
  /// para escolher o texto do `SnackBar`.
  Future<bool> toggleFavorite(Character character) async {
    final bool next = !isFavorite(character.id);
    await _write(character, isFavorite: next);
    return next;
  }

  /// RF07 - marcar / desmarcar como "Ja vi".
  Future<bool> toggleWatched(Character character) async {
    final bool next = !isWatched(character.id);
    await _write(character, isWatched: next);
    return next;
  }

  /// Ponto unico de mutacao: atualiza memoria, grava no disco e sobe para a
  /// nuvem, nessa ordem. A UI ja e notificada antes da gravacao terminar, para
  /// que a estrela responda ao toque instantaneamente (atualizacao otimista).
  Future<void> _write(
    Character character, {
    bool? isFavorite,
    bool? isWatched,
  }) async {
    final String? userId = _userId;
    if (userId == null) return;

    final CollectionEntry current = _entries[character.id] ??
        CollectionEntry(
          character: character,
          isFavorite: false,
          isWatched: false,
          updatedAt: DateTime.now(),
        );

    final CollectionEntry updated = current.copyWith(
      // Atualiza tambem o snapshot: se o item veio da busca, agora temos os
      // dados completos para exibir offline.
      character: character,
      isFavorite: isFavorite,
      isWatched: isWatched,
      updatedAt: DateTime.now(),
    );

    if (updated.isEmpty) {
      _entries.remove(character.id);
    } else {
      _entries[character.id] = updated;
    }
    notifyListeners();

    await _storage.saveCollection(userId, _entries);

    if (!isCloudSession) return;
    try {
      _syncError = null;
      if (updated.isEmpty) {
        await _cloud.deleteEntry(userId, character.id);
      } else {
        await _cloud.upsertEntry(userId, updated);
      }
    } catch (_) {
      _syncError = 'Alteracao salva neste aparelho, mas ainda nao sincronizada.';
      notifyListeners();
    }
  }

  /// Tenta reenviar tudo para a nuvem depois de uma falha de rede.
  Future<void> retrySync() async {
    final String? userId = _userId;
    if (userId == null || !isCloudSession) return;
    await _mergeWithCloud(userId, Map<int, CollectionEntry>.from(_entries));
  }
}
