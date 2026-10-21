-- Private stock is never added to list rows, admin exports, public APIs or statistics.
create table pull_private.inventory (
 list_id uuid primary key references pull_private.lists(id) on delete cascade,
 master jsonb not null default '{}',binder jsonb not null default '{}',given jsonb not null default '{}',
 revision integer not null default 0
);
alter table pull_private.inventory enable row level security;
revoke all on pull_private.inventory from public,anon,authenticated;
create table pull_private.inventory_requests (
 request_id uuid primary key,list_id uuid not null references pull_private.lists(id) on delete cascade,
 payload jsonb not null,result jsonb not null,created_at timestamptz not null default now()
);
create index inventory_requests_list on pull_private.inventory_requests(list_id);
alter table pull_private.inventory_requests enable row level security;
revoke all on pull_private.inventory_requests from public,anon,authenticated;
create function pull_private.stock_available(totals jsonb,m jsonb,b jsonb,g jsonb) returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_object_agg(id,coalesce((totals->>id)::int,0)-coalesce((m->>id)::int,0)-coalesce((b->>id)::int,0)-coalesce((g->>id)::int,0)),'{}') from pull_private.cards;
$$;
create function pull_private.stock_sets(bound jsonb) returns integer language sql stable security invoker set search_path='' as $$
 select coalesce(min(coalesce((bound->>id)::int,0)),0) from pull_private.cards where id not in ('mew-rgb-r','mew-rgb-g','mew-rgb-b');
$$;
create function pull_private.validate_stock(totals jsonb,m jsonb,b jsonb,g jsonb) returns void language plpgsql security invoker set search_path='' as $$
begin
 perform pull_private.validate_counts(totals);perform pull_private.validate_counts(m);perform pull_private.validate_counts(b);perform pull_private.validate_counts(g);
 if exists(select 1 from jsonb_each_text(pull_private.stock_available(totals,m,b,g)) where value::int<0) then raise exception 'STOCK_EXCEEDS_TOTAL';end if;
