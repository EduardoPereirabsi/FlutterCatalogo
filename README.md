# Catálogo do Multiverso

Aplicativo Flutter de catálogo interativo desenvolvido para o **Projeto Somativo
da disciplina de Desenvolvimento Mobile Híbrido** (Bacharelado em Sistemas de
Informação).

O app consome a [Rick and Morty API](https://rickandmortyapi.com/) e permite
navegar por um catálogo paginado de personagens, ver detalhes, favoritar e
manter uma lista de personagens que o usuário "já viu" — tudo protegido por
login e preservado entre reinícios do aplicativo.

| | |
|---|---|
| **Tema** | Catálogo de personagens do multiverso (Rick and Morty) |
| **API** | `https://rickandmortyapi.com/api` — pública, gratuita, sem chave |
| **Persistência** | Local (`shared_preferences`) **+ bônus** nuvem (Supabase / Postgres) |
| **Login** | Local (hash SHA-256 + salt) **+ bônus** autenticação real (Supabase Auth) |
| **Flutter** | verificado em 3.47.2 / Dart 3.13.2 (mínimo 3.24) |

---

## Sumário

- [Como rodar](#como-rodar)
- [Ativando o bônus (Supabase)](#ativando-o-bônus-supabase)
- [Arquitetura](#arquitetura)
- [Mapa dos requisitos funcionais](#mapa-dos-requisitos-funcionais)
- [Decisões técnicas](#decisões-técnicas)
- [Testes](#testes)

---

## Como rodar

Pré-requisito: **Flutter 3.24 ou superior** (verificado no 3.47.2) com o
Android SDK configurado — confira com `flutter doctor`.

O repositório já inclui as pastas de plataforma (`android/`, `ios/`, `web/`),
então basta:

```bash
flutter pub get
```

```bash
flutter run
```

Sem nenhuma configuração extra o aplicativo roda em **modo local**: as contas e
a coleção ficam salvas no próprio aparelho. Isso cobre integralmente os
requisitos obrigatórios RF06 e RF07.

---

## Ativando o bônus (Supabase)

1. Crie um projeto gratuito em <https://supabase.com>.
2. No painel, abra **SQL Editor** e execute
   [`docs/supabase_schema.sql`](docs/supabase_schema.sql) — ele cria a tabela
   `collection_items` e as políticas de Row Level Security.
3. Em **Authentication → Providers → Email**, desligue *Confirm email* para que
   o cadastro entre direto (facilita a demonstração).
4. Copie **Project URL** e a **publishable key** (nas versões antigas do painel
   ela se chama *anon public key* — o app aceita as duas) em *Settings → API* e rode:

```bash
flutter run --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE
```

As credenciais **não ficam no repositório**: são injetadas em tempo de
compilação por `--dart-define` e lidas em `String.fromEnvironment`
(`lib/services/supabase_service.dart`). Se elas não forem informadas,
`SupabaseService.isEnabled` fica `false` e o app opera 100% local — quem clonar
o repositório consegue rodar tudo sem ter uma conta Supabase.

---

## Arquitetura

```
lib/
├── main.dart                  # injeção de dependência + AuthGate (navegação condicional)
├── models/                    # objetos de domínio e parsing defensivo de JSON
│   ├── app_user.dart
│   ├── character.dart
│   └── collection_entry.dart
├── services/                  # tudo que fala com o mundo externo
│   ├── api_service.dart       # HTTP + tradução de erros
│   ├── local_storage_service.dart
│   ├── supabase_service.dart
│   └── auth/
│       ├── auth_service.dart          # contrato
│       ├── local_auth_service.dart    # baseline
│       └── supabase_auth_service.dart # bônus
├── providers/                 # estado observável (ChangeNotifier)
│   ├── auth_provider.dart
│   ├── catalog_provider.dart
│   └── collection_provider.dart
├── screens/                   # uma tela por arquivo
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── detail_screen.dart
│   ├── favorites_screen.dart
│   └── watched_screen.dart
├── widgets/                   # componentes reutilizáveis
│   ├── character_card.dart
│   ├── character_image.dart
│   ├── collection_list.dart
│   └── feedback_views.dart
└── theme/
    └── app_theme.dart         # paleta com contraste WCAG AA verificado
```

A regra que organiza as pastas é **a direção da dependência**:

```
screens → providers → services → models
```

Nenhuma tela chama `http` diretamente e nenhum service conhece um `Widget`.
É isso que permite testar `CollectionProvider` com um armazenamento falso, sem
subir a interface (`test/collection_provider_test.dart`).

---

## Mapa dos requisitos funcionais

| RF | O que é | Onde está |
|----|---------|-----------|
| RF01 | Catálogo em `GridView` + botão "Carregar Mais" + placeholder | `screens/home_screen.dart`, `providers/catalog_provider.dart`, `widgets/character_image.dart` |
| RF02 | Navegação para os detalhes com `Navigator.push` | `screens/home_screen.dart` (`_openDetail`) |
| RF03 | Detalhes com 2ª requisição e imagem ampliada | `screens/detail_screen.dart` |
| RF04 | Favoritar/desfavoritar com `provider` | `providers/collection_provider.dart`, `screens/detail_screen.dart` |
| RF05 | Tela de Favoritos reativa | `screens/favorites_screen.dart` |
| RF06 | Persistência local + sincronização em nuvem | `services/local_storage_service.dart`, `services/supabase_service.dart` |
| RF07 | Login obrigatório + lista "Já vi" | `screens/login_screen.dart`, `main.dart` (`AuthGate`), `screens/watched_screen.dart` |
| RF08 | Busca que navega direto para os detalhes | `screens/home_screen.dart` (`_SearchBar`, `_runSearch`) |
| RF09 | `CircularProgressIndicator`, `FutureBuilder` e erros amigáveis | `widgets/feedback_views.dart`, `screens/detail_screen.dart` |
| RF10 | `Semantics`, contraste, fonte ampliada, alvos de 48 dp | `theme/app_theme.dart` e todos os widgets |

---

## Decisões técnicas

**Por que `Provider` e não `setState` para favoritos.**
O toque acontece na Tela de Detalhes, mas quem precisa se redesenhar é o card do
catálogo e a Tela de Favoritos — widgets em outros galhos da árvore. Com
`setState` seria necessário devolver resultados pela pilha do `Navigator` e
repassá-los manualmente a cada tela. Com um `ChangeNotifier` global, cada widget
se inscreve no que lhe interessa e o estado sobrevive ao `dispose()` das telas.

**Por que `FutureBuilder` só na Tela de Detalhes.**
`FutureBuilder` é ideal para uma requisição única cujo resultado morre junto com
a rota. Ele é inadequado para o catálogo, porque a lista *acumula* páginas: cada
"Carregar Mais" produziria um novo `Future` e descartaria o que já estava na
tela. Por isso o catálogo usa um `ChangeNotifier` que acumula em memória, e os
detalhes usam `FutureBuilder`. O `Future` dos detalhes é criado no `initState`,
nunca no `build` — caso contrário favoritar dispararia uma nova requisição HTTP.

**Por que `shared_preferences` e não `sqflite`/`hive`.**
O volume é pequeno (dezenas de itens por usuário) e sempre lido/gravado por
inteiro; não há consulta por campo, ordenação no banco nem junção. `sqflite`
traria migrações e SQL para um problema que é literalmente "salvar um JSON".
`hive` seria mais rápido, mas exige geração de código (`build_runner`) e um
diretório de inicialização. `shared_preferences` resolve com zero configuração.

**Estratégia local-first.**
Toda alteração é gravada no disco **antes** de ir para a nuvem, e é a gravação
local que confirma a ação para o usuário. Se a rede falhar, aparece um aviso
não bloqueante com botão "Tentar de novo" e o app continua utilizável offline.
A reconciliação entre local e nuvem é *last-write-wins* pelo campo `updatedAt`.

**Falha de rede no meio da sessão.**
Se a API cair durante o "Carregar Mais", os itens já carregados permanecem na
tela: apenas uma faixa de erro aparece acima do botão, que continua clicável.
Só quando não há absolutamente nada em tela é que o erro ocupa a tela inteira
com o botão "Tentar de novo".

---

## Testes

```bash
flutter test
```

**15 testes, todos passando**, e `flutter analyze` sem nenhum aviso.

- `test/character_model_test.dart` — parsing defensivo do JSON, incluindo o caso
  do item sem imagem exigido pelo RF01.
- `test/collection_provider_test.dart` — regras de favoritos/vistos,
  persistência entre sessões e isolamento entre usuários diferentes.
- `test/app_flow_test.dart` — percorre o app inteiro com um `ApiService` falso:
  login obrigatório (RF07), paginação que acumula (RF01), falha de rede no
  "Carregar Mais" preservando o que já está em tela (RF09), detalhes com as duas
  requisições (RF03), favoritar refletindo na Tela de Favoritos (RF04/RF05),
  persistência sobrevivendo a "fechar e reabrir" (RF06) e busca navegando direto
  para os detalhes (RF08).

Foi esse último arquivo que revelou um defeito real durante o desenvolvimento: o
placeholder de "sem imagem" estourava o layout quando desenhado em uma miniatura
de 48 dp. A correção está em `widgets/character_image.dart`, que agora adapta o
conteúdo ao tamanho da caixa.
