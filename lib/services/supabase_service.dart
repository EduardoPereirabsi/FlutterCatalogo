import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/collection_entry.dart';

/// RF06/RF07 (BONUS) - persistencia em nuvem e autenticacao real com Supabase.
///
/// As credenciais NAO ficam no codigo: sao injetadas em tempo de compilacao com
/// `--dart-define`, o que atende ao criterio "ausencia de segredos expostos no
/// repositorio". Quando elas nao sao informadas, [isEnabled] fica `false` e o
/// aplicativo opera inteiro no modo local (baseline obrigatorio) - o app roda
/// normalmente para quem clonar o repositorio sem ter uma conta Supabase.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');

  /// Nome atual da chave publica no painel do Supabase.
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Nome antigo da mesma chave. Aceitamos os dois para que projetos criados
  /// antes da renomeacao continuem funcionando sem editar o comando de build.
  static const String _legacyAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get _key =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;

  /// Nome da tabela remota (schema em docs/supabase_schema.sql).
  static const String _table = 'collection_items';

  bool _initialized = false;

  /// `true` somente quando as duas credenciais foram informadas E o client
  /// subiu sem erro. Todo o resto do app pergunta isso antes de tocar na rede.
  bool get isEnabled => _initialized;

  static bool get hasCredentials => _url.isNotEmpty && _key.isNotEmpty;

  SupabaseClient get client => Supabase.instance.client;

  /// Chamado uma unica vez no `main()`. Falha de inicializacao nao derruba o
  /// app: apenas mantem o modo local ativo.
  Future<void> initialize() async {
    if (!hasCredentials) return;
    try {
      await Supabase.initialize(url: _url, publishableKey: _key);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Colecao remota
  // ---------------------------------------------------------------------------

  /// Baixa a colecao do usuario autenticado. Usado no login para trazer de
  /// volta os favoritos gravados em outro aparelho.
  Future<Map<int, CollectionEntry>> fetchCollection(String userId) async {
    if (!isEnabled) return <int, CollectionEntry>{};

    final List<Map<String, dynamic>> rows = await client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .then((dynamic value) => List<Map<String, dynamic>>.from(value as List<dynamic>));

    final Map<int, CollectionEntry> result = <int, CollectionEntry>{};
    for (final Map<String, dynamic> row in rows) {
      final int id = (row['character_id'] as num?)?.toInt() ?? 0;
      if (id == 0) continue;
      result[id] = CollectionEntry.fromJson(<String, dynamic>{
        'isFavorite': row['is_favorite'] == true,
        'isWatched': row['is_watched'] == true,
        'updatedAt': row['updated_at'],
        'character': row['payload'],
      });
    }
    return result;
  }

  /// Envia (insere ou atualiza) um item. A chave primaria composta
  /// (user_id, character_id) faz o upsert funcionar sem consulta previa.
  Future<void> upsertEntry(String userId, CollectionEntry entry) async {
    if (!isEnabled) return;
    await client.from(_table).upsert(<String, dynamic>{
      'user_id': userId,
      'character_id': entry.id,
      'is_favorite': entry.isFavorite,
      'is_watched': entry.isWatched,
      'payload': entry.character.toJson(),
      'updated_at': entry.updatedAt.toUtc().toIso8601String(),
    }, onConflict: 'user_id,character_id');
  }

  /// Remove o item quando ele deixa de ser favorito E deixa de ser visto.
  Future<void> deleteEntry(String userId, int characterId) async {
    if (!isEnabled) return;
    await client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('character_id', characterId);
  }
}