end $$;
create function pull_private.stock_result(list_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('list',to_jsonb(l),'master',coalesce(i.master,'{}'),'binder',coalesce(i.binder,'{}'),'given',coalesce(i.given,'{}'),'revision',coalesce(i.revision,0),'available',pull_private.stock_available(l.counts,coalesce(i.master,'{}'),coalesce(i.binder,'{}'),coalesce(i.given,'{}')),'master_sets',pull_private.stock_sets(coalesce(i.master,'{}')),'binder_sets',pull_private.stock_sets(coalesce(i.binder,'{}'))) from pull_private.lists l left join pull_private.inventory i on i.list_id=l.id where l.id=stock_result.list_id;
$$;
-- This guard also protects old clients, imports and administrative restore paths.
create function pull_private.guard_stock_totals() returns trigger language plpgsql security definer set search_path='' as $$
declare i pull_private.inventory;
begin
 select * into i from pull_private.inventory where list_id=new.id;
 if found then
  perform pull_private.validate_stock(new.counts,i.master,i.binder,i.given);
  if new.purpose<>old.purpose and exists(select 1 from jsonb_each_text(i.master||'{}'::jsonb) where value::int>0 union all select 1 from jsonb_each_text(i.binder) where value::int>0 union all select 1 from jsonb_each_text(i.given) where value::int>0) then raise exception 'CLEAR_STOCK_BEFORE_PURPOSE_CHANGE';end if;
 end if;
 return new;
end $$;
create trigger guard_stock_totals before update of counts,purpose on pull_private.lists for each row execute function pull_private.guard_stock_totals();
create function pull_private.inventory_application(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  perform pull_private.validate_counts(payload->'counts');perform pull_private.validate_counts(payload->'new_pulls');
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
revoke all on function pull_private.stock_available(jsonb,jsonb,jsonb,jsonb),pull_private.stock_sets(jsonb),pull_private.validate_stock(jsonb,jsonb,jsonb,jsonb),pull_private.stock_result(uuid),pull_private.guard_stock_totals(),pull_private.inventory_application(text,jsonb) from public,anon,authenticated;
grant execute on function pull_private.inventory_application(text,jsonb) to authenticated;
create function public.pull_inventory(operation text,payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.inventory_application(operation,payload);$$;
revoke all on function public.pull_inventory(text,jsonb) from public,anon;
grant execute on function public.pull_inventory(text,jsonb) to authenticated;
-- Replace delta/watermark transfer with a direct, checked availability proposal.
create or replace function pull_private.trade_transfer_preview(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare source pull_private.lists;destination pull_private.lists;stock jsonb;available jsonb;rows jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 stock:=pull_private.inventory_application('get',jsonb_build_object('list_id',payload->>'source_id'));
 select * into source from pull_private.lists where id=(payload->>'source_id')::uuid;
 select * into destination from pull_private.lists where id=(payload->>'target_id')::uuid and owner_id=auth.uid() and purpose='trade';if not found then raise exception 'OWN_TRADE_LIST_REQUIRED';end if;
 if jsonb_typeof(payload->'card_ids') is distinct from 'array' or jsonb_array_length(payload->'card_ids') not between 1 and 176 then raise exception 'NO_CARDS_SELECTED';end if;
 if exists(select 1 from jsonb_array_elements_text(payload->'card_ids') k where not exists(select 1 from pull_private.cards where id=k)) then raise exception 'INVALID_COUNTS';end if;
 available:=stock->'available';
 select jsonb_object_agg(k,jsonb_build_object('available',coalesce((available->>k)::int,0),'offer_count',coalesce((destination.counts->>k)::int,0))) into rows from (select distinct value k from jsonb_array_elements_text(payload->'card_ids')) x;
 return jsonb_build_object('protocol',3,'source_id',source.id,'source_version',source.version,'inventory_revision',stock->'revision','target_id',destination.id,'target_version',destination.version,'cards',rows);
end $$;
create or replace function pull_private.copy_pulls_to_trade(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare source pull_private.lists;destination pull_private.lists;preview jsonb;merged jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 if payload->>'protocol' is distinct from '3' then raise exception 'TRANSFER_PREVIEW_REQUIRED';end if;
 perform pull_private.validate_counts(payload->'counts');
 preview:=pull_private.trade_transfer_preview(jsonb_build_object('source_id',payload->>'source_id','target_id',payload->>'target_id','card_ids',(select jsonb_agg(key) from jsonb_object_keys(payload->'counts') key)));
 if (preview->>'source_version')::int is distinct from (payload->>'source_version')::int or (preview->>'target_version')::int is distinct from (payload->>'target_version')::int or (preview->>'inventory_revision')::int is distinct from (payload->>'inventory_revision')::int then raise exception 'VERSION_CONFLICT';end if;
 if exists(select 1 from jsonb_each_text(payload->'counts') x where value::int>(preview->'cards'->key->>'available')::int) then raise exception 'OFFER_EXCEEDS_AVAILABLE';end if;
 select * into destination from pull_private.lists where id=(payload->>'target_id')::uuid;
 merged:=destination.counts||(payload->'counts');
 return pull_private.list_application('save',jsonb_build_object('list_id',destination.id,'version',destination.version,'counts',merged));
end $$;
-- Previous marks remain archived; no personal counts, snapshots or offers are rewritten.
create or replace function public.pull_trade_preview(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.trade_transfer_preview(payload);$$;
create or replace function public.pull_copy_to_trade(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.copy_pulls_to_trade(payload);$$;
revoke all on function pull_private.trade_transfer_preview(jsonb),pull_private.copy_pulls_to_trade(jsonb),public.pull_trade_preview(jsonb),public.pull_copy_to_trade(jsonb) from public,anon;
grant execute on function pull_private.trade_transfer_preview(jsonb),pull_private.copy_pulls_to_trade(jsonb),public.pull_trade_preview(jsonb),public.pull_copy_to_trade(jsonb) to authenticated;
