import 'package:catalogo_multiverso/main.dart';
import 'package:catalogo_multiverso/models/character.dart';
import 'package:catalogo_multiverso/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ApiService] falso: responde na hora, sem tocar na rede.
///
/// Como todas as telas recebem o service pelo `Provider`, trocar o real por
/// este nao exige mudar uma linha de UI - e o retorno pratico de ter separado
/// `services/` de `screens/`.
class _FakeApiService extends ApiService {
  _FakeApiService({this.falharNaPagina2 = false});

  /// Simula a API caindo no meio da sessao, durante o "Carregar Mais".
  final bool falharNaPagina2;

  int chamadasDeLista = 0;

  static Character _personagem(int id) => Character(
        id: id,
        name: id == 1 ? 'Rick Sanchez' : 'Personagem $id',
        status: id.isEven ? 'Dead' : 'Alive',
        species: 'Human',
        type: '',
        gender: 'Male',
        // URL inexistente de proposito: no ambiente de teste toda imagem de
        // rede falha, entao isto tambem exercita o placeholder do RF01.
        imageUrl: 'https://exemplo.invalido/$id.jpeg',
        originName: 'Earth (C-137)',
        locationName: 'Citadel of Ricks',
        episodeUrls: const <String>['https://exemplo.invalido/episode/1'],
      );

  @override
  Future<CharacterPage> fetchCharacters({int page = 1}) async {
    chamadasDeLista += 1;
    if (page == 2 && falharNaPagina2) {
      throw const ApiException('Sem conexao com a internet.');
    }
    final int inicio = (page - 1) * 20 + 1;
    return CharacterPage(
      items: List<Character>.generate(20, (int i) => _personagem(inicio + i)),
      hasNextPage: page < 3,
      totalCount: 60,
    );
  }

  @override
  Future<Character> fetchCharacterById(int id) async => _personagem(id);

  @override
  Future<Episode> fetchEpisode(String url) async =>
      const Episode(name: 'Pilot', airDate: 'December 2, 2013', code: 'S01E01');

  @override
  Future<Character> searchFirstByName(String term) async => _personagem(1);
}

/// Cria a conta e entra, deixando o app na tela de catalogo.
Future<void> _entrar(WidgetTester tester) async {
  await tester.tap(find.text('Criar uma conta'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome completo'),
    'Eduardo Pereira',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-mail'),
    'aluno@exemplo.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Senha'),
    'senha123',
  );
  await tester.tap(find.text('Criar conta e entrar'));
  await tester.pumpAndSettle();
}

