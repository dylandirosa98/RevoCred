-- Run this in Supabase SQL Editor once.
-- It creates app tables, indexes, and RLS policies for per-user data access.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  credit_card_strategy text not null,
  goal text not null,
  top_spend_categories text not null,
  next_application_target text not null,
  points_value integer not null default 0,
  projected_yearly_value integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  card_id text not null,
  status text not null default 'Active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, card_id)
);

create table if not exists public.revo_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.revo_usage_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('success', 'rate_limited', 'guardrail_blocked', 'provider_error', 'bad_request')),
  prompt_chars integer not null default 0,
  response_chars integer not null default 0,
  latency_ms integer,
  model text,
  error_code text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  redemption_type text not null default 'hybrid' check (redemption_type in ('cash_back', 'points', 'hybrid')),
  travel_scope text not null default 'both' check (travel_scope in ('domestic', 'international', 'both', 'none')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.card_catalog (
  id text primary key,
  issuer text not null,
  brand text not null,
  name text not null,
  network text,
  annual_fee text not null,
  point_multipliers text[] not null default '{}',
  transferable_points boolean not null default false,
  transfer_partners text[] not null default '{}',
  benefits text[] not null default '{}',
  summary text,
  best_use text not null,
  multiplier text not null,
  redemption_type text check (redemption_type in ('cash_back', 'points', 'hybrid')),
  travel_scope text check (travel_scope in ('domestic', 'international', 'both', 'none')),
  no_foreign_tx_fee boolean,
  annual_fee_tier text check (annual_fee_tier in ('0', 'low', 'mid', 'high')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_wallet_cards_user_created_at on public.wallet_cards (user_id, created_at);
create index if not exists idx_revo_messages_user_created_at on public.revo_messages (user_id, created_at);
create index if not exists idx_revo_usage_logs_user_created_at on public.revo_usage_logs (user_id, created_at);
create index if not exists idx_card_catalog_issuer on public.card_catalog (issuer);
create index if not exists idx_card_catalog_name on public.card_catalog (name);
create index if not exists idx_card_catalog_redemption_travel on public.card_catalog (redemption_type, travel_scope);

alter table public.profiles enable row level security;
alter table public.wallet_cards enable row level security;
alter table public.revo_messages enable row level security;
alter table public.revo_usage_logs enable row level security;
alter table public.user_preferences enable row level security;
alter table public.card_catalog enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_delete_own" on public.profiles;

create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "profiles_delete_own"
  on public.profiles
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "wallet_cards_select_own" on public.wallet_cards;
drop policy if exists "wallet_cards_insert_own" on public.wallet_cards;
drop policy if exists "wallet_cards_update_own" on public.wallet_cards;
drop policy if exists "wallet_cards_delete_own" on public.wallet_cards;

create policy "wallet_cards_select_own"
  on public.wallet_cards
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "wallet_cards_insert_own"
  on public.wallet_cards
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "wallet_cards_update_own"
  on public.wallet_cards
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wallet_cards_delete_own"
  on public.wallet_cards
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "revo_messages_select_own" on public.revo_messages;
drop policy if exists "revo_messages_insert_own" on public.revo_messages;
drop policy if exists "revo_messages_delete_own" on public.revo_messages;

create policy "revo_messages_select_own"
  on public.revo_messages
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "revo_messages_insert_own"
  on public.revo_messages
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "revo_messages_delete_own"
  on public.revo_messages
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "revo_usage_logs_select_own" on public.revo_usage_logs;
drop policy if exists "revo_usage_logs_insert_own" on public.revo_usage_logs;
drop policy if exists "revo_usage_logs_delete_own" on public.revo_usage_logs;
drop policy if exists "user_preferences_select_own" on public.user_preferences;
drop policy if exists "user_preferences_insert_own" on public.user_preferences;
drop policy if exists "user_preferences_update_own" on public.user_preferences;
drop policy if exists "user_preferences_delete_own" on public.user_preferences;
drop policy if exists "card_catalog_select_authenticated" on public.card_catalog;

create policy "revo_usage_logs_select_own"
  on public.revo_usage_logs
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "revo_usage_logs_insert_own"
  on public.revo_usage_logs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "revo_usage_logs_update_own"
  on public.revo_usage_logs
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "revo_usage_logs_delete_own"
  on public.revo_usage_logs
  for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "user_preferences_select_own"
  on public.user_preferences
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "user_preferences_insert_own"
  on public.user_preferences
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "user_preferences_update_own"
  on public.user_preferences
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_preferences_delete_own"
  on public.user_preferences
  for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "card_catalog_select_authenticated"
  on public.card_catalog
  for select
  to authenticated
  using (true);
