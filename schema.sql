-- ============================================================
--  ExamDesk — Supabase Schema
--  Run this entire file in: Supabase → SQL Editor → New query
-- ============================================================

-- 1. PROFILES (extends Supabase auth.users)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  role        text not null check (role in ('admin','student')),
  created_at  timestamptz default now()
);
alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Admins can read all profiles"
  on public.profiles for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Allow insert on signup"
  on public.profiles for insert with check (auth.uid() = id);


-- 2. EXAMS
create table if not exists public.exams (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  duration    int not null default 60,
  passmark    int not null default 50,
  status      text not null default 'draft' check (status in ('draft','active')),
  questions   jsonb not null default '[]',
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
alter table public.exams enable row level security;

create policy "Admins can do everything on exams"
  on public.exams for all using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Students can read active exams"
  on public.exams for select using (
    status = 'active' and
    exists (select 1 from public.profiles where id = auth.uid() and role = 'student')
  );


-- 3. SUBMISSIONS
create table if not exists public.submissions (
  id            uuid primary key default gen_random_uuid(),
  exam_id       uuid not null references public.exams(id) on delete cascade,
  student_id    uuid not null references public.profiles(id) on delete cascade,
  answers       jsonb not null default '{}',
  auto_score    int,
  submitted_at  timestamptz default now(),
  unique(exam_id, student_id)
);
alter table public.submissions enable row level security;

create policy "Students can insert own submissions"
  on public.submissions for insert with check (auth.uid() = student_id);

create policy "Students can read own submissions"
  on public.submissions for select using (auth.uid() = student_id);

create policy "Admins can read all submissions"
  on public.submissions for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );


-- 4. Auto-update updated_at on exams
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_exam_updated on public.exams;
create trigger on_exam_updated
  before update on public.exams
  for each row execute procedure public.handle_updated_at();


-- ✅ Done! All tables and policies are set up.
