-- Additive migration: no changes to existing counts, snapshots or transfer marks.
create table public.cardmarket_catalog (
 product_id bigint primary key, name text not null, low numeric check(low>=0),avg7 numeric check(avg7>=0), source_at timestamptz not null
);
alter table public.cardmarket_catalog enable row level security;
revoke all on public.cardmarket_catalog from anon,authenticated;
grant select on public.cardmarket_catalog to authenticated;
create policy catalog_owner_read on public.cardmarket_catalog for select to authenticated using((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid);
create table public.cardmarket_prices (
 card_id text primary key references pull_private.cards(id),
 cardmarket_url text not null check(cardmarket_url ~ '^https://www[.]cardmarket[.]com/(de|en)/Pokemon/Products/Singles/30th-Celebration-Simplified-Chinese/[A-Za-z0-9-]+$'),
 product_id bigint references public.cardmarket_catalog(product_id),
 low numeric check(low>=0),avg7 numeric check(avg7>=0),
 unit_eur numeric generated always as(case when low is not null and avg7 is not null then round(low*0.9+avg7*0.1,2) else null end) stored,
 source_at timestamptz, checked_at timestamptz,status text not null default 'unmapped' check(status in ('unmapped','ok','missing','error'))
);
alter table public.cardmarket_prices enable row level security;
revoke all on public.cardmarket_prices from anon,authenticated;
grant select on public.cardmarket_prices to anon,authenticated;
create policy market_prices_read on public.cardmarket_prices for select to anon,authenticated using(true);
grant all on public.cardmarket_catalog,public.cardmarket_prices to service_role;
alter table pull_private.lists add column value_public boolean not null default false;
create function pull_private.valuation(card_counts jsonb) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('total_eur',coalesce(sum(n*p.unit_eur),0),'valued_copies',coalesce(sum(n) filter(where p.unit_eur is not null),0),'unvalued_copies',coalesce(sum(n) filter(where p.unit_eur is null),0),'stale_copies',coalesce(sum(n) filter(where p.unit_eur is not null and (p.status<>'ok' or p.source_at<now()-interval '48 hours')),0),'source_at',min(p.source_at) filter(where p.unit_eur is not null)) from jsonb_each_text(card_counts) c cross join lateral (select c.value::numeric n) v left join public.cardmarket_prices p on p.card_id=c.key where n>0;
$$;
revoke all on function pull_private.valuation(jsonb) from public,anon,authenticated;
create function pull_private.visible_valuation(card_counts jsonb,show_counts boolean) returns jsonb language sql stable security invoker set search_path='' as $$
 select case when show_counts then v else (v-'valued_copies'-'unvalued_copies'-'stale_copies')||jsonb_build_object('has_prices',(v->>'valued_copies')::numeric>0,'incomplete',(v->>'unvalued_copies')::numeric>0,'stale',(v->>'stale_copies')::numeric>0) end from (select pull_private.valuation(card_counts) v) x;
$$;
revoke all on function pull_private.visible_valuation(jsonb,boolean) from public,anon,authenticated;
-- Extend the existing permission-checked list API, retaining all previous logic.
do $patch$
declare d text;old text;
begin
 d:=pg_get_functiondef('pull_private.list_application(text,jsonb)'::regprocedure);
 old:=$s$'display',item.display,$s$;
 if position(old in d)=0 then raise exception 'LIST_VIEW_PATCH_MISMATCH';end if;
 d:=replace(d,old,$s$'display',item.display,'value_public',item.value_public,'valuation',case when full_access or item.value_public then pull_private.visible_valuation(item.counts,full_access or item.display<>'rates_only') else null end,$s$);
 old:=$s$display=payload->>'display',version=version+1$s$;
 if position(old in d)=0 then raise exception 'LIST_SETTINGS_PATCH_MISMATCH';end if;
 d:=replace(d,old,$s$display=payload->>'display',value_public=case when payload ? 'value_public' then (payload->>'value_public')::boolean else value_public end,version=version+1$s$);
 execute d;
end $patch$;
create function pull_private.save_market_link(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare card text:=payload->>'card_id';link text:=nullif(btrim(payload->>'url'),'');product public.cardmarket_catalog;pid bigint;slug text;
begin
 if auth.uid() is distinct from 'e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid or not exists(select 1 from pull_private.profiles where id=auth.uid() and role='admin' and status='approved') then raise exception 'OWNER_REQUIRED';end if;
 if not exists(select 1 from pull_private.cards where id=card) then raise exception 'UNKNOWN_CARD';end if;
 if link is null then delete from public.cardmarket_prices where card_id=card;return jsonb_build_object('ok',true);end if;
 if link !~ '^https://www[.]cardmarket[.]com/(de|en)/Pokemon/Products/Singles/30th-Celebration-Simplified-Chinese/[A-Za-z0-9-]+$' then raise exception 'INVALID_CARDMARKET_LINK';end if;
 pid:=nullif(payload->>'product_id','')::bigint;
 if pid is not null then
  select * into product from public.cardmarket_catalog where product_id=pid;
  if not found then raise exception 'UNKNOWN_PRODUCT';end if;
  slug:=regexp_replace(regexp_replace(regexp_replace(link,'^.*/',''),'-30thC[0-9]+$','','i'),'-V[0-9]+$','','i');
  if regexp_replace(lower(slug),'[^a-z0-9]','','g')<>regexp_replace(translate(lower(split_part(product.name,' [',1)),'éèêëáàâäíìîïóòôöúùûüñç','eeeeaaaaiiiioooouuuunc'),'[^a-z0-9]','','g') then raise exception 'PRODUCT_LINK_MISMATCH';end if;
 end if;
 insert into public.cardmarket_prices(card_id,cardmarket_url,product_id,low,avg7,source_at,checked_at,status)
 values(card,link,pid,product.low,product.avg7,product.source_at,now(),case when pid is null then 'unmapped' when product.low is null or product.avg7 is null then 'missing' else 'ok' end)
 on conflict(card_id) do update set cardmarket_url=excluded.cardmarket_url,product_id=excluded.product_id,low=excluded.low,avg7=excluded.avg7,source_at=excluded.source_at,checked_at=excluded.checked_at,status=excluded.status;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function pull_private.save_market_link(jsonb) from public;
grant execute on function pull_private.save_market_link(jsonb) to authenticated;
create function public.pull_save_market_link(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.save_market_link(payload);$$;
revoke all on function public.pull_save_market_link(jsonb) from public;
grant execute on function public.pull_save_market_link(jsonb) to authenticated;
-- Worker authentication is separate from user login and stored only as a hash.
create table pull_private.market_worker_state(id boolean primary key default true check(id),token_hash text not null,running_until timestamptz,last_attempt timestamptz,last_success timestamptz,last_error text);
alter table pull_private.market_worker_state enable row level security;
revoke all on pull_private.market_worker_state from public,anon,authenticated;
create function pull_private.market_worker(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare state pull_private.market_worker_state;row jsonb;at_time timestamptz;
begin
 if auth.jwt()->>'role' is distinct from 'service_role' then raise exception 'WORKER_REQUIRED';end if;
 select * into state from pull_private.market_worker_state where id=true for update;
 if state.token_hash is null or state.token_hash<>encode(extensions.digest(coalesce(payload->>'token',''),'sha256'),'hex') then raise exception 'WORKER_REQUIRED';end if;
 if operation='claim' then
  if state.running_until>now() then return jsonb_build_object('run',false);end if;
  update pull_private.market_worker_state set running_until=now()+interval '4 minutes',last_attempt=now() where id=true;
  return jsonb_build_object('run',true);
 elsif operation='finish' then
  at_time:=(payload->>'source_at')::timestamptz;
  if at_time>now()+interval '1 day' or at_time is null or at_time<(select max(source_at) from public.cardmarket_catalog) or jsonb_array_length(payload->'products') not between 1 and 1000 then raise exception 'INVALID_SOURCE';end if;
  for row in select * from jsonb_array_elements(payload->'products') loop
   insert into public.cardmarket_catalog(product_id,name,low,avg7,source_at) values((row->>'product_id')::bigint,row->>'name',(row->>'low')::numeric,(row->>'avg7')::numeric,at_time)
   on conflict(product_id) do update set name=excluded.name,low=excluded.low,avg7=excluded.avg7,source_at=excluded.source_at;
  end loop;
  update public.cardmarket_prices p set
   low=case when c.low is not null and c.avg7 is not null then c.low else p.low end,
   avg7=case when c.low is not null and c.avg7 is not null then c.avg7 else p.avg7 end,
   source_at=case when c.low is not null and c.avg7 is not null then c.source_at else p.source_at end,
   checked_at=now(),status=case when c.low is null or c.avg7 is null then 'missing' else 'ok' end
  from public.cardmarket_catalog c where c.product_id=p.product_id and c.source_at=at_time;
  update public.cardmarket_prices p set status='missing',checked_at=now() where product_id is not null and not exists(select 1 from public.cardmarket_catalog c where c.product_id=p.product_id and c.source_at=at_time);
  update pull_private.market_worker_state set running_until=null,last_success=now(),last_error=null where id=true;
 elsif operation='fail' then
  update public.cardmarket_prices set status='error',checked_at=now() where product_id is not null;
  update pull_private.market_worker_state set running_until=null,last_error=left(payload->>'error',200) where id=true;
 else raise exception 'UNKNOWN_OPERATION';end if;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function pull_private.market_worker(text,jsonb) from public,anon,authenticated;
grant execute on function pull_private.market_worker(text,jsonb) to service_role;
grant usage on schema pull_private to service_role;
create function public.pull_market_worker(operation text,payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.market_worker(operation,payload);$$;
revoke all on function public.pull_market_worker(text,jsonb) from public,anon,authenticated;
grant execute on function public.pull_market_worker(text,jsonb) to service_role;