/// Rola o catalogo ate o rodape de paginacao ficar visivel.
///
/// Precisa dizer QUAL scrollable: o `TextField` da busca tambem contem um
/// `Scrollable` interno, entao o padrao do `scrollUntilVisible` encontra dois.
Future<void> _rolarAteORodape(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Carregar Mais'),
    400,
    scrollable: find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Cada teste comeca com o armazenamento vazio.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('RF07 - o catalogo so aparece depois do login', (tester) async {
    await tester.pumpWidget(
      CatalogoMultiversoApp(apiOverride: _FakeApiService()),
    );
    await tester.pumpAndSettle();

    // Sem sessao: o AuthGate renderiza o login e nenhum item do catalogo.
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Rick Sanchez'), findsNothing);

    await _entrar(tester);

    expect(find.text('Catalogo do Multiverso'), findsOneWidget);
    expect(find.text('Rick Sanchez'), findsOneWidget);
  });

  testWidgets('RF01 - "Carregar Mais" acrescenta a proxima pagina',
      (tester) async {
    final _FakeApiService api = _FakeApiService();
    await tester.pumpWidget(CatalogoMultiversoApp(apiOverride: api));
    await tester.pumpAndSettle();
    await _entrar(tester);

    await _rolarAteORodape(tester);
    expect(find.text('Exibindo 20 de 60 personagens'), findsOneWidget);

    await tester.tap(find.text('Carregar Mais'));
    await tester.pumpAndSettle();

    // A lista ACUMULOU: 40, nao 20 substituidos por outros 20.
    await _rolarAteORodape(tester);
    expect(find.text('Exibindo 40 de 60 personagens'), findsOneWidget);
    expect(api.chamadasDeLista, 2);
  });

  testWidgets('RF09 - falha no "Carregar Mais" preserva os itens em tela',
      (tester) async {
    await tester.pumpWidget(
      CatalogoMultiversoApp(apiOverride: _FakeApiService(falharNaPagina2: true)),
    );
    await tester.pumpAndSettle();
    await _entrar(tester);

    await _rolarAteORodape(tester);
    await tester.tap(find.text('Carregar Mais'));
    await tester.pumpAndSettle();

    // Mensagem amigavel, e o catalogo ja carregado continua la.
    await _rolarAteORodape(tester);
    expect(find.text('Sem conexao com a internet.'), findsOneWidget);
    expect(find.text('Exibindo 20 de 60 personagens'), findsOneWidget);
  });

  testWidgets('RF02/RF03/RF04/RF05 - detalhes, favoritar e lista de favoritos',
      (tester) async {
    await tester.pumpWidget(
      CatalogoMultiversoApp(apiOverride: _FakeApiService()),
    );
    await tester.pumpAndSettle();
    await _entrar(tester);

    // RF02 - abre os detalhes a partir do card.
    await tester.tap(find.text('Rick Sanchez').first);
    await tester.pumpAndSettle();

    expect(find.text('Ficha do personagem'), findsOneWidget);

    // RF04 - favoritar troca o rotulo do botao.
    expect(find.text('Favoritar'), findsOneWidget);
    await tester.tap(find.text('Favoritar'));
    await tester.pumpAndSettle();
    expect(find.text('Favorito'), findsOneWidget);

    // RF07 - marcar como visto e independente do favorito.
    await tester.tap(find.text('Marcar como visto'));
    await tester.pumpAndSettle();
    expect(find.text('Ja vi'), findsWidgets);

    // RF03 - a ficha completa fica abaixo da dobra: rolamos ate ela.
    // Os dados vem da 2a requisicao (personagem) e da 3a (episodio).
    await tester.scrollUntilVisible(
      find.text('S01E01 - Pilot (December 2, 2013)'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Earth (C-137)'), findsOneWidget);
    expect(find.text('S01E01 - Pilot (December 2, 2013)'), findsOneWidget);

    // Volta ao catalogo e abre a Tela de Favoritos.
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();

    // RF05 - o item favoritado em OUTRA tela aparece aqui, sem setState.
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.text('Rick Sanchez'), findsOneWidget);
  });

  testWidgets('RF06 - favoritos sobrevivem a reabertura do app',
      (tester) async {
    await tester.pumpWidget(
      CatalogoMultiversoApp(apiOverride: _FakeApiService()),
    );
    await tester.pumpAndSettle();
    await _entrar(tester);

    await tester.tap(find.text('Rick Sanchez').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritar'));
    await tester.pumpAndSettle();

    // Simula fechar e reabrir o app: arvore nova, MESMO armazenamento.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      CatalogoMultiversoApp(apiOverride: _FakeApiService()),
    );
    await tester.pumpAndSettle();

    // A sessao tambem foi restaurada: entramos direto no catalogo.
    expect(find.text('Catalogo do Multiverso'), findsOneWidget);

    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Rick Sanchez'), findsOneWidget);
  });

  testWidgets('RF08 - a busca leva direto para a Tela de Detalhes',
      (tester) async {
    await tester.pumpWidget(
      CatalogoMultiversoApp(apiOverride: _FakeApiService()),
    );
    await tester.pumpAndSettle();
    await _entrar(tester);

    await tester.enterText(find.byType(TextField).first, 'Rick');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Ficha do personagem'), findsOneWidget);
  });
}
