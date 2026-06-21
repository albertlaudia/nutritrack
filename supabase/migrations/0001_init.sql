-- NutriTrack Supabase schema (v1, offline-first sync)
-- Apply: supabase db push  (after `supabase init`)

-- ─── Food logs ────────────────────────────────────────────────
create table public.food_logs (
  id uuid primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  brand text,
  grams numeric not null,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  fiber numeric default 0,
  sugar numeric default 0,
  sodium numeric default 0,
  confidence numeric default 1,
  slot text not null check (slot in ('breakfast','lunch','dinner','snack')),
  source text not null,
  logged_at timestamptz not null,
  image_path text,
  notes text,
  external_id text,
  is_favorite boolean default false,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

create index food_logs_user_logged on public.food_logs(user_id, logged_at desc);
create index food_logs_user_slot on public.food_logs(user_id, slot, logged_at desc);
alter table public.food_logs enable row level security;
create policy "Users can manage own logs" on public.food_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─── Workout sessions ─────────────────────────────────────────
create table public.workout_sessions (
  id uuid primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  exercises jsonb not null default '[]',
  perceived_exertion int default 0,
  calories_burned numeric default 0,
  notes text,
  updated_at timestamptz default now()
);

create index workout_user_started on public.workout_sessions(user_id, started_at desc);
alter table public.workout_sessions enable row level security;
create policy "Users manage own sessions" on public.workout_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─── Weight entries ───────────────────────────────────────────
create table public.weight_entries (
  id uuid primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  recorded_at timestamptz not null,
  weight_kg numeric not null,
  body_fat_pct numeric default 0,
  muscle_kg numeric default 0,
  notes text
);

create index weight_user_recorded on public.weight_entries(user_id, recorded_at desc);
alter table public.weight_entries enable row level security;
create policy "Users manage own weight" on public.weight_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─── User profiles (mirror) ───────────────────────────────────
create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sex text not null,
  age_years int not null,
  height_cm numeric not null,
  weight_kg numeric not null,
  activity text not null,
  goal text not null,
  use_metric boolean default true,
  updated_at timestamptz default now()
);

alter table public.user_profiles enable row level security;
create policy "Users manage own profile" on public.user_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─── Exercise DB (shared, read-mostly) ────────────────────────
create table public.exercises (
  id text primary key,
  name text not null,
  primary_muscle text not null,
  secondary_muscles text[] default '{}',
  equipment text not null,
  difficulty text not null,
  instructions text,
  video_url text,
  image_url text,
  tags text[] default '{}',
  calories_per_hour int default 0
);

create index exercises_name_trgm on public.exercises using gin (name gin_trgm_ops);
create index exercises_muscle on public.exercises(primary_muscle);

-- Enable pg_trgm extension for fast ILIKE search
create extension if not exists pg_trgm;