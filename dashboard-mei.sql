-- EXTENSÃO
create extension if not exists "uuid-ossp";

-- PROFILES
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  email text,
  created_at timestamp with time zone default now()
);

-- CATEGORIES
create table if not exists categories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  name text not null,
  type text check (type in ('receita', 'despesa')) not null,
  created_at timestamp with time zone default now()
);

-- TRANSACTIONS
create table if not exists transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  date date not null,
  type text check (type in ('receita', 'despesa')) not null,
  category_id uuid references categories(id),
  description text,
  amount numeric(12,2) not null check (amount >= 0),
  payment_method text,
  is_recurring boolean default false,
  created_at timestamp with time zone default now()
);

-- TAXES
create table if not exists taxes (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  name text not null,
  amount numeric(12,2) not null,
  due_date date not null,
  status text check (status in ('pendente', 'pago')) default 'pendente',
  created_at timestamp with time zone default now()
);

-- MEI SETTINGS
create table if not exists mei_settings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid unique references profiles(id) on delete cascade,
  annual_limit numeric(12,2) default 81000,
  alert_threshold numeric(5,2) default 80,
  created_at timestamp with time zone default now()
);


-- VIEWS
create or replace view financial_summary as
select
  user_id,
  sum(case when type = 'receita' then amount else 0 end) as total_receita,
  sum(case when type = 'despesa' then amount else 0 end) as total_despesa,
  sum(case when type = 'receita' then amount else -amount end) as lucro_liquido
from transactions
group by user_id;

create or replace view monthly_evolution as
select
  user_id,
  date_trunc('month', date) as month,
  sum(case when type = 'receita' then amount else 0 end) as receita,
  sum(case when type = 'despesa' then amount else 0 end) as despesa
from transactions
group by user_id, month;

-- ATIVAÇÃO RLS
alter table profiles enable row level security;
alter table categories enable row level security;
alter table transactions enable row level security;
alter table taxes enable row level security;
alter table mei_settings enable row level security;

-- PROFILES
drop policy if exists "profile_select" on profiles;
create policy "profile_select"
on profiles for select
using (auth.uid() = id);

drop policy if exists "profile_insert" on profiles;
create policy "profile_insert"
on profiles for insert
with check (auth.uid() = id);

-- CATEGORIES
drop policy if exists "categories_all" on categories;
create policy "categories_all"
on categories for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- TRANSACTIONS
drop policy if exists "transactions_all" on transactions;
create policy "transactions_all"
on transactions for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- TAXES
drop policy if exists "taxes_all" on taxes;
create policy "taxes_all"
on taxes for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- SETTINGS
drop policy if exists "settings_all" on mei_settings;
create policy "settings_all"
on mei_settings for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- TRIGGER PARA CRIAR NOVO USUÁRIO
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;

  return new;
end;
$$ language plpgsql security definer;

-- RECRIAR TRIGGER
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure handle_new_user();

-- Consulta final
select * from profiles;



