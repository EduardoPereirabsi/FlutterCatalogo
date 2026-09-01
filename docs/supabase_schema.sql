-- =====================================================================
-- Catalogo do Multiverso - schema do BONUS (RF06 nuvem + RF07 auth real)
-- Cole este script inteiro no SQL Editor do painel do Supabase e execute.
-- =====================================================================

-- Tabela unica com a colecao pessoal de cada usuario.
-- A chave primaria composta (user_id, character_id) e o que permite o
-- `upsert` do app funcionar sem consulta previa.
create table if not exists public.collection_items (
  user_id      uuid        not null references auth.users (id) on delete cascade,
  character_id integer     not null,
  is_favorite  boolean     not null default false,
  is_watched   boolean     not null default false,
  -- Snapshot do personagem (nome, imagem, especie...) para que as telas de
  -- Favoritos e "Ja vi" abram sem precisar chamar a API de novo.
  payload      jsonb       not null default '{}'::jsonb,
  updated_at   timestamptz not null default now(),
  primary key (user_id, character_id)
);

-- Consulta mais frequente do app: "tudo do usuario X".
create index if not exists collection_items_user_idx
  on public.collection_items (user_id);

-- ---------------------------------------------------------------------
-- Row Level Security: sem isso qualquer usuario autenticado leria a
-- colecao dos outros. Com RLS ativo, o Postgres filtra por auth.uid()
-- em TODA consulta, mesmo que o app envie a query errada.
-- ---------------------------------------------------------------------
alter table public.collection_items enable row level security;

drop policy if exists "usuario le a propria colecao" on public.collection_items;
create policy "usuario le a propria colecao"
  on public.collection_items
  for select
  using (auth.uid() = user_id);

drop policy if exists "usuario insere na propria colecao" on public.collection_items;
create policy "usuario insere na propria colecao"
  on public.collection_items
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "usuario atualiza a propria colecao" on public.collection_items;
create policy "usuario atualiza a propria colecao"
  on public.collection_items
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "usuario apaga da propria colecao" on public.collection_items;
create policy "usuario apaga da propria colecao"
  on public.collection_items
  for delete
  using (auth.uid() = user_id);
