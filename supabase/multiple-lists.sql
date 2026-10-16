-- Additive migration: original profile counts and reviewed snapshots are retained.
alter table pull_private.profiles add column username text, add column username_blocked boolean not null default false;
create unique index profiles_username_unique on pull_private.profiles(lower(username)) where username is not null;
create table pull_private.lists (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references pull_private.profiles(id) on delete cascade,
 name text not null check(char_length(btrim(name)) between 1 and 80),
 purpose text not null default 'pulls' check(purpose in ('pulls','trade')),
 visibility text not null default 'private' check(visibility in ('private','public')),
 display text not null default 'all' check(display in ('all','hide_boosters','rates_only')),
 counts jsonb not null default '{}', version integer not null default 0,
 snapshot jsonb, snapshot_version integer, owner_live boolean not null default false,
 is_legacy boolean not null default false, updated_at timestamptz not null default now()
);
create index lists_owner on pull_private.lists(owner_id);
create unique index lists_one_legacy on pull_private.lists(owner_id) where is_legacy;
alter table pull_private.lists enable row level security;
revoke all on pull_private.lists from public,anon,authenticated;
insert into pull_private.lists(owner_id,name,counts,version,snapshot,snapshot_version,owner_live,is_legacy)
 select id,'Meine Sammlung',counts,version,snapshot,snapshot_version,role='admin',true from pull_private.profiles;

create function pull_private.validate_username(value text) returns text language plpgsql set search_path='' as $$
declare cleaned text:=nullif(btrim(value),''); normalized text;
begin
 if cleaned is null then return null; end if;
 if char_length(cleaned) not between 3 and 24 or cleaned !~ '^[[:alpha:]0-9_-]+$' then raise exception 'USERNAME_FORMAT'; end if;
 normalized:=lower(cleaned);
 normalized:=replace(replace(replace(replace(normalized,'ä','a'),'ö','o'),'ü','u'),'ß','ss');
 normalized:=translate(normalized,'013457','oieast');
 normalized:=regexp_replace(normalized,'[^[:alpha:]]','','g');
 -- Conservative maintained denylist, also matching separators and common leetspeak.
 if normalized ~ '(arschloch|hurensohn|hurentochter|wichser|fotze|fickdich|scheisse|shithead|asshole|motherfucker|bastard|schlampe|fuck|bitch|cunt|nigger|neger|heilhitler|siegheil|hitler|nazi|hakenkreuz|whitepower|ku[ck]luxklan|judentod|judenvergas|holocaustleug|ssdivision|waffenss|nsdap|untermensch)' or lower(cleaned) ~ '(1488|(^|[_-])88([_-]|$))' or normalized in ('admin','administrator','moderator','support') then raise exception 'USERNAME_BLOCKED'; end if;
 return cleaned;
end $$;
revoke all on function pull_private.validate_username(text) from public,anon,authenticated;

create function pull_private.sync_legacy_list() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into pull_private.lists(owner_id,name,counts,version,snapshot,snapshot_version,owner_live,is_legacy)
   values(new.id,'Meine Sammlung',new.counts,new.version,new.snapshot,new.snapshot_version,new.role='admin',true);
 else
  if new.counts is distinct from old.counts or new.snapshot is distinct from old.snapshot or new.snapshot_version is distinct from old.snapshot_version then
   update pull_private.lists set counts=new.counts,
    snapshot=case when new.snapshot is distinct from old.snapshot or new.snapshot_version is distinct from old.snapshot_version then new.snapshot else snapshot end,
    snapshot_version=case when new.snapshot is distinct from old.snapshot or new.snapshot_version is distinct from old.snapshot_version then case when new.snapshot is null then null else version+1 end else snapshot_version end,
    version=version+1,updated_at=now() where owner_id=new.id and is_legacy;
  end if;
  if new.status='rejected' and old.status<>'rejected' then
   update pull_private.lists set snapshot=null,snapshot_version=null,owner_live=false,visibility='private',version=version+1,updated_at=now() where owner_id=new.id;
  end if;
  if new.username is null or new.username_blocked then
   update pull_private.lists set visibility='private',version=version+1,updated_at=now() where owner_id=new.id and visibility='public';
  end if;
 end if;
 return new;
