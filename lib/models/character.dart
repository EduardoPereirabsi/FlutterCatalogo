/// Modelo de dominio do item do catalogo (RF01/RF03).
///
/// Representa um personagem retornado pela Rick and Morty API.
/// Todo parsing defensivo mora aqui: se a API mudar ou vier com campo nulo,
/// a tela nao quebra (requisito do RF01 sobre itens sem imagem).
class Character {
  const Character({
    required this.id,
    required this.name,
    required this.status,
    required this.species,
    required this.type,
    required this.gender,
    required this.imageUrl,
    required this.originName,
    required this.locationName,
    required this.episodeUrls,
  });

  final int id;
  final String name;
  final String status;
  final String species;
  final String type;
  final String gender;
  final String imageUrl;
  final String originName;
  final String locationName;
  final List<String> episodeUrls;

  /// Quantidade de episodios em que o personagem aparece.
  int get episodeCount => episodeUrls.length;

  /// `true` quando a API nao trouxe uma imagem utilizavel.
  /// A UI usa isso para desenhar o placeholder em vez de tentar baixar nada.
  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// Traducao do campo `status` para exibicao e para o `semanticLabel` (RF10).
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'alive':
        return 'Vivo';
      case 'dead':
        return 'Morto';
      default:
        return 'Desconhecido';
    }
  }

  String get speciesLabel => species.isEmpty ? 'Especie desconhecida' : species;

  String get typeLabel => type.trim().isEmpty ? 'Sem subtipo' : type;

  String get genderLabel {
    switch (gender.toLowerCase()) {
      case 'male':
        return 'Masculino';
      case 'female':
        return 'Feminino';
      case 'genderless':
        return 'Sem genero';
      default:
        return 'Desconhecido';
    }
  }

  /// Descricao usada no `semanticLabel` da imagem (RF10 - leitor de tela).
  String get accessibleDescription =>
      'Foto de $name, $speciesLabel, status $statusLabel';

  /// Parsing tolerante: qualquer campo ausente vira string vazia em vez de
  /// lancar excecao. `id` e o unico campo realmente obrigatorio.
  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: _asInt(json['id']),
      name: _asString(json['name'], fallback: 'Sem nome'),
      status: _asString(json['status'], fallback: 'unknown'),
      species: _asString(json['species']),
      type: _asString(json['type']),
      gender: _asString(json['gender'], fallback: 'unknown'),
      imageUrl: _asString(json['image']),
      originName: _asString(
        (json['origin'] as Map<String, dynamic>?)?['name'],
        fallback: 'Origem desconhecida',
      ),
      locationName: _asString(
        (json['location'] as Map<String, dynamic>?)?['name'],
        fallback: 'Localizacao desconhecida',
      ),
      episodeUrls: (json['episode'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
    );
  }

  /// Serializacao usada pela persistencia (RF06), tanto local quanto na nuvem.
  /// Guardamos o snapshot do item para que Favoritos/Vistos abram offline,
  /// sem depender de uma nova chamada de rede.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'status': status,
        'species': species,
        'type': type,
        'gender': gender,
        'image': imageUrl,
        'origin': <String, dynamic>{'name': originName},
        'location': <String, dynamic>{'name': locationName},
        'episode': episodeUrls,
      };

  static String _asString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  bool operator ==(Object other) => other is Character && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Uma pagina de resultados da API (RF01 - paginacao).
class CharacterPage {
  const CharacterPage({
    required this.items,
    required this.hasNextPage,
    required this.totalCount,
  });

  final List<Character> items;
  final bool hasNextPage;
  final int totalCount;
}

/// Modelo do episodio, usado na segunda requisicao da Tela de Detalhes (RF03).
class Episode {
  const Episode({required this.name, required this.airDate, required this.code});

  final String name;
  final String airDate;
  final String code;

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        name: (json['name'] ?? 'Episodio desconhecido').toString(),
        airDate: (json['air_date'] ?? '').toString(),
        code: (json['episode'] ?? '').toString(),
      );
}
