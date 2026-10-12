-- Fotos de antes y después (testimonios) · aplicado el 2026-10-11 en gym-ciclico-club
-- Ya está aplicado: este archivo es el registro de lo que se corrió.

-- ¿Es Brayan quien consulta? (se compara contra auth.users, no contra lo que mande el navegador)
create or replace function public.es_admin_reino()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from auth.users
    where id = auth.uid() and email = 'brayanpedrazatrainer@gmail.com'
  );
$$;
revoke all on function public.es_admin_reino() from public, anon;
grant execute on function public.es_admin_reino() to authenticated;

-- Una fila por reina: permiso de publicación y fechas de sus fotos
create table public.fotos_reinas (
  id            uuid primary key references auth.users on delete cascade,
  permiso       text check (permiso in ('con_cara','sin_cara')),
  antes_fecha   timestamptz,
  despues_fecha timestamptz,
  actualizada   timestamptz default now()
);
alter table public.fotos_reinas enable row level security;
revoke all on public.fotos_reinas from anon;

create policy "cada reina ve sus fotos y el admin todas"
  on public.fotos_reinas for select to authenticated
  using (auth.uid() = id or public.es_admin_reino());
create policy "cada reina crea su fila"
  on public.fotos_reinas for insert to authenticated
  with check (auth.uid() = id);
create policy "cada reina actualiza su fila"
  on public.fotos_reinas for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

-- El admin necesita ver los correos de todas
create policy "el admin ve todas las reinas"
  on public.reinas for select to authenticated
  using (public.es_admin_reino());

-- Espacio privado para las fotos: carpeta = id de la reina
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 3145728, array['image/jpeg']);

create policy "cada reina sube sus fotos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "cada reina reemplaza sus fotos"
  on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "cada reina ve sus fotos y el admin todas"
  on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and ((storage.foldername(name))[1] = auth.uid()::text or public.es_admin_reino()));

-- nueva_reina solo debe correr como disparador al crear una cuenta, no desde la API
revoke execute on function public.nueva_reina() from public, anon, authenticated;

-- Permisos de tabla (el proyecto no los da por defecto). RLS sigue decidiendo las filas.
grant select on public.reinas to authenticated;
grant select, insert, update on public.fotos_reinas to authenticated;
revoke truncate, trigger, references on public.reinas from anon, authenticated;
revoke truncate, trigger, references on public.fotos_reinas from anon, authenticated;

-- 2026-10-12: cada reina puede quitar sus propias fotos para volver a tomarlas
create policy "cada reina quita sus fotos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);
