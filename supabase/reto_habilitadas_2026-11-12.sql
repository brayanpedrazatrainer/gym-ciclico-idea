-- Reto "Diciembre sin culpa" y alta de cuentas por lista · aplicado el 2026-11-12 en gym-ciclico-club
-- Ya está aplicado: este archivo es el registro de lo que se corrió.

-- Lista de habilitadas: solo puede crear cuenta quien esté aquí.
-- Se llena desde el panel de Supabase (Table Editor o SQL Editor); nadie la ve desde el Reino.
create table public.habilitadas (
  correo text primary key,
  plan   text not null default 'reto',
  inicio timestamptz,          -- null = sin fecha de inicio (Standard)
  fin    timestamptz,          -- null = no vence (Standard)
  nota   text,
  creada timestamptz not null default now()
);
alter table public.habilitadas enable row level security;
revoke all on public.habilitadas from anon, authenticated;

-- El correo se guarda siempre en minúscula y sin espacios, como lo guarda Supabase
create or replace function public.normalizar_habilitada()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.correo := lower(trim(new.correo));
  return new;
end;
$$;
revoke all on function public.normalizar_habilitada() from public, anon, authenticated;
create trigger normalizar_correo
  before insert or update on public.habilitadas
  for each row execute function public.normalizar_habilitada();

-- Cada reina guarda las fechas de su plan
alter table public.reinas add column inicio timestamptz, add column fin timestamptz;

-- Al crear una cuenta: copia plan y fechas desde la lista; si el correo no está, no se crea
create or replace function public.nueva_reina()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare h record;
begin
  select plan, inicio, fin into h from public.habilitadas where correo = lower(new.email);
  if not found then
    raise exception 'correo no habilitado'
      using hint = 'Agrega el correo a public.habilitadas antes de crear la cuenta';
  end if;
  insert into public.reinas (id, correo, plan, inicio, fin)
  values (new.id, new.email, h.plan, h.inicio, h.fin);
  return new;
end;
$$;
revoke execute on function public.nueva_reina() from public, anon, authenticated;

-- Qué puede ver ella hoy. La hora la pone la base de datos, no su celular.
create or replace function public.mi_acceso()
returns table (plan text, estado text, inicio timestamptz, fin timestamptz)
language sql stable security invoker set search_path = ''
as $$
  select r.plan,
         case when r.plan = 'vencido'                     then 'terminado'
              when r.fin is not null and now() >= r.fin   then 'terminado'
              when r.inicio is not null and now() < r.inicio then 'antes'
              else 'activo' end,
         r.inicio, r.fin
  from public.reinas r
  where r.id = auth.uid();
$$;
revoke all on function public.mi_acceso() from public, anon;
grant execute on function public.mi_acceso() to authenticated;

/* ---------------------------------------------------------------
   CÓMO SE USA (SQL Editor de gym-ciclico-club)

   Habilitar a las que pagaron el reto (pega todos los correos de una vez):
     insert into public.habilitadas (correo, plan, inicio, fin)
     select c, 'reto', '2026-12-01 00:00-05', '2027-01-01 00:00-05'
     from unnest(array['correo1@gmail.com', 'correo2@gmail.com']) as c
     on conflict (correo) do nothing;

   Habilitar a una de Standard (antes de crearle la cuenta o de que ella la cree):
     insert into public.habilitadas (correo, plan) values ('correo@gmail.com', 'standard');

   Pasar a Standard a una del reto que compró el Club:
     update public.reinas set plan = 'standard', inicio = null, fin = null
     where correo = 'correo@gmail.com';
   --------------------------------------------------------------- */
