create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);
create table if not exists public.shopping_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  budget numeric(12,2),
  household_size integer,
  goal text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shopping_lists_budget_non_negative check (budget is null or budget >= 0),
  constraint shopping_lists_household_size_positive check (household_size is null or household_size > 0)
);

create table if not exists public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  shopping_list_id uuid not null references public.shopping_lists (id) on delete cascade,
  custom_name text,
  quantity numeric(12,3) not null default 1,
  unit text,
  estimated_price numeric(12,2),
  checked boolean not null default false,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  constraint shopping_list_items_quantity_positive check (quantity > 0),
  constraint shopping_list_items_estimated_price_non_negative check (
    estimated_price is null or estimated_price >= 0
  ),
  constraint shopping_list_items_position_non_negative check (position >= 0)
);

create index if not exists shopping_lists_user_id_idx
  on public.shopping_lists (user_id);

create index if not exists shopping_list_items_shopping_list_id_idx
  on public.shopping_list_items (shopping_list_id);

create index if not exists shopping_list_items_list_position_idx
  on public.shopping_list_items (shopping_list_id, position);
