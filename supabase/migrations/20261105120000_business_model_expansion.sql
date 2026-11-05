
-- ============================================================
-- BOKIAMA TOURS & TRAVEL
-- MIGRATION 002: BUSINESS MODEL EXPANSION
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. TRAVEL MARKETS
-- ------------------------------------------------------------

create table public.market_segments (
  code text primary key,
  name text not null unique,
  description text
);

insert into public.market_segments (code, name, description)
values
(
  'kenya_domestic',
  'Kenya Domestic Travel',
  'Kenyan travellers exploring destinations within Kenya.'
),
(
  'inbound_to_kenya',
  'International Visitors to Kenya',
  'International visitors travelling to experience Kenya.'
),
(
  'outbound_from_kenya',
  'Kenya Outbound Travel',
  'Travellers based in Kenya visiting destinations abroad.'
);

create table public.tour_market_segments (
  tour_id uuid not null references public.tours(id) on delete cascade,
  market_segment_code text not null
    references public.market_segments(code),
  primary key (tour_id, market_segment_code)
);

-- ------------------------------------------------------------
-- 2. SIGNATURE TOUR COLLECTIONS
-- ------------------------------------------------------------

create table public.tour_collections (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text,
  is_published boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tour_collection_items (
  collection_id uuid not null
    references public.tour_collections(id) on delete cascade,
  tour_id uuid not null
    references public.tours(id) on delete cascade,
  display_order integer not null default 0,
  primary key (collection_id, tour_id)
);

-- ------------------------------------------------------------
-- 3. PRICING CATEGORIES
-- ------------------------------------------------------------

create table public.pricing_categories (
  code text primary key,
  name text not null unique,
  eligibility_notes text
);

insert into public.pricing_categories
  (code, name, eligibility_notes)
values
(
  'standard',
  'Standard Rate',
  'General pricing where no special eligibility rate applies.'
),
(
  'kenyan_citizen',
  'Kenyan Citizen',
  'Applicable where the traveller qualifies as a Kenyan citizen.'
),
(
  'kenyan_resident',
  'Kenyan Resident',
  'Applicable where the traveller qualifies under resident pricing.'
),
(
  'international_visitor',
  'International Visitor',
  'Applicable visitor pricing for the relevant destination.'
);

alter table public.tour_pricing_options
  add column pricing_category_code text not null default 'standard'
  references public.pricing_categories(code);

-- Expand pricing types without losing existing pricing records.
alter table public.tour_pricing_options
  drop constraint if exists tour_pricing_options_pricing_type_check;

alter table public.tour_pricing_options
  add constraint tour_pricing_options_pricing_type_check
  check (
    pricing_type in (
      'per_person',
      'group',
      'family',
      'custom_quote'
    )
  );

alter table public.tour_pricing_options
  drop constraint if exists pricing_amounts_check;

alter table public.tour_pricing_options
  add constraint pricing_amounts_check check (
    (
      pricing_type = 'per_person'
      and adult_price is not null
      and adult_price >= 0
      and (child_price is null or child_price >= 0)
      and group_price is null
      and minimum_group_size is null
      and maximum_group_size is null
    )
    or
    (
      pricing_type in ('group', 'family')
      and group_price is not null
      and group_price >= 0
      and adult_price is null
      and child_price is null
      and (minimum_group_size is null or minimum_group_size > 0)
      and (
        maximum_group_size is null
        or (
          maximum_group_size >= minimum_group_size
          and maximum_group_size > 0
        )
      )
    )
    or
    (
      pricing_type = 'custom_quote'
      and adult_price is null
      and child_price is null
      and group_price is null
      and minimum_group_size is null
      and maximum_group_size is null
    )
  );

-- ------------------------------------------------------------
-- 4. CUSTOM TRIP REQUESTS
-- ------------------------------------------------------------

create table public.custom_trip_requests (
  id uuid primary key default gen_random_uuid(),

  request_reference text not null unique
    default (
      'TRIP-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))
    ),

  customer_id uuid default auth.uid()
    references auth.users(id) on delete set null,

  contact_name text not null,
  contact_email text not null,
  contact_phone text not null,

  preferred_start_date date,
  flexible_dates boolean not null default false,

  duration_days integer
    check (duration_days is null or duration_days > 0),

  budget_amount numeric(12,2)
    check (budget_amount is null or budget_amount >= 0),

  budget_currency text
    check (
      budget_currency is null
      or budget_currency ~ '^[A-Z]{3}$'
    ),

  traveller_count integer
    check (traveller_count is null or traveller_count > 0),

  travel_mood text,
  interests text[] not null default '{}',
  notes text,

  status text not null default 'requested'
    check (
      status in (
        'requested',
        'planning',
        'quoted',
        'accepted',
        'declined',
        'cancelled',
        'converted'
      )
    ),

  admin_notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (length(trim(contact_name)) > 0),
  check (length(trim(contact_email)) > 0),
  check (length(trim(contact_phone)) > 0)
);

create table public.custom_trip_destinations (
  id uuid primary key default gen_random_uuid(),

  custom_trip_request_id uuid not null
    references public.custom_trip_requests(id) on delete cascade,

  destination_id uuid
    references public.destinations(id) on delete set null,

  destination_name text,

  visit_order integer not null default 1
    check (visit_order > 0),

  notes text,

  check (
    destination_id is not null
    or nullif(trim(destination_name), '') is not null
  )
);

-- ------------------------------------------------------------
-- 5. CUSTOM TRIP QUOTATIONS
-- ------------------------------------------------------------

create table public.custom_trip_quotations (
  id uuid primary key default gen_random_uuid(),

  custom_trip_request_id uuid not null
    references public.custom_trip_requests(id) on delete cascade,

  version integer not null default 1
    check (version > 0),

  currency_code text not null
    check (currency_code ~ '^[A-Z]{3}$'),

  subtotal numeric(12,2) not null default 0
    check (subtotal >= 0),

  taxes_and_fees numeric(12,2) not null default 0
    check (taxes_and_fees >= 0),

  total_amount numeric(12,2) not null
    check (total_amount >= 0),

  valid_until date,

  status text not null default 'draft'
    check (
      status in (
        'draft',
        'sent',
        'accepted',
        'rejected',
        'expired'
      )
    ),

  customer_message text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (custom_trip_request_id, version)
);

create table public.quotation_items (
  id uuid primary key default gen_random_uuid(),

  quotation_id uuid not null
    references public.custom_trip_quotations(id) on delete cascade,

  item_type text not null
    check (
      item_type in (
        'accommodation',
        'transport',
        'activity',
        'entry_fee',
        'meal',
        'guide',
        'other'
      )
    ),

  description text not null,

  quantity numeric(10,2) not null default 1
    check (quantity > 0),

  unit_price numeric(12,2) not null
    check (unit_price >= 0),

  line_total numeric(12,2) not null
    check (line_total >= 0),

  display_order integer not null default 0
);

-- ------------------------------------------------------------
-- 6. AUTOMATIC UPDATED_AT TRIGGERS
-- ------------------------------------------------------------

create trigger tour_collections_set_updated_at
before update on public.tour_collections
for each row execute function public.set_updated_at();

create trigger custom_trip_requests_set_updated_at
before update on public.custom_trip_requests
for each row execute function public.set_updated_at();

create trigger custom_trip_quotations_set_updated_at
before update on public.custom_trip_quotations
for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 7. ENABLE ROW LEVEL SECURITY
-- ------------------------------------------------------------

alter table public.market_segments enable row level security;
alter table public.tour_market_segments enable row level security;
alter table public.tour_collections enable row level security;
alter table public.tour_collection_items enable row level security;
alter table public.pricing_categories enable row level security;
alter table public.custom_trip_requests enable row level security;
alter table public.custom_trip_destinations enable row level security;
alter table public.custom_trip_quotations enable row level security;
alter table public.quotation_items enable row level security;

-- ------------------------------------------------------------
-- 8. ACCESS PERMISSIONS
-- ------------------------------------------------------------

revoke all on
  public.market_segments,
  public.tour_market_segments,
  public.tour_collections,
  public.tour_collection_items,
  public.pricing_categories,
  public.custom_trip_requests,
  public.custom_trip_destinations,
  public.custom_trip_quotations,
  public.quotation_items
from anon, authenticated;

-- Public catalogue reads.
grant select on
  public.market_segments,
  public.pricing_categories,
  public.tour_market_segments,
  public.tour_collections,
  public.tour_collection_items
to anon, authenticated;

-- Owner catalogue management.
grant insert, update, delete on
  public.tour_market_segments,
  public.tour_collections,
  public.tour_collection_items
to authenticated;

-- Public custom trip submissions.
grant insert (
  contact_name,
  contact_email,
  contact_phone,
  preferred_start_date,
  flexible_dates,
  duration_days,
  budget_amount,
  budget_currency,
  traveller_count,
  travel_mood,
  interests,
  notes
)
on public.custom_trip_requests to anon, authenticated;

grant select, update, delete
on public.custom_trip_requests to authenticated;

grant insert (
  custom_trip_request_id,
  destination_id,
  destination_name,
  visit_order,
  notes
)
on public.custom_trip_destinations to anon, authenticated;

grant select, update, delete
on public.custom_trip_destinations to authenticated;

-- Quotations are private owner-managed records.
grant select, insert, update, delete
on public.custom_trip_quotations, public.quotation_items
to authenticated;

-- ------------------------------------------------------------
-- 9. PUBLIC CATALOGUE POLICIES
-- ------------------------------------------------------------

create policy "Public read market segments"
on public.market_segments
for select to anon, authenticated
using (true);

create policy "Public read pricing categories"
on public.pricing_categories
for select to anon, authenticated
using (true);

create policy "Public read tour market segments"
on public.tour_market_segments
for select to anon, authenticated
using (
  exists (
    select 1
    from public.tours t
    where t.id = tour_id
      and t.is_published = true
  )
  or (select public.is_bokiama_owner())
);

create policy "Public read published collections"
on public.tour_collections
for select to anon, authenticated
using (
  is_published
  or (select public.is_bokiama_owner())
);

create policy "Public read published collection items"
on public.tour_collection_items
for select to anon, authenticated
using (
  exists (
    select 1
    from public.tour_collections c
    join public.tours t on t.id = tour_id
    where c.id = collection_id
      and c.is_published = true
      and t.is_published = true
  )
  or (select public.is_bokiama_owner())
);

-- ------------------------------------------------------------
-- 10. OWNER CATALOGUE POLICIES
-- ------------------------------------------------------------

create policy "Owner manages tour market segments"
on public.tour_market_segments
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

create policy "Owner manages collections"
on public.tour_collections
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

create policy "Owner manages collection items"
on public.tour_collection_items
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

-- ------------------------------------------------------------
-- 11. CUSTOM TRIP REQUEST POLICIES
-- ------------------------------------------------------------

create policy "Visitors submit custom trip requests"
on public.custom_trip_requests
for insert to anon, authenticated
with check (
  status = 'requested'
  and customer_id is not distinct from (select auth.uid())
);

create policy "Owner manages custom trip requests"
on public.custom_trip_requests
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

create policy "Visitors add destinations to their own request"
on public.custom_trip_destinations
for insert to anon, authenticated
with check (
  exists (
    select 1
    from public.custom_trip_requests r
    where r.id = custom_trip_request_id
      and r.customer_id is not distinct from (select auth.uid())
      and r.status = 'requested'
  )
);

create policy "Owner manages custom trip destinations"
on public.custom_trip_destinations
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

-- ------------------------------------------------------------
-- 12. QUOTATION POLICIES
-- ------------------------------------------------------------

create policy "Owner manages custom trip quotations"
on public.custom_trip_quotations
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

create policy "Owner manages quotation items"
on public.quotation_items
for all to authenticated
using ((select public.is_bokiama_owner()))
with check ((select public.is_bokiama_owner()));

commit;
