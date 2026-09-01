import 'package:catalogo_multiverso/models/character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Character.fromJson', () {
    test('le um payload completo da Rick and Morty API', () {
      final Character character = Character.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Rick Sanchez',
        'status': 'Alive',
        'species': 'Human',
        'type': '',
        'gender': 'Male',
        'image': 'https://exemplo/1.jpeg',
        'origin': <String, dynamic>{'name': 'Earth (C-137)'},
        'location': <String, dynamic>{'name': 'Citadel of Ricks'},
        'episode': <String>['e1', 'e2'],
      });

      expect(character.id, 1);
      expect(character.name, 'Rick Sanchez');
      expect(character.statusLabel, 'Vivo');
      expect(character.genderLabel, 'Masculino');
      expect(character.originName, 'Earth (C-137)');
      expect(character.episodeCount, 2);
      expect(character.hasImage, isTrue);
    });

    /// RF01 - "itens sem imagem nao podem quebrar a tela". O parsing precisa
    /// sobreviver a um payload incompleto, e nao lancar excecao.
    test('sobrevive a campos ausentes e sinaliza ausencia de imagem', () {
      final Character character =
          Character.fromJson(<String, dynamic>{'id': 42});

      expect(character.id, 42);
      expect(character.name, 'Sem nome');
      expect(character.hasImage, isFalse);
      expect(character.statusLabel, 'Desconhecido');
      expect(character.typeLabel, 'Sem subtipo');
      expect(character.originName, 'Origem desconhecida');
      expect(character.episodeCount, 0);
    });

    test('toJson e fromJson sao simetricos (usado na persistencia RF06)', () {
      const Character original = Character(
        id: 7,
        name: 'Birdperson',
        status: 'Dead',
        species: 'Bird-Person',
        type: '',
        gender: 'Male',
        imageUrl: 'https://exemplo/7.jpeg',
        originName: 'Bird World',
        locationName: 'Bird World',
        episodeUrls: <String>['e11'],
      );

      final Character restored = Character.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.originName, original.originName);
      expect(restored.episodeCount, 1);
    });
  });
}
