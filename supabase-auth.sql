-- Ejecuta este script en Supabase: SQL Editor > New query > Run
-- (después de haber ejecutado antes supabase.sql, que crea propinas_state)

-- 1) Correos autorizados como máster (solo ellos pueden escribir)
create table if not exists public.propinas_masters (email text primary key);
alter table public.propinas_masters enable row level security; -- sin políticas: el navegador no puede leerla

-- TODO: cambia este correo por el del máster (el mismo con el que crearás el usuario en Authentication)
insert into public.propinas_masters (email) values ('TU_CORREO@ejemplo.com') on conflict do nothing;

-- 2) Función que dice si quien llama es máster (se usa en la app y en las políticas)
create or replace function public.es_master_propinas()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.propinas_masters
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.es_master_propinas() from public;
grant execute on function public.es_master_propinas() to anon, authenticated;

-- 3) Seguridad de los datos: todos leen, solo el máster actualiza
grant select on public.propinas_state to anon, authenticated;
grant update on public.propinas_state to authenticated;
alter table public.propinas_state enable row level security;

drop policy if exists "propinas ver" on public.propinas_state;
create policy "propinas ver" on public.propinas_state
  for select to anon, authenticated using (true);

drop policy if exists "propinas master actualiza" on public.propinas_state;
create policy "propinas master actualiza" on public.propinas_state
  for update to authenticated
  using (public.es_master_propinas())
  with check (public.es_master_propinas());
