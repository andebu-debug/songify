-- =====================================================================
--  SONGIFY versjon 12 – album kan deles med alle
--  Lim inn alt i SQL Editor i Supabase og trykk «Run». Trygt å kjøre flere ganger.
-- =====================================================================

alter table ml_playlists add column if not exists shared boolean not null default false;

drop policy if exists "ml_playlists egne"  on ml_playlists;
drop policy if exists "ml_playlists les"   on ml_playlists;
drop policy if exists "ml_playlists ny"    on ml_playlists;
drop policy if exists "ml_playlists endre" on ml_playlists;
drop policy if exists "ml_playlists slett" on ml_playlists;

-- Du ser dine egne album + felles album. Admin kan endre og slette alle.
create policy "ml_playlists les"   on ml_playlists for select to authenticated
  using (owner = auth.uid() or shared or ml_is_admin());
create policy "ml_playlists ny"    on ml_playlists for insert to authenticated
  with check (owner = auth.uid() and (shared = false or ml_is_admin()));
create policy "ml_playlists endre" on ml_playlists for update to authenticated
  using (owner = auth.uid() or ml_is_admin())
  with check (ml_is_admin() or (owner = auth.uid() and shared = false));
create policy "ml_playlists slett" on ml_playlists for delete to authenticated
  using (owner = auth.uid() or ml_is_admin());
