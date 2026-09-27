create extension if not exists pgcrypto;

create table public.cases (
  id uuid primary key default gen_random_uuid(),
  task_description text not null check (char_length(task_description) between 1 and 500),
  failure_reason text not null check (char_length(failure_reason) between 1 and 1000),
  status text not null default 'open' check (status in ('open', 'closed')),
  closes_at timestamptz not null,
  winning_consequence_id uuid,
  created_at timestamptz not null default now()
);

create table public.consequences (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  type text not null check (type in ('grounded', 'orders', 'embarrass', 'waste_money')),
  title text not null check (char_length(title) between 1 and 200),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (case_id, id)
);

alter table public.cases
  add constraint cases_winner_fk
  foreign key (id, winning_consequence_id)
  references public.consequences(case_id, id);

create table public.votes (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  voter_id text not null check (char_length(voter_id) between 1 and 200),
  consequence_id uuid not null,
  voter_kind text not null default 'human' check (voter_kind in ('human', 'ai')),
  persona text,
  comment text check (comment is null or char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  unique (case_id, voter_id),
  foreign key (case_id, consequence_id)
    references public.consequences(case_id, id)
    on delete cascade
);

create index votes_case_consequence_idx on public.votes(case_id, consequence_id);
create index consequences_case_id_idx on public.consequences(case_id);

alter table public.cases enable row level security;
alter table public.consequences enable row level security;
alter table public.votes enable row level security;

-- Hackathon-only access model: anyone with the public key can create and view
-- short-lived demo cases. There are no user accounts or private profiles.
create policy "public can read cases"
  on public.cases for select
  to anon, authenticated
  using (true);

create policy "public can create cases"
  on public.cases for insert
  to anon, authenticated
  with check (status = 'open' and winning_consequence_id is null);

create policy "public can close cases"
  on public.cases for update
  to anon, authenticated
  using (status = 'open')
  with check (status = 'closed' and winning_consequence_id is not null);

create policy "public can read consequences"
  on public.consequences for select
  to anon, authenticated
  using (true);

create policy "public can create consequences"
  on public.consequences for insert
  to anon, authenticated
  with check (
    exists (
      select 1 from public.cases
      where cases.id = consequences.case_id and cases.status = 'open'
    )
  );

create policy "public can read votes"
  on public.votes for select
  to anon, authenticated
  using (true);

create policy "public can cast one vote per session"
  on public.votes for insert
  to anon, authenticated
  with check (
    exists (
      select 1 from public.cases
      where cases.id = votes.case_id and cases.status = 'open'
    )
    and exists (
      select 1 from public.consequences
      where consequences.id = votes.consequence_id
        and consequences.case_id = votes.case_id
    )
  );

revoke all on public.cases, public.consequences, public.votes from anon, authenticated;
grant select, insert on public.cases, public.consequences, public.votes to anon, authenticated;
grant update (status, winning_consequence_id) on public.cases to anon, authenticated;

alter publication supabase_realtime add table public.cases;
alter publication supabase_realtime add table public.votes;
