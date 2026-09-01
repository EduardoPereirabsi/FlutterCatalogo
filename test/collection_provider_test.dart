import 'package:catalogo_multiverso/models/app_user.dart';
import 'package:catalogo_multiverso/models/character.dart';
import 'package:catalogo_multiverso/models/collection_entry.dart';
import 'package:catalogo_multiverso/providers/collection_provider.dart';
import 'package:catalogo_multiverso/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê de teste do armazenamento: guarda tudo em memoria, o que permite
/// testar as regras do provider sem depender do `shared_preferences` real.
class _FakeStorage extends LocalStorageService {
  final Map<String, Map<int, CollectionEntry>> data =
      <String, Map<int, CollectionEntry>>{};

  int saveCount = 0;

  @override
  Future<Map<int, CollectionEntry>> loadCollection(String userId) async =>
      Map<int, CollectionEntry>.from(
        data[userId] ?? <int, CollectionEntry>{},
      );

  @override
  Future<void> saveCollection(
    String userId,
    Map<int, CollectionEntry> entries,
  ) async {
    saveCount += 1;
    data[userId] = Map<int, CollectionEntry>.from(entries);
  }

  @override
  Future<void> clearCollection(String userId) async => data.remove(userId);
}

const Character _rick = Character(
  id: 1,
  name: 'Rick Sanchez',
  status: 'Alive',
  species: 'Human',
  type: '',
  gender: 'Male',
  imageUrl: 'https://exemplo/1.jpeg',
  originName: 'Earth',
  locationName: 'Citadel',
  episodeUrls: <String>[],
);

const AppUser _user = AppUser(
  id: 'u1',
  email: 'aluno@exemplo.com',
  displayName: 'Aluno',
  isCloud: false,
);

Future<CollectionProvider> _providerFor(_FakeStorage storage) async {
  final CollectionProvider provider = CollectionProvider(storage: storage);
  provider.syncWithUser(_user);
  // `syncWithUser` agenda a carga num microtask; aguardamos ela concluir.
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  group('CollectionProvider', () {
    test('favoritar adiciona a lista e grava no armazenamento (RF04/RF06)',
        () async {
      final _FakeStorage storage = _FakeStorage();
      final CollectionProvider provider = await _providerFor(storage);

      expect(provider.isFavorite(_rick.id), isFalse);

      final bool now = await provider.toggleFavorite(_rick);

      expect(now, isTrue);
      expect(provider.isFavorite(_rick.id), isTrue);
      expect(provider.favorites.single.name, 'Rick Sanchez');
      expect(storage.data['u1']!.containsKey(1), isTrue);
    });

    test('favoritos e vistos sao marcadores independentes (RF07)', () async {
      final _FakeStorage storage = _FakeStorage();
      final CollectionProvider provider = await _providerFor(storage);

      await provider.toggleFavorite(_rick);
      await provider.toggleWatched(_rick);

      expect(provider.favoritesCount, 1);
      expect(provider.watchedCount, 1);

      await provider.toggleFavorite(_rick);

      // Deixou de ser favorito, mas continua na lista de vistos.
      expect(provider.favoritesCount, 0);
      expect(provider.watchedCount, 1);
      expect(storage.data['u1']!.containsKey(1), isTrue);
    });

    test('registro sem nenhum marcador e removido do armazenamento', () async {
      final _FakeStorage storage = _FakeStorage();
      final CollectionProvider provider = await _providerFor(storage);

      await provider.toggleFavorite(_rick);
      await provider.toggleFavorite(_rick);

      expect(provider.favoritesCount, 0);
      expect(storage.data['u1']!.containsKey(1), isFalse);
    });

    test('a colecao persistida volta ao entrar de novo (RF06)', () async {
      final _FakeStorage storage = _FakeStorage();

      final CollectionProvider first = await _providerFor(storage);
      await first.toggleFavorite(_rick);

      // Simula reabrir o app: novo provider, mesmo armazenamento.
      final CollectionProvider second = await _providerFor(storage);

      expect(second.favoritesCount, 1);
      expect(second.favorites.single.id, _rick.id);
    });

    test('trocar de usuario nao vaza dados entre contas', () async {
      final _FakeStorage storage = _FakeStorage();
      final CollectionProvider provider = await _providerFor(storage);
      await provider.toggleFavorite(_rick);

      provider.syncWithUser(
        const AppUser(
          id: 'u2',
          email: 'outro@exemplo.com',
          displayName: 'Outro',
          isCloud: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.favoritesCount, 0);
      // Os dados do primeiro usuario continuam guardados, so nao visiveis.
      expect(storage.data['u1']!.containsKey(1), isTrue);
    });

    test('notifica os ouvintes a cada alteracao (RF05 - tela reativa)',
        () async {
      final _FakeStorage storage = _FakeStorage();
      final CollectionProvider provider = await _providerFor(storage);

      int notifications = 0;
      provider.addListener(() => notifications += 1);

      await provider.toggleFavorite(_rick);

      expect(notifications, greaterThan(0));
    });
  });
}
