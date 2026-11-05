-- Bokiama Tours & Travel
-- Initial Supabase database migration
-- Apply once in Supabase Dashboard > SQL Editor.
-- Keep this file under supabase/migrations/ in the project for version control.

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Shared updated_at trigger
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- User profiles and owner authorization
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role text not null default 'customer'
    check (role in ('customer', 'owner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_bokiama_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'owner'
  );
$$;

revoke all on function public.is_bokiama_owner() from public;
grant execute on function public.is_bokiama_owner() to authenticated;

-- ---------------------------------------------------------------------------
-- Destination and tour catalogue
-- ---------------------------------------------------------------------------

create table public.destinations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  country_code text not null,
  region text,
  description text,
  is_published boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint destinations_country_code_check
    check (country_code ~ '^[A-Z]{2}$')
);

create table public.tour_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text,
  created_at timestamptz not null default now()
);

create table public.tours (
  id uuid primary key default gen_random_uuid(),
  destination_id uuid not null references public.destinations(id),
  category_id uuid references public.tour_categories(id) on delete set null,
  title text not null,
  slug text not null unique,
  summary text,
  description text,
  duration_days integer not null check (duration_days > 0),
  duration_nights integer not null default 0 check (duration_nights >= 0),
  highlights text[] not null default '{}',
  inclusions text[] not null default '{}',
  exclusions text[] not null default '{}',
  meeting_point text,
  is_published boolean not null default false,
  is_featured boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tours_destination_id_idx on public.tours(destination_id);
create index tours_category_id_idx on public.tours(category_id);
create index tours_public_listing_idx
  on public.tours(is_published, is_featured, display_order);

create table public.tour_images (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  caption text,
  is_cover boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint tour_images_storage_path_nonempty check (length(trim(storage_path)) > 0)
);

create index tour_images_tour_id_idx on public.tour_images(tour_id);

create unique index one_cover_image_per_tour
  on public.tour_images(tour_id)
  where is_cover = true;

create table public.tour_itineraries (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours(id) on delete cascade,
  day_number integer not null check (day_number > 0),
  title text not null,
  description text,
  overnight_location text,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (tour_id, day_number)
);

create index tour_itineraries_tour_id_idx on public.tour_itineraries(tour_id);

-- Supports per-person (adult/child) and private/group pricing.
-- A row uses either per_person or group pricing, never both.
create table public.tour_pricing_options (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours(id) on delete cascade,
  label text not null,
  pricing_type text not null
    check (pricing_type in ('per_person', 'group')),
  currency_code text not null
    check (currency_code ~ '^[A-Z]{3}$'),
  adult_price numeric(12,2),
  child_price numeric(12,2),
  group_price numeric(12,2),
  minimum_group_size integer,
  maximum_group_size integer,
  notes text,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, tour_id),
  constraint pricing_amounts_check check (
    (
      pricing_type = 'per_person'
      and adult_price is not null and adult_price >= 0
      and (child_price is null or child_price >= 0)
      and group_price is null
      and minimum_group_size is null
      and maximum_group_size is null
    )
    or
    (
      pricing_type = 'group'
      and group_price is not null and group_price >= 0
      and adult_price is null
      and child_price is null
      and (minimum_group_size is null or minimum_group_size > 0)
      and (maximum_group_size is null or maximum_group_size >= minimum_group_size)
    )
  )
);

create index tour_pricing_options_tour_id_idx
  on public.tour_pricing_options(tour_id, is_active, display_order);

create table public.tour_departures (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz,
  max_capacity integer check (max_capacity is null or max_capacity > 0),
  seats_reserved integer not null default 0 check (seats_reserved >= 0),
  status text not null default 'open'
    check (status in ('open', 'closed', 'cancelled', 'completed')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, tour_id),
  check (ends_at is null or ends_at >= starts_at),
  check (max_capacity is null or seats_reserved <= max_capacity)
);

create index tour_departures_tour_date_idx
  on public.tour_departures(tour_id, starts_at, status);

-- ---------------------------------------------------------------------------
-- Booking requests and manual payments
-- ---------------------------------------------------------------------------

