import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_entry.dart';

/// RF06 (baseline obrigatorio) - persistencia local com `shared_preferences`.
///
/// A colecao inteira do usuario e serializada como um unico documento JSON sob
/// a chave `collection_<userId>`. Como o volume e pequeno (dezenas de itens) e
/// sempre lido/escrito por inteiro, um banco relacional (sqflite) traria
/// complexidade sem beneficio - ver justificativa no README.
class LocalStorageService {
  static const String _collectionPrefix = 'collection_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _keyFor(String userId) => '$_collectionPrefix$userId';

  /// Le a colecao salva do usuario. Nunca lanca: se o JSON estiver corrompido
  /// (versao antiga do app, por exemplo), devolvemos vazio em vez de travar o
  /// boot do aplicativo.
  Future<Map<int, CollectionEntry>> loadCollection(String userId) async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_keyFor(userId));
    if (raw == null || raw.isEmpty) return <int, CollectionEntry>{};

    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      final Map<int, CollectionEntry> result = <int, CollectionEntry>{};
      decoded.forEach((String key, dynamic value) {
        final int? id = int.tryParse(key);
        if (id == null || value is! Map<String, dynamic>) return;
        result[id] = CollectionEntry.fromJson(value);
      });
      return result;
    } catch (_) {
      await prefs.remove(_keyFor(userId));
      return <int, CollectionEntry>{};
    }
  }

  /// Grava a colecao completa. Chamado a cada toque em favoritar/marcar visto.
  Future<void> saveCollection(
    String userId,
    Map<int, CollectionEntry> entries,
  ) async {
    final SharedPreferences prefs = await _prefs;
    final Map<String, dynamic> payload = <String, dynamic>{
      for (final MapEntry<int, CollectionEntry> e in entries.entries)
        e.key.toString(): e.value.toJson(),
    };
    await prefs.setString(_keyFor(userId), jsonEncode(payload));
  }

  Future<void> clearCollection(String userId) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_keyFor(userId));
  }
}