end $$;
revoke all on function pull_private.sync_legacy_list() from public,anon,authenticated;
create trigger profiles_sync_lists after insert or update on pull_private.profiles for each row execute function pull_private.sync_legacy_list();
create or replace function pull_private.register_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into pull_private.profiles(id,email,username) values(new.id,coalesce(new.email,''),pull_private.validate_username(new.raw_user_meta_data->>'username'));
 return new;
end $$;

create or replace function pull_private.community_counts() returns jsonb language sql set search_path='' as $$
 with effective as (
 select case when l.owner_live then l.counts else l.snapshot end counts from pull_private.lists l join pull_private.profiles p on p.id=l.owner_id
 where p.status='approved' and l.purpose='pulls' and (l.owner_live or l.snapshot is not null)
 ), totals as (
 select c.id,c.booster_slot,coalesce(sum(coalesce((e.counts->>c.id)::numeric,0)),0) n
 from pull_private.cards c left join effective e on true group by c.id,c.booster_slot
 ) select jsonb_build_object('counts',jsonb_object_agg(id,n),'boosters',coalesce(sum(n) filter(where booster_slot),0)) from totals;
$$;
create or replace function pull_private.refresh_rates() returns void language sql set search_path='' as $$
 with totals as (select pull_private.community_counts() d)
 update public.pull_rates set rates=(select jsonb_object_agg(c.id,case when (d->>'boosters')::numeric=0 or coalesce((d->'counts'->>c.id)::numeric,0)=0 then null else round((d->>'boosters')::numeric/(d->'counts'->>c.id)::numeric,2) end) from pull_private.cards c cross join totals),updated_at=now() where id=1;
$$;

