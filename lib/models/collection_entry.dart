import 'character.dart';

/// Um item da colecao pessoal do usuario (RF04, RF06, RF07).
///
/// Um unico registro carrega os dois marcadores - favorito e "visto" - porque
/// ambos apontam para o mesmo personagem. Isso evita duas listas paralelas que
/// podem sair de sincronia e reduz a escrita em disco pela metade.
class CollectionEntry {
  const CollectionEntry({
    required this.character,
    required this.isFavorite,
    required this.isWatched,
    required this.updatedAt,
  });

  final Character character;
  final bool isFavorite;
  final bool isWatched;

  /// Carimbo usado para resolver conflito entre local e nuvem: vence o mais
  /// recente (last-write-wins).
  final DateTime updatedAt;

  int get id => character.id;

  /// Um registro sem nenhum marcador nao precisa ser guardado.
  bool get isEmpty => !isFavorite && !isWatched;

  CollectionEntry copyWith({
    Character? character,
    bool? isFavorite,
    bool? isWatched,
    DateTime? updatedAt,
  }) {
    return CollectionEntry(
      character: character ?? this.character,
      isFavorite: isFavorite ?? this.isFavorite,
      isWatched: isWatched ?? this.isWatched,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'isFavorite': isFavorite,
        'isWatched': isWatched,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'character': character.toJson(),
      };

  factory CollectionEntry.fromJson(Map<String, dynamic> json) => CollectionEntry(
        character:
            Character.fromJson((json['character'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
        isFavorite: json['isFavorite'] == true,
        isWatched: json['isWatched'] == true,
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString())?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
