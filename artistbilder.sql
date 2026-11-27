-- =====================================================================
--  ARTISTBILDER (lagt til senere) – lenker til artistbilder fra Deezer
-- =====================================================================
create table if not exists ml_artists (
  key text primary key,
  name text,
  image_url text,
  checked_at timestamptz not null default now()
);
alter table ml_artists enable row level security;
drop policy if exists "ml_artists les"   on ml_artists;
drop policy if exists "ml_artists ny"    on ml_artists;
drop policy if exists "ml_artists endre" on ml_artists;
create policy "ml_artists les" on ml_artists for select to authenticated using (true);
create policy "ml_artists ny" on ml_artists for insert to authenticated
  with check (image_url is null or image_url ~ '^https://[a-z0-9.-]+\.dzcdn\.net/');
create policy "ml_artists endre" on ml_artists for update to authenticated
  using (ml_is_admin())
  with check (ml_is_admin() and (image_url is null or image_url ~ '^https://[a-z0-9.-]+\.dzcdn\.net/'));