create table public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  booking_reference text not null unique
    default ('BOK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  customer_id uuid default auth.uid() references auth.users(id) on delete set null,
  tour_id uuid not null,
  departure_id uuid,
  pricing_option_id uuid,
  contact_name text not null,
  contact_email text not null,
  contact_phone text not null,
  country text,
  adults integer not null default 1 check (adults >= 0),
  children integer not null default 0 check (children >= 0),
  group_size integer not null default 0 check (group_size >= 0),
  traveller_count integer generated always as (
    case when group_size > 0 then group_size else adults + children end
  ) stored,
  travellers jsonb not null default '[]'::jsonb,
  special_requests text,
  status text not null default 'requested'
    check (status in (
      'requested', 'approved', 'awaiting_payment',
      'confirmed', 'declined', 'cancelled', 'completed'
    )),
  admin_notes text,
  approved_at timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_has_party check (
    (group_size > 0 and adults = 0 and children = 0)
    or
    (group_size = 0 and adults + children > 0)
  ),
  constraint booking_contact_name_nonempty check (length(trim(contact_name)) > 0),
  constraint booking_contact_email_nonempty check (length(trim(contact_email)) > 0),
  constraint booking_contact_phone_nonempty check (length(trim(contact_phone)) > 0),
  constraint booking_travellers_array check (jsonb_typeof(travellers) = 'array'),
  constraint booking_tour_fk foreign key (tour_id)
    references public.tours(id),
  constraint booking_departure_tour_fk foreign key (departure_id, tour_id)
    references public.tour_departures(id, tour_id),
  constraint booking_pricing_tour_fk foreign key (pricing_option_id, tour_id)
    references public.tour_pricing_options(id, tour_id)
);

create index booking_requests_tour_id_idx on public.booking_requests(tour_id);
create index booking_requests_customer_id_idx on public.booking_requests(customer_id);
create index booking_requests_status_created_idx
  on public.booking_requests(status, created_at desc);

