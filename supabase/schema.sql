begin;
create schema if not exists pull_private;
revoke all on schema pull_private from public, anon, authenticated;
grant usage on schema pull_private to authenticated;

create table pull_private.cards (id text primary key, booster_slot boolean not null);
create table pull_private.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 email text not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 role text not null default 'user' check(role in ('user','admin')),
 counts jsonb not null default '{}',
 version integer not null default 0,
 snapshot jsonb,
 snapshot_version integer,
 updated_at timestamptz not null default now()
);
create table pull_private.settings (
 id boolean primary key default true check(id),
 admin_email text
);
insert into pull_private.settings(id) values(true);
create table pull_private.history (
 id bigint generated always as identity primary key,
 actor uuid, target uuid, action text not null, previous_state jsonb,
 created_at timestamptz not null default now()
);
create index history_target_idx on pull_private.history(target);
alter table pull_private.cards enable row level security;
alter table pull_private.profiles enable row level security;
alter table pull_private.history enable row level security;
alter table pull_private.settings enable row level security;
revoke all on all tables in schema pull_private from public, anon, authenticated;

-- The only public data: rounded rates. No counts, owners or denominator.
create table public.pull_rates (
 id smallint primary key check(id=1),
 rates jsonb not null default '{}',
 updated_at timestamptz not null default now()
);
alter table public.pull_rates enable row level security;
create policy public_read_rates on public.pull_rates for select to anon, authenticated using(true);
revoke all on public.pull_rates from anon, authenticated;
grant select on public.pull_rates to anon, authenticated;
insert into public.pull_rates(id) values(1);

create function pull_private.register_user() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into pull_private.profiles(id,email) values(new.id,coalesce(new.email,''));
 return new;
end $$;
revoke all on function pull_private.register_user() from public, anon, authenticated;
create trigger pull_signup after insert on auth.users for each row execute function pull_private.register_user();

-- The owner email is configured privately after deployment, never in public code.
create function pull_private.confirm_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.email_confirmed_at is not null and exists(
  select 1 from pull_private.settings where id=true and lower(admin_email)=lower(new.email)
 ) then
  update pull_private.profiles set role='admin',status='approved' where id=new.id;
 end if;
 return new;
end $$;
revoke all on function pull_private.confirm_owner() from public,anon,authenticated;
create trigger pull_zz_owner_confirm after insert or update of email_confirmed_at on auth.users
for each row execute function pull_private.confirm_owner();

create function pull_private.validate_counts(payload jsonb) returns void
language plpgsql security invoker set search_path='' as $$
declare item record;
begin
 if payload is null or jsonb_typeof(payload)<>'object' then raise exception 'INVALID_BACKUP: Kartenwerte müssen ein Objekt sein'; end if;
 if pg_column_size(payload)>100000 then raise exception 'INVALID_BACKUP: Datei zu groß'; end if;
 for item in select * from jsonb_each(payload) loop
  if not exists(select 1 from pull_private.cards where id=item.key)
   or jsonb_typeof(item.value)<>'number' or item.value::text !~ '^[0-9]+$'
  then raise exception 'INVALID_COUNTS: Unbekannte Karte oder ungültige Stückzahl'; end if;
  if (item.value::text)::numeric>1000000 then raise exception 'INVALID_COUNTS: Maximal 1.000.000 je Karte'; end if;
 end loop;
end $$;
revoke all on function pull_private.validate_counts(jsonb) from public, anon, authenticated;

create function pull_private.refresh_rates() returns void
language plpgsql security invoker set search_path='' as $$
declare boosters numeric; result jsonb;
begin
 with effective as (
  select case when role='admin' then counts else snapshot end counts
  from pull_private.profiles where status='approved' and (role='admin' or snapshot is not null)
 ), totals as (
  select c.id,c.booster_slot,coalesce(sum(coalesce((e.counts->>c.id)::numeric,0)),0) n
  from pull_private.cards c left join effective e on true group by c.id,c.booster_slot
 ) select coalesce(sum(n) filter(where booster_slot),0) into boosters from totals;
 with effective as (
  select case when role='admin' then counts else snapshot end counts
  from pull_private.profiles where status='approved' and (role='admin' or snapshot is not null)
 ), totals as (
  select c.id,coalesce(sum(coalesce((e.counts->>c.id)::numeric,0)),0) n
  from pull_private.cards c left join effective e on true group by c.id
 ) select jsonb_object_agg(id,case when n=0 or boosters=0 then null else round(boosters/n,2) end) into result from totals;
 update public.pull_rates set rates=result,updated_at=now() where id=1;
