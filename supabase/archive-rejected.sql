alter table pull_private.profiles add column request_archived boolean not null default false;
CREATE OR REPLACE FUNCTION pull_private.application(operation text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 if operation='archive-rejected' then
  if me.id<>'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid then raise exception 'ADMIN_REQUIRED'; end if;
  select * into target from pull_private.profiles where id=(payload->>'user_id')::uuid for update;
  if not found then raise exception 'USER_NOT_FOUND'; end if;
  if target.role='admin' or target.status<>'rejected' then raise exception 'ONLY_REJECTED_USERS'; end if;
  if (payload->>'version')::integer is distinct from target.version then raise exception 'VERSION_CONFLICT'; end if;
  insert into pull_private.history(actor,target,action,previous_state) values(me.id,target.id,'archive-rejected',to_jsonb(target));
  update pull_private.profiles set request_archived=true,version=version+1,updated_at=now() where id=target.id;
  return jsonb_build_object('ok',true);
 end if;
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
end $function$
;