create function pull_private.list_application(operation text,payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; item pull_private.lists; result jsonb; clean text; total numeric; r jsonb; full_access boolean; entry jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform pg_advisory_xact_lock(3046103);
 select * into me from pull_private.profiles where id=auth.uid() for update;
 if not found then raise exception 'PROFILE_MISSING'; end if;
 if operation='me' then
  return jsonb_build_object('id',me.id,'role',me.role,'status',me.status,'username',me.username,'username_blocked',me.username_blocked,'lists',
   (select coalesce(jsonb_agg(to_jsonb(l) order by l.is_legacy desc,l.updated_at,l.id),'[]') from pull_private.lists l where l.owner_id=me.id));
 end if;
 if me.status='rejected' then raise exception 'NOT_APPROVED'; end if;
 if operation='username' then
  if me.username_blocked then raise exception 'USERNAME_LOCKED'; end if;
  clean:=pull_private.validate_username(payload->>'username');
  if exists(select 1 from pull_private.profiles where lower(username)=lower(clean) and id<>me.id) then raise exception 'USERNAME_TAKEN'; end if;
  update pull_private.profiles set username=clean where id=me.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation='create' then
  if (select count(*) from pull_private.lists where owner_id=me.id)>=10 then raise exception 'LIST_LIMIT'; end if;
  clean:=btrim(payload->>'name');
  if clean is null or char_length(clean) not between 1 and 80 then raise exception 'LIST_NAME'; end if;
  insert into pull_private.lists(owner_id,name,purpose) values(me.id,clean,coalesce(payload->>'purpose','pulls')) returning * into item;
  return to_jsonb(item);
 end if;
 if operation='search' then
  if me.role<>'admin' and (me.status<>'approved' or me.username is null or me.username_blocked) then raise exception 'SEARCH_REQUIRES_APPROVAL_AND_USERNAME'; end if;
  select coalesce(jsonb_agg(x),'[]') into result from (
   select l.id,l.name,l.purpose,l.display,p.username from pull_private.lists l join pull_private.profiles p on p.id=l.owner_id
   where l.visibility='public' and p.status='approved' and p.username is not null and not p.username_blocked
    and position(lower(left(coalesce(payload->>'query',''),24)) in lower(p.username))>0 order by lower(p.username),l.name,l.id limit 100
  ) x;
  return result;
 end if;
 if operation in ('admin-lists','export-all','restore-all','moderate-name') then
  if me.role<>'admin' or me.status<>'approved' then raise exception 'ADMIN_REQUIRED'; end if;
  if operation='admin-lists' then
   select coalesce(jsonb_agg(to_jsonb(l)||jsonb_build_object('username',p.username,'email',p.email,'status',p.status) order by p.email,l.is_legacy desc,l.name),'[]') into result from pull_private.lists l join pull_private.profiles p on p.id=l.owner_id where not p.request_archived;
   return result;
  end if;
  if operation='moderate-name' then
   if me.id<>'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid then raise exception 'ADMIN_REQUIRED'; end if;
   clean:=pull_private.validate_username(payload->>'username');
   update pull_private.profiles set username=clean,username_blocked=coalesce((payload->>'blocked')::boolean,false) where id=(payload->>'user_id')::uuid;
   return jsonb_build_object('ok',true);
  end if;
  if operation='export-all' then
   return jsonb_build_object('format','pokemon-pullrates','schema_version',2,'set','30thC-zh-Hans','scope','all','created_at',now(),'lists',(select coalesce(jsonb_agg(to_jsonb(l)),'[]') from pull_private.lists l));
  end if;
  if operation='restore-all' then
   if payload->>'format' is distinct from 'pokemon-pullrates' or payload->>'schema_version' is distinct from '2' or payload->>'set' is distinct from '30thC-zh-Hans' or payload->>'scope' is distinct from 'all' or jsonb_typeof(payload->'lists') is distinct from 'array' then raise exception 'INVALID_BACKUP';end if;
   if jsonb_array_length(payload->'lists')>10000 or exists(select 1 from jsonb_array_elements(payload->'lists') a group by a->>'id' having count(*)>1) then raise exception 'INVALID_BACKUP';end if;
   for entry in select * from jsonb_array_elements(payload->'lists') loop
    select * into item from pull_private.lists where id=(entry->>'id')::uuid for update;
    if not found or item.owner_id::text is distinct from entry->>'owner_id' then raise exception 'LIST_NOT_FOUND';end if;
    if item.version is distinct from (payload->'expected_versions'->>item.id::text)::integer then raise exception 'VERSION_CONFLICT';end if;
    perform pull_private.validate_counts(entry->'counts');
    if not(entry ? 'snapshot') then raise exception 'INVALID_BACKUP';end if;
    if entry->'snapshot'<>'null'::jsonb then perform pull_private.validate_counts(entry->'snapshot');end if;
    insert into pull_private.history(actor,target,action,previous_state) values(me.id,item.owner_id,'restore-list',to_jsonb(item));
    if item.is_legacy then update pull_private.profiles set counts=entry->'counts',version=version+1 where id=item.owner_id;end if;
    update pull_private.lists set counts=entry->'counts',snapshot=nullif(entry->'snapshot','null'::jsonb),snapshot_version=case when entry->'snapshot'<>'null'::jsonb then version+1 else null end,version=version+1,updated_at=now() where id=item.id;
   end loop;
   perform pull_private.refresh_rates();return jsonb_build_object('ok',true);
  end if;
 end if;
 select * into item from pull_private.lists where id=(payload->>'list_id')::uuid for update;
 if not found then raise exception 'LIST_NOT_FOUND'; end if;
 select * into target from pull_private.profiles where id=item.owner_id;
 full_access:=item.owner_id=me.id or me.role='admin';
 if operation='view' then
  if not full_access and (me.status<>'approved' or me.username is null or me.username_blocked or target.status<>'approved' or target.username is null or target.username_blocked or item.visibility<>'public') then raise exception 'LIST_NOT_FOUND'; end if;
  select coalesce(sum(coalesce((item.counts->>c.id)::numeric,0)),0) into total from pull_private.cards c where c.booster_slot;
  select jsonb_object_agg(c.id,case when total=0 or coalesce((item.counts->>c.id)::numeric,0)=0 then null else round(total/(item.counts->>c.id)::numeric,2) end) into r from pull_private.cards c;
  return jsonb_build_object('id',item.id,'name',item.name,'username',target.username,'purpose',item.purpose,'display',item.display,
   'counts',case when full_access or item.display<>'rates_only' then item.counts else null end,
   'boosters',case when full_access or (item.display='all' and item.purpose='pulls') then total else null end,
   'rates',case when item.purpose='pulls' then r else null end);
 end if;
 if operation in ('include','exclude') then
  if me.role<>'admin' or me.status<>'approved' then raise exception 'ADMIN_REQUIRED';end if;
  if item.version is distinct from (payload->>'version')::integer then raise exception 'VERSION_CONFLICT';end if;
  if operation='include' and (item.purpose<>'pulls' or target.status<>'approved') then raise exception 'NOT_ELIGIBLE';end if;
  insert into pull_private.history(actor,target,action,previous_state) values(me.id,item.owner_id,operation||'-list',to_jsonb(item));
  update pull_private.lists set snapshot=case when operation='include' then counts else null end,snapshot_version=case when operation='include' then version+1 else null end,owner_live=false,version=version+1,updated_at=now() where id=item.id;
  perform pull_private.refresh_rates();return jsonb_build_object('ok',true);
 end if;
 if item.owner_id<>me.id then raise exception 'NOT_OWNER';end if;
 if item.version is distinct from (payload->>'version')::integer then raise exception 'VERSION_CONFLICT';end if;
 if operation='save' then
  perform pull_private.validate_counts(payload->'counts');
  insert into pull_private.history(actor,target,action,previous_state) values(me.id,me.id,'save-list',to_jsonb(item));
  if item.is_legacy then
   update pull_private.profiles set counts=payload->'counts',version=version+1,updated_at=now() where id=me.id;
  else
   update pull_private.lists set counts=payload->'counts',version=version+1,updated_at=now() where id=item.id;
  end if;
  perform pull_private.refresh_rates();
  select * into item from pull_private.lists where id=item.id;
  return to_jsonb(item);
 end if;
 if operation='settings' then
  clean:=btrim(payload->>'name');
  if clean is null or char_length(clean) not between 1 and 80 then raise exception 'LIST_NAME';end if;
  if payload->>'visibility'='public' and (me.status<>'approved' or me.username is null or me.username_blocked) then raise exception 'PUBLIC_REQUIRES_APPROVAL_AND_USERNAME';end if;
  if item.purpose is distinct from payload->>'purpose' and (item.owner_live or item.snapshot is not null) then raise exception 'EXCLUDE_BEFORE_PURPOSE_CHANGE';end if;
  update pull_private.lists set name=clean,purpose=payload->>'purpose',visibility=payload->>'visibility',display=payload->>'display',version=version+1,updated_at=now() where id=item.id returning * into item;
  return to_jsonb(item);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.list_application(text,jsonb) from public,anon;
grant execute on function pull_private.list_application(text,jsonb) to authenticated;
create function public.pull_lists(operation text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select pull_private.list_application(operation,payload); $$;
revoke all on function public.pull_lists(text,jsonb) from public,anon;
grant execute on function public.pull_lists(text,jsonb) to authenticated;
-- Migration must not change original data or existing published rates.
do $$ begin
 if exists(select 1 from pull_private.profiles p left join pull_private.lists l on l.owner_id=p.id and l.is_legacy where l.id is null or p.counts is distinct from l.counts or p.snapshot is distinct from l.snapshot) then raise exception 'MIGRATION_DATA_MISMATCH';end if;
end $$;