end $$;
revoke all on function pull_private.refresh_rates() from public, anon, authenticated;

-- Privileged entry point is deliberately private. Every call verifies the current
-- database profile; client-controlled user_metadata is never used for permission.
create function pull_private.application(operation text, payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; rec record; result jsonb; item jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 -- Serializes publication and prevents lost updates across concurrent contributors.
 perform pg_advisory_xact_lock(3046103);
 select * into me from pull_private.profiles where id=auth.uid() for update;
 if not found then raise exception 'PROFILE_MISSING'; end if;
 if operation='me' then
  return jsonb_build_object('id',me.id,'email',me.email,'role',me.role,'status',me.status,
   'counts',case when me.status='approved' then me.counts else '{}'::jsonb end,
   'version',me.version,'snapshot_version',me.snapshot_version);
 end if;
 if me.status<>'approved' then raise exception 'NOT_APPROVED'; end if;
 if operation='save' then
  perform pull_private.validate_counts(payload->'counts');
  if (payload->>'version')::integer is distinct from me.version then raise exception 'VERSION_CONFLICT'; end if;
  insert into pull_private.history(actor,target,action,previous_state) values(me.id,me.id,'save',to_jsonb(me));
  update pull_private.profiles set counts=payload->'counts',version=version+1,updated_at=now() where id=me.id;
  if me.role='admin' then perform pull_private.refresh_rates(); end if;
  return jsonb_build_object('version',me.version+1);
 end if;
 if operation='export-own' then
  return jsonb_build_object('format','pokemon-pullrates','schema_version',1,'set','30thC-zh-Hans',
   'scope','own','created_at',now(),'counts',me.counts);
 end if;
 if me.role<>'admin' then raise exception 'ADMIN_REQUIRED'; end if;
 if operation='users' then
  select coalesce(jsonb_agg(to_jsonb(p) order by p.email),'[]'::jsonb) into result from pull_private.profiles p;
  return result;
 end if;
 if operation in ('approve','reject','include','exclude') then
  select * into target from pull_private.profiles where id=(payload->>'user_id')::uuid for update;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  if target.role='admin' then raise exception 'ADMIN_PROTECTED'; end if;
  if (payload->>'version')::integer is distinct from target.version then raise exception 'VERSION_CONFLICT'; end if;
  if operation='include' and target.status<>'approved' then raise exception 'NOT_APPROVED'; end if;
  insert into pull_private.history(actor,target,action,previous_state) values(me.id,target.id,operation,to_jsonb(target));
  if operation='approve' then update pull_private.profiles set status='approved' where id=target.id; end if;
  if operation='reject' then update pull_private.profiles set status='rejected',snapshot=null,snapshot_version=null where id=target.id; end if;
  if operation='include' then update pull_private.profiles set snapshot=counts,snapshot_version=version where id=target.id; end if;
  if operation='exclude' then update pull_private.profiles set snapshot=null,snapshot_version=null where id=target.id; end if;
  -- Permission and snapshot changes also increment the revision for stale dialogs.
  update pull_private.profiles set version=version+1,updated_at=now() where id=target.id;
  if operation='include' then update pull_private.profiles set snapshot_version=version where id=target.id; end if;
  perform pull_private.refresh_rates();return jsonb_build_object('ok',true);
 end if;
 if operation='export-all' then
  select jsonb_agg(jsonb_build_object('user_id',id,'email',email,'counts',counts,'snapshot',snapshot))
   into result from pull_private.profiles;
  return jsonb_build_object('format','pokemon-pullrates','schema_version',1,'set','30thC-zh-Hans',
   'scope','all','created_at',now(),'datasets',result);
 end if;
 if operation='restore-all' then
  if (payload->>'format') is distinct from 'pokemon-pullrates' or (payload->>'set') is distinct from '30thC-zh-Hans'
   or (payload->>'schema_version') is distinct from '1' or (payload->>'scope') is distinct from 'all'
   or jsonb_typeof(payload->'datasets') is distinct from 'array' then raise exception 'INVALID_BACKUP'; end if;
  if jsonb_array_length(payload->'datasets')>10000 then raise exception 'INVALID_BACKUP'; end if;
  if exists(select 1 from jsonb_array_elements(payload->'datasets') a group by a->>'user_id' having count(*)>1) then raise exception 'DUPLICATE_USER'; end if;
  for item in select * from jsonb_array_elements(payload->'datasets') loop
   perform pull_private.validate_counts(item->'counts');
   if not (item ? 'snapshot') then raise exception 'INVALID_BACKUP'; end if;
   if item->'snapshot'<>'null'::jsonb then perform pull_private.validate_counts(item->'snapshot'); end if;
   select * into target from pull_private.profiles where id=(item->>'user_id')::uuid for update;
   if not found then raise exception 'USER_NOT_FOUND'; end if;
   if (payload->'expected_versions'->>target.id::text)::integer is distinct from target.version then raise exception 'VERSION_CONFLICT'; end if;
   insert into pull_private.history(actor,target,action,previous_state) values(me.id,target.id,'restore',to_jsonb(target));
   update pull_private.profiles set counts=item->'counts',snapshot=nullif(item->'snapshot','null'::jsonb),
    version=version+1,snapshot_version=case when item->'snapshot'<>'null'::jsonb then version+1 else null end,updated_at=now() where id=target.id;
  end loop;
  perform pull_private.refresh_rates();return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.application(text,jsonb) from public, anon, authenticated;
grant execute on function pull_private.application(text,jsonb) to authenticated;
create function public.pull_app(operation text,payload jsonb default '{}') returns jsonb
language sql security invoker set search_path='' as $$ select pull_private.application(operation,payload); $$;
revoke all on function public.pull_app(text,jsonb) from public, anon, authenticated;
grant execute on function public.pull_app(text,jsonb) to authenticated;

-- A public subscription can only publish the derived table.
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.pull_rates;
 end if;
end $$;

insert into pull_private.cards(id,booster_slot) values
('001',false),
('002',false),
('003',false),
('004',false),
('005',false),
('006',false),
('007',false),
('008',false),
('009',false),
('010',false),
('011',false),
('012',false),
('013',false),
('014',false),
('015',false),
('016',false),
('017',true),
('018',true),
('019',true),
('020',true),
('021',true),
('022',true),
('023',true),
('024',true),
('025',true),
('026',true),
('027',true),
('028',true),
('029',true),
('030',true),
('031',true),
('032',true),
('033',true),
('034',true),
('035',true),
('036',true),
('037',true),
('038',true),
('039',true),
('040',true),
('041',true),
('042',true),
('043',true),
('044',true),
('045',true),
('046',true),
('047',false),
('048',false),
('049',false),
('050',false),
('051',false),
('052',false),
('053',false),
('054',false),
('055',false),
('056',false),
('057',false),
('058',false),
('059',false),
('060',false),
('061',false),
('062',false),
('063',false),
('064',false),
('065',false),
('066',false),
('067',false),
('068',false),
('069',false),
('070',false),
('071',false),
('072',false),
('073',false),
('074',false),
('075',false),
('076',false),
('077',false),
('078',false),
('079',false),
('080',false),
('081',false),
('082',false),
('083',false),
('084',false),
('085',false),
('086',false),
('087',false),
('088',false),
('089',false),
('090',false),
('091',false),
('092',false),
('093',false),
('094',false),
('095',false),
('096',false),
('097',false),
('098',false),
('099',false),
('100',false),
('101',false),
('102',false),
('103',false),
('104',false),
('105',false),
('106',false),
('107',false),
('108',false),
('109',false),
('110',false),
('111',false),
('112',false),
('113',false),
('114',false),
('115',false),
('116',false),
('117',false),
('118',false),
('120',false),
('121',false),
('122',false),
('123',false),
('124',false),
('125',false),
('126',false),
('127',false),
('130',false),
('132',false),
('133',false),
('134',false),
('135',false),
('136',false),
('137',false),
('138',false),
('139',false),
('140',false),
('141',false),
('142',false),
('143',false),
('144',false),
('145',false),
('146',false),
('147',false),
('148',false),
('149',false),
('150',false),
('151',false),
('152',false),
('153',false),
('154',false),
('155',false),
('156',false),
('157',false),
('158',false),
('159',false),
('160',false),
('161',false),
('162',false),
('163',false),
('164',false),
('165',false),
('energy-darkness',false),
('energy-fighting',false),
('energy-fire',false),
('energy-grass',false),
('energy-lightning',false),
('energy-metal',false),
('energy-psychic',false),
('energy-water',false);
select pull_private.refresh_rates();
commit;
