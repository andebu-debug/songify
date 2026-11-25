-- =====================================================================
--  SONGIFY – oppsett i Supabase
--  1) Bytt admin-koden på linja merket «BYTT» til din egen hemmelige kode
--  2) Lim inn alt i SQL Editor i Supabase og trykk «Run»
--  Trygt å kjøre flere ganger.
-- =====================================================================

-- Admin: den som skriver inn admin-koden i appen blir admin på den enheten
create table if not exists ml_admin_code (id int primary key default 1, code text not null);
insert into ml_admin_code (id, code) values (1, 'Wålemusik')   -- <<< BYTT til din egen hemmelige kode
on conflict (id) do update set code = excluded.code;

create table if not exists ml_admin_ids (user_id uuid primary key references auth.users on delete cascade);

create or replace function ml_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from ml_admin_ids where user_id = auth.uid());
$$;

create or replace function ml_claim_admin(p_code text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  if exists (select 1 from ml_admin_code where code = p_code) then
    insert into ml_admin_ids (user_id) values (auth.uid()) on conflict do nothing;
    return true;
  end if;
  perform pg_sleep(1);
  return false;
end $$;

-- Brukere (valgfritt navn, så admin ser hvem som eier hva)
create table if not exists ml_profiles (
  id uuid primary key references auth.users on delete cascade,
  name text,
  created_at timestamptz not null default now()
);
alter table ml_profiles add column if not exists name text;

-- Låter
create table if not exists ml_songs (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users on delete cascade,
  title text not null,
  artist text not null default '',
  album text not null default '',
  duration real not null default 0,
  size bigint not null default 0,
  file_path text not null,
  cover_path text,
  shared boolean not null default false,   -- true = felles låt som alle får
  created_at timestamptz not null default now()
);

-- Felles låter en bruker har fjernet fra sitt eget bibliotek
create table if not exists ml_hidden (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  song_id uuid not null references ml_songs on delete cascade,
  primary key (user_id, song_id)
);

-- Likte låter (per bruker)
create table if not exists ml_likes (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  song_id uuid not null references ml_songs on delete cascade,
  primary key (user_id, song_id)
);

-- Spillelister (per bruker)
create table if not exists ml_playlists (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  song_ids uuid[] not null default '{}',
  created_at timestamptz not null default now()
);
-- Album kan deles med alle (versjon 12)
alter table ml_playlists add column if not exists shared boolean not null default false;

alter table ml_admin_code enable row level security;
alter table ml_admin_ids  enable row level security;
alter table ml_profiles  enable row level security;
alter table ml_songs     enable row level security;
alter table ml_hidden    enable row level security;
alter table ml_likes     enable row level security;
alter table ml_playlists enable row level security;

-- Profiler
drop policy if exists "ml_profiles les"  on ml_profiles;
drop policy if exists "ml_profiles ny"   on ml_profiles;
drop policy if exists "ml_profiles endre" on ml_profiles;
create policy "ml_profiles les"  on ml_profiles for select to authenticated using (id = auth.uid() or ml_is_admin());
create policy "ml_profiles ny"   on ml_profiles for insert to authenticated with check (id = auth.uid());
create policy "ml_profiles endre" on ml_profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Låter: du ser dine egne + felles. Admin ser alt.
drop policy if exists "ml_songs les"   on ml_songs;
drop policy if exists "ml_songs ny"    on ml_songs;
drop policy if exists "ml_songs endre" on ml_songs;
drop policy if exists "ml_songs slett" on ml_songs;
create policy "ml_songs les"   on ml_songs for select to authenticated
  using (owner = auth.uid() or shared or ml_is_admin());
create policy "ml_songs ny"    on ml_songs for insert to authenticated
  with check (owner = auth.uid() and (shared = false or ml_is_admin()));
create policy "ml_songs endre" on ml_songs for update to authenticated
  using (owner = auth.uid() or ml_is_admin())
  with check (ml_is_admin() or (owner = auth.uid() and shared = false));
create policy "ml_songs slett" on ml_songs for delete to authenticated
  using (owner = auth.uid() or ml_is_admin());

-- Skjulte, likte og spillelister: bare dine egne
drop policy if exists "ml_hidden egne"    on ml_hidden;
drop policy if exists "ml_likes egne"     on ml_likes;
drop policy if exists "ml_playlists egne" on ml_playlists;
create policy "ml_hidden egne"    on ml_hidden    for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "ml_likes egne"     on ml_likes     for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "ml_playlists les"   on ml_playlists;
drop policy if exists "ml_playlists ny"    on ml_playlists;
drop policy if exists "ml_playlists endre" on ml_playlists;
drop policy if exists "ml_playlists slett" on ml_playlists;
-- Album: du ser dine egne + felles. Admin kan endre og slette alle.
create policy "ml_playlists les"   on ml_playlists for select to authenticated using (owner = auth.uid() or shared or ml_is_admin());
create policy "ml_playlists ny"    on ml_playlists for insert to authenticated with check (owner = auth.uid() and (shared = false or ml_is_admin()));
create policy "ml_playlists endre" on ml_playlists for update to authenticated
  using (owner = auth.uid() or ml_is_admin())
  with check (ml_is_admin() or (owner = auth.uid() and shared = false));
create policy "ml_playlists slett" on ml_playlists for delete to authenticated using (owner = auth.uid() or ml_is_admin());

-- Lagring av lydfiler og cover (privat bøtte, maks 50 MB per fil)
insert into storage.buckets (id, name, public, file_size_limit)
values ('mine-later', 'mine-later', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "ml filer last opp" on storage.objects;
drop policy if exists "ml filer les"      on storage.objects;
drop policy if exists "ml filer slett"    on storage.objects;
create policy "ml filer last opp" on storage.objects for insert to authenticated
  with check (bucket_id = 'mine-later' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "ml filer les" on storage.objects for select to authenticated
  using (bucket_id = 'mine-later' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or ml_is_admin()
    or exists (select 1 from ml_songs s where s.shared and (s.file_path = name or s.cover_path = name))
  ));
create policy "ml filer slett" on storage.objects for delete to authenticated
  using (bucket_id = 'mine-later' and ((storage.foldername(name))[1] = auth.uid()::text or ml_is_admin()));
