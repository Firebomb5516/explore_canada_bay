-- Community challenges are cooperative by default. Individual ranking is
-- opt-in and exposes only a generated alias, never account names or emails.
create extension if not exists pgcrypto;

create table if not exists public.community_challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text not null,
  reward text not null,
  target_points integer not null check (target_points > 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.community_challenge_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_alias text not null,
  leaderboard_opt_in boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.community_contributions (
  id bigint generated always as identity primary key,
  challenge_id uuid not null references public.community_challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id text not null check (char_length(activity_id) between 3 and 120),
  activity_kind text not null check (activity_kind in ('discovery', 'route', 'journey', 'community')),
  points integer not null check (points between 1 and 50),
  created_at timestamptz not null default now(),
  unique (challenge_id, user_id, activity_id)
);

create index if not exists community_contributions_challenge_user_idx
  on public.community_contributions (challenge_id, user_id);

alter table public.community_challenges enable row level security;
alter table public.community_challenge_profiles enable row level security;
alter table public.community_contributions enable row level security;

drop policy if exists "Active challenges are publicly readable" on public.community_challenges;
create policy "Active challenges are publicly readable"
  on public.community_challenges for select
  using (active and now() between starts_at and ends_at);

drop policy if exists "People can read their challenge profile" on public.community_challenge_profiles;
create policy "People can read their challenge profile"
  on public.community_challenge_profiles for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "People can read their contributions" on public.community_contributions;
create policy "People can read their contributions"
  on public.community_contributions for select to authenticated
  using (auth.uid() = user_id);

-- Writes are available only through the validated functions below.
revoke insert, update, delete on public.community_challenges from anon, authenticated;
revoke insert, update, delete on public.community_challenge_profiles from anon, authenticated;
revoke insert, update, delete on public.community_contributions from anon, authenticated;

create or replace function public.record_community_activity(
  p_activity_id text,
  p_activity_kind text
) returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_challenge_id uuid;
  v_points integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_activity_id is null or char_length(trim(p_activity_id)) not between 3 and 120 then
    raise exception 'Invalid activity ID';
  end if;
  v_points := case p_activity_kind
    when 'discovery' then 10
    when 'route' then 25
    when 'journey' then 5
    when 'community' then 15
    else null
  end;
  if v_points is null then
    raise exception 'Invalid activity kind';
  end if;
  select id into v_challenge_id
  from public.community_challenges
  where active and now() between starts_at and ends_at
  order by starts_at desc limit 1;
  if v_challenge_id is null then return false; end if;

  insert into public.community_contributions(
    challenge_id, user_id, activity_id, activity_kind, points
  ) values (
    v_challenge_id, auth.uid(), trim(p_activity_id), p_activity_kind, v_points
  ) on conflict (challenge_id, user_id, activity_id) do nothing;
  return found;
end;
$$;

create or replace function public.set_community_leaderboard_opt_in(p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.community_challenge_profiles(user_id, public_alias, leaderboard_opt_in)
  values (
    auth.uid(),
    'Neighbour ' || upper(substr(replace(auth.uid()::text, '-', ''), 1, 4)),
    coalesce(p_enabled, false)
  )
  on conflict (user_id) do update
    set leaderboard_opt_in = excluded.leaderboard_opt_in,
        updated_at = now();
end;
$$;

create or replace function public.get_active_community_challenge()
returns jsonb
language sql
stable
security definer
set search_path = public, auth
as $$
with active_challenge as (
  select * from public.community_challenges
  where active and now() between starts_at and ends_at
  order by starts_at desc limit 1
), totals as (
  select coalesce(sum(c.points), 0)::integer as points,
         count(distinct c.user_id)::integer as contributors
  from public.community_contributions c join active_challenge a on a.id = c.challenge_id
), personal as (
  select coalesce(sum(c.points), 0)::integer as points
  from public.community_contributions c join active_challenge a on a.id = c.challenge_id
  where c.user_id = auth.uid()
), ranked as (
  select c.user_id, sum(c.points)::integer as points,
         rank() over (order by sum(c.points) desc)::integer as position
  from public.community_contributions c
  join active_challenge a on a.id = c.challenge_id
  group by c.user_id
), leaders as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'position', r.position, 'alias', p.public_alias, 'points', r.points
  ) order by r.position), '[]'::jsonb) as items
  from (
    select r.* from ranked r
    join public.community_challenge_profiles p on p.user_id = r.user_id
    where p.leaderboard_opt_in
    order by r.position limit 10
  ) r
  join public.community_challenge_profiles p on p.user_id = r.user_id
)
select jsonb_build_object(
  'id', a.slug,
  'title', a.title,
  'description', a.description,
  'reward', a.reward,
  'target_points', a.target_points,
  'community_points', t.points,
  'contributor_count', t.contributors,
  'personal_points', coalesce(pe.points, 0),
  'personal_rank', (select position from ranked where user_id = auth.uid()),
  'leaderboard_opt_in', coalesce((select leaderboard_opt_in from public.community_challenge_profiles where user_id = auth.uid()), false),
  'leaders', l.items,
  'ends_at', a.ends_at
)
from active_challenge a cross join totals t cross join personal pe cross join leaders l;
$$;

revoke all on function public.record_community_activity(text, text) from public;
grant execute on function public.record_community_activity(text, text) to authenticated;
revoke all on function public.set_community_leaderboard_opt_in(boolean) from public;
grant execute on function public.set_community_leaderboard_opt_in(boolean) to authenticated;
revoke all on function public.get_active_community_challenge() from public;
grant execute on function public.get_active_community_challenge() to anon, authenticated;

insert into public.community_challenges(
  slug, title, description, reward, target_points, starts_at, ends_at, active
) values (
  'together-canada-bay-2026',
  'Together Canada Bay',
  'Explore, volunteer, walk and learn together. Every verified Passport activity moves the whole community forward.',
  'Unlock the Together Canada Bay digital celebration and community impact story.',
  2000,
  '2026-01-01 00:00:00+11',
  '2027-01-01 00:00:00+11',
  true
) on conflict (slug) do update set
  title = excluded.title,
  description = excluded.description,
  reward = excluded.reward,
  target_points = excluded.target_points,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  active = excluded.active;
