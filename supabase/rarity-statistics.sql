create function pull_private.rarity_statistics(card_counts jsonb,show_counts boolean default false) returns jsonb language sql stable security invoker set search_path='' as $$
 with card_values as (
  select c.id,c.booster_slot,coalesce(d.rarity,b.rarity,'Unbekannt') rarity,coalesce((card_counts->>c.id)::numeric,0) n
  from pull_private.cards c left join pull_private.card_rarities b on b.card_id=c.id left join public.card_details d on d.card_id=c.id
 ), totals as (select rarity,sum(n) n from card_values group by rarity), base as (select coalesce(sum(n) filter(where booster_slot),0) n from card_values)
 select jsonb_build_object('classes',(select coalesce(jsonb_object_agg(t.rarity,jsonb_build_object('rate',case when t.n>0 and b.n>0 then b.n/t.n else null end,'fraction',case when b.n>0 then t.n/b.n else null end)||case when show_counts then jsonb_build_object('count',t.n) else '{}'::jsonb end),'{}') from totals t cross join base b),
 'within',(select coalesce(jsonb_object_agg(c.id,jsonb_build_object('rarity',c.rarity,'rate',case when c.n>0 and t.n>0 then t.n/c.n else null end,'fraction',case when t.n>0 then c.n/t.n else null end)),'{}') from card_values c join totals t using(rarity)));
$$;
revoke all on function pull_private.rarity_statistics(jsonb,boolean) from public,anon,authenticated;
create function pull_private.public_rarity_statistics() returns jsonb language plpgsql security definer set search_path='' as $$
declare totals jsonb;visible_counts boolean;
begin
 totals:=pull_private.community_counts();
 visible_counts:=auth.uid() is not null and (coalesce((select show_public_counts from pull_private.settings where id=true),false) or exists(select 1 from pull_private.profiles where id=auth.uid() and status='approved' and role='admin'));
 return pull_private.rarity_statistics(totals->'counts',visible_counts);
end $$;
revoke all on function pull_private.public_rarity_statistics() from public;
grant execute on function pull_private.public_rarity_statistics() to anon,authenticated;
grant usage on schema pull_private to anon;
create function public.pull_rarity_stats() returns jsonb language sql security invoker set search_path='' as $$select pull_private.public_rarity_statistics();$$;
revoke all on function public.pull_rarity_stats() from public;
grant execute on function public.pull_rarity_stats() to anon,authenticated;
do $migration$
declare definition text;old_fragment text:=$old$'rates',case when item.purpose='pulls' then r else null end);$old$;
begin
 definition:=pg_get_functiondef('pull_private.list_application(text,jsonb)'::regprocedure);
 if position(old_fragment in definition)=0 then raise exception 'LIST_VIEW_FRAGMENT_NOT_FOUND';end if;
 definition:=replace(definition,old_fragment,$new$'rates',case when item.purpose='pulls' then r else null end,'rarity_stats',case when item.purpose='pulls' then pull_private.rarity_statistics(item.counts,full_access or item.display<>'rates_only') else null end);$new$);
 execute definition;
end $migration$;
