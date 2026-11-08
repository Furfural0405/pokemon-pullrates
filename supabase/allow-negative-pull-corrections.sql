-- Signed corrections are accepted only for 'new_pulls'; all final counts and allocations stay nonnegative.
-- Existing rows, snapshots and statistics are not modified by this migration.
create or replace function pull_private.validate_pull_deltas(payload jsonb) returns void language plpgsql security invoker set search_path='' as $$
declare item record;
begin
 if payload is null or jsonb_typeof(payload)<>'object' then raise exception 'INVALID_PULL_DELTAS: Kartenwerte müssen ein Objekt sein';end if;
 if pg_column_size(payload)>100000 then raise exception 'INVALID_PULL_DELTAS: Eingabe zu groß';end if;
 for item in select * from jsonb_each(payload) loop
  if not exists(select 1 from pull_private.cards where id=item.key) or jsonb_typeof(item.value)<>'number' or item.value::text !~ '^-?[0-9]+$' then raise exception 'INVALID_PULL_DELTAS: Unbekannte Karte oder ungültige Korrektur';end if;
  if abs((item.value::text)::numeric)>1000000 then raise exception 'INVALID_PULL_DELTAS: Maximal +/- 1.000.000 je Karte';end if;
 end loop;
end $$;
revoke all on function pull_private.validate_pull_deltas(jsonb) from public,anon,authenticated;
create or replace function pull_private.inventory_application(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare l pull_private.lists;i pull_private.inventory;totals jsonb;m jsonb;b jsonb;g jsonb;available jsonb;missing jsonb;result jsonb;previous_binder int;delta int;req uuid;prior pull_private.inventory_requests;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 if not exists(select 1 from pull_private.profiles where id=auth.uid() and status<>'rejected') then raise exception 'NOT_APPROVED';end if;
 select * into l from pull_private.lists where id=(payload->>'list_id')::uuid and owner_id=auth.uid() and purpose='pulls' for update;
 if not found then raise exception 'OWN_PULL_LIST_REQUIRED';end if;
 select * into i from pull_private.inventory where list_id=l.id for update;
 m:=coalesce(i.master,'{}');b:=coalesce(i.binder,'{}');g:=coalesce(i.given,'{}');
 if operation='get' then return pull_private.stock_result(l.id);end if;
 if operation='save' then
  req:=(payload->>'request_id')::uuid;if req is null then raise exception 'REQUEST_ID_REQUIRED';end if;
  select * into prior from pull_private.inventory_requests where request_id=req;
  if found then
   if prior.list_id<>l.id or prior.payload<>payload then raise exception 'REQUEST_REUSED';end if;
   return prior.result;
  end if;
 end if;
 if l.version is distinct from (payload->>'version')::int or coalesce(i.revision,0) is distinct from (payload->>'revision')::int then raise exception 'VERSION_CONFLICT';end if;
 previous_binder:=pull_private.stock_sets(b);
 if operation='save' then
  perform pull_private.validate_counts(payload->'counts');perform pull_private.validate_pull_deltas(payload->'new_pulls');
  select jsonb_object_agg(id,coalesce((payload->'counts'->>id)::int,0)+coalesce((payload->'new_pulls'->>id)::int,0)) into totals from pull_private.cards;
  m:=payload->'master';b:=payload->'binder';g:=payload->'given';
  perform pull_private.validate_stock(totals,m,b,g);
 elsif operation='master' then
  delta:=(payload->>'delta')::int;if delta is null or delta=0 or abs(delta::bigint)>1000000 then raise exception 'INVALID_MASTER_DELTA';end if;
  available:=pull_private.stock_available(l.counts,m,b,g);
  if delta>0 then
   select coalesce(jsonb_agg(jsonb_build_object('card_id',id,'missing',delta-coalesce((available->>id)::int,0)) order by id),'[]') into missing from pull_private.cards where id not in ('mew-rgb-r','mew-rgb-g','mew-rgb-b') and coalesce((available->>id)::int,0)<delta;
   if jsonb_array_length(missing)>0 then return jsonb_build_object('applied',false,'missing',missing);end if;
  end if;
  select m||jsonb_object_agg(id,coalesce((m->>id)::int,0)+delta) into m from pull_private.cards where id not in ('mew-rgb-r','mew-rgb-g','mew-rgb-b');
  totals:=l.counts;perform pull_private.validate_stock(totals,m,b,g);
 else raise exception 'UNKNOWN_OPERATION';end if;
 -- Allocations must be updated before the total guard runs, in the same transaction.
 insert into pull_private.inventory(list_id,master,binder,given,revision) values(l.id,m,b,g,1) on conflict(list_id) do update set master=excluded.master,binder=excluded.binder,given=excluded.given,revision=inventory.revision+1;
 if operation='save' and totals is distinct from (select jsonb_object_agg(id,coalesce((l.counts->>id)::int,0)) from pull_private.cards) then
  perform pull_private.list_application('save',jsonb_build_object('list_id',l.id,'version',l.version,'counts',totals));
 end if;
 result:=pull_private.stock_result(l.id)||jsonb_build_object('applied',true,'previous_binder_sets',previous_binder);
 if operation='save' then insert into pull_private.inventory_requests(request_id,list_id,payload,result) values(req,l.id,payload,result);end if;
 return result;
end $$;