create table public.booking_payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.booking_requests(id) on delete cascade,
  payment_method text not null
    check (payment_method in ('mpesa', 'bank_transfer')),
  amount numeric(12,2) not null check (amount > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  transaction_reference text,
  payment_date timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected', 'refunded')),
  proof_storage_path text,
  admin_notes text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index booking_payments_booking_id_idx on public.booking_payments(booking_id);
create index booking_payments_status_idx on public.booking_payments(status);

-- ---------------------------------------------------------------------------
-- Public business settings
-- ---------------------------------------------------------------------------

create table public.site_settings (
  setting_key text primary key,
  setting_value jsonb not null,
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Payment instructions shown to customers after a booking is approved.
-- Store only the business's intended customer-facing instructions here.
create table public.payment_method_settings (
  method text primary key
    check (method in ('mpesa', 'bank_transfer')),
  display_name text not null,
  instructions jsonb not null default '{}'::jsonb,
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger destinations_set_updated_at before update on public.destinations
  for each row execute function public.set_updated_at();
create trigger tours_set_updated_at before update on public.tours
  for each row execute function public.set_updated_at();
create trigger pricing_set_updated_at before update on public.tour_pricing_options
  for each row execute function public.set_updated_at();
create trigger departures_set_updated_at before update on public.tour_departures
  for each row execute function public.set_updated_at();
create trigger booking_requests_set_updated_at before update on public.booking_requests
  for each row execute function public.set_updated_at();
create trigger booking_payments_set_updated_at before update on public.booking_payments
  for each row execute function public.set_updated_at();
create trigger site_settings_set_updated_at before update on public.site_settings
  for each row execute function public.set_updated_at();
create trigger payment_method_settings_set_updated_at
  before update on public.payment_method_settings
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.destinations enable row level security;
alter table public.tour_categories enable row level security;
alter table public.tours enable row level security;
alter table public.tour_images enable row level security;
alter table public.tour_itineraries enable row level security;
alter table public.tour_pricing_options enable row level security;
alter table public.tour_departures enable row level security;
alter table public.booking_requests enable row level security;
alter table public.booking_payments enable row level security;
alter table public.site_settings enable row level security;
alter table public.payment_method_settings enable row level security;

-- Remove broad default privileges first.
revoke all on table
  public.profiles,
  public.destinations,
  public.tour_categories,
  public.tours,
  public.tour_images,
  public.tour_itineraries,
  public.tour_pricing_options,
  public.tour_departures,
  public.booking_requests,
  public.booking_payments,
  public.site_settings,
  public.payment_method_settings
from anon, authenticated;

-- Public catalogue: read only. RLS narrows this to published content.
grant select on
  public.destinations,
  public.tour_categories,
  public.tours,
  public.tour_images,
  public.tour_itineraries,
  public.tour_pricing_options,
  public.tour_departures
to anon, authenticated;

create policy "Public can read published destinations"
  on public.destinations for select to anon, authenticated
  using (is_published or (select public.is_bokiama_owner()));

create policy "Public can read tour categories"
  on public.tour_categories for select to anon, authenticated
  using (true);

create policy "Public can read published tours"
  on public.tours for select to anon, authenticated
  using (
    is_published
    or (select public.is_bokiama_owner())
  );

create policy "Public can read images for published tours"
  on public.tour_images for select to anon, authenticated
  using (
    exists (
      select 1 from public.tours t
      where t.id = tour_id and t.is_published
    )
    or (select public.is_bokiama_owner())
  );

create policy "Public can read itineraries for published tours"
  on public.tour_itineraries for select to anon, authenticated
  using (
    exists (
      select 1 from public.tours t
      where t.id = tour_id and t.is_published
    )
    or (select public.is_bokiama_owner())
  );

create policy "Public can read active pricing for published tours"
  on public.tour_pricing_options for select to anon, authenticated
  using (
    (
      is_active
      and exists (
        select 1 from public.tours t
        where t.id = tour_id and t.is_published
      )
    )
    or (select public.is_bokiama_owner())
  );

create policy "Public can read open departures for published tours"
  on public.tour_departures for select to anon, authenticated
  using (
    (
      status = 'open'
      and exists (
        select 1 from public.tours t
        where t.id = tour_id and t.is_published
      )
    )
    or (select public.is_bokiama_owner())
  );

-- Owner has full catalogue control.
grant insert, update, delete on
  public.destinations,
  public.tour_categories,
  public.tours,
  public.tour_images,
  public.tour_itineraries,
  public.tour_pricing_options,
  public.tour_departures
to authenticated;

create policy "Owner manages destinations"
  on public.destinations for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner manages tour categories"
  on public.tour_categories for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner manages tours"
  on public.tours for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner manages tour images"
  on public.tour_images for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner manages tour itineraries"
  on public.tour_itineraries for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner manages tour pricing"
  on public.tour_pricing_options for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner manages tour departures"
  on public.tour_departures for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

-- Profiles: users can read/update their own basic profile.
grant select on public.profiles to authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

create policy "Users read their own profile and owner reads all"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_bokiama_owner()));

create policy "Users update their own basic profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Booking requests: public can submit a request, but cannot read or change it.
-- Sensitive booking records are only readable/manageable by the owner.
grant insert (
  tour_id, departure_id, pricing_option_id,
  contact_name, contact_email, contact_phone, country,
  adults, children, group_size, travellers, special_requests
) on public.booking_requests to anon, authenticated;

grant select, update, delete on public.booking_requests to authenticated;

create policy "Visitors can submit requests for published tours"
  on public.booking_requests for insert to anon, authenticated
  with check (
    status = 'requested'
    and customer_id is not distinct from (select auth.uid())
    and exists (
      select 1 from public.tours t
      where t.id = tour_id and t.is_published
    )
    and (
      departure_id is null
      or exists (
        select 1 from public.tour_departures d
        where d.id = departure_id
          and d.tour_id = booking_requests.tour_id
          and d.status = 'open'
      )
    )
    and (
      pricing_option_id is null
      or exists (
        select 1 from public.tour_pricing_options p
        where p.id = pricing_option_id
          and p.tour_id = booking_requests.tour_id
          and p.is_active
      )
    )
  );

create policy "Owner reads booking requests"
  on public.booking_requests for select to authenticated
  using ((select public.is_bokiama_owner()));

create policy "Owner updates booking requests"
  on public.booking_requests for update to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner deletes booking requests"
  on public.booking_requests for delete to authenticated
  using ((select public.is_bokiama_owner()));

-- Payments are private owner-managed records. No public payment writes.
grant select, insert, update, delete on public.booking_payments to authenticated;

create policy "Owner reads payments"
  on public.booking_payments for select to authenticated
  using ((select public.is_bokiama_owner()));

create policy "Owner creates payments"
  on public.booking_payments for insert to authenticated
  with check ((select public.is_bokiama_owner()));

create policy "Owner updates payments"
  on public.booking_payments for update to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Owner deletes payments"
  on public.booking_payments for delete to authenticated
  using ((select public.is_bokiama_owner()));

-- Public site settings are read-only to visitors.
grant select on public.site_settings to anon, authenticated;
grant insert, update, delete on public.site_settings to authenticated;

grant select on public.payment_method_settings to anon, authenticated;
grant insert, update, delete on public.payment_method_settings to authenticated;

create policy "Visitors read public site settings"
  on public.site_settings for select to anon, authenticated
  using (is_public or (select public.is_bokiama_owner()));

create policy "Owner manages site settings"
  on public.site_settings for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

create policy "Visitors read enabled payment methods"
  on public.payment_method_settings for select to anon, authenticated
  using (is_enabled or (select public.is_bokiama_owner()));

create policy "Owner manages payment method settings"
  on public.payment_method_settings for all to authenticated
  using ((select public.is_bokiama_owner()))
  with check ((select public.is_bokiama_owner()));

commit;

-- ---------------------------------------------------------------------------
-- AFTER the first owner account has signed up, promote it using SQL Editor:
--
-- update public.profiles
-- set role = 'owner'
-- where id = (
--   select id from auth.users
--   where email = 'YOUR_OWNER_EMAIL'
-- );
--
-- Replace YOUR_OWNER_EMAIL with the email used for your Bokiama admin login.
-- Run this separately after creating that account. Never expose service_role
-- credentials in browser code.
-- ---------------------------------------------------------------------------
