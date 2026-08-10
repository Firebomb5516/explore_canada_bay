-- Practical newcomer details saved from the guided Journey. Every row is
-- private to its authenticated owner; no public profile view is provided.
create table if not exists public.user_settlement_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  bin_collection_weekday smallint check (bin_collection_weekday between 1 and 7),
  library_card_label text check (char_length(library_card_label) <= 80),
  transport_stop text check (char_length(transport_stop) <= 120),
  transport_mode text check (char_length(transport_mode) <= 40),
  council_report_reference text check (char_length(council_report_reference) <= 100),
  council_report_type text check (char_length(council_report_type) <= 100),
  pet_name text check (char_length(pet_name) <= 80),
  updated_at timestamptz not null default now()
);

alter table public.user_settlement_profiles enable row level security;

drop policy if exists "People can read their settlement profile"
  on public.user_settlement_profiles;
create policy "People can read their settlement profile"
  on public.user_settlement_profiles for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "People can create their settlement profile"
  on public.user_settlement_profiles;
create policy "People can create their settlement profile"
  on public.user_settlement_profiles for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "People can update their settlement profile"
  on public.user_settlement_profiles;
create policy "People can update their settlement profile"
  on public.user_settlement_profiles for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke delete on public.user_settlement_profiles from anon, authenticated;
