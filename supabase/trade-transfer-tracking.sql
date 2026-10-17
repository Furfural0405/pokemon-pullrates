create table pull_private.trade_transfer_marks(source_id uuid not null references pull_private.lists(id) on delete cascade,target_id uuid not null references pull_private.lists(id) on delete cascade,card_id text not null references pull_private.cards(id),pull_count integer not null check(pull_count between 0 and 1000000),version integer not null default 1,primary key(source_id,target_id,card_id));
alter table pull_private.trade_transfer_marks enable row level security;
revoke all on pull_private.trade_transfer_marks from public,anon,authenticated;
create function pull_private.trade_transfer_preview(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare source pull_private.lists;destination pull_private.lists;rows jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 if not exists(select 1 from pull_private.profiles where id=auth.uid() and status<>'rejected') then raise exception 'NOT_APPROVED';end if;
 select * into source from pull_private.lists where id=(payload->>'source_id')::uuid and owner_id=auth.uid() and purpose='pulls';if not found then raise exception 'SOURCE_PULL_LIST_REQUIRED';end if;
 select * into destination from pull_private.lists where id=(payload->>'target_id')::uuid and owner_id=auth.uid() and purpose='trade';if not found then raise exception 'OWN_TRADE_LIST_REQUIRED';end if;
 if jsonb_typeof(payload->'card_ids') is distinct from 'array' or jsonb_array_length(payload->'card_ids') not between 1 and 176 then raise exception 'NO_CARDS_SELECTED';end if;
 if exists(select 1 from jsonb_array_elements_text(payload->'card_ids') k where not exists(select 1 from pull_private.cards where id=k)) then raise exception 'INVALID_COUNTS';end if;
 select jsonb_object_agg(k,jsonb_build_object('pull_count',coalesce((source.counts->>k)::int,0),'offer_count',coalesce((destination.counts->>k)::int,0),'baseline',coalesce(m.pull_count,coalesce((source.counts->>k)::int,0)),'mark_version',coalesce(m.version,0),'mode',case when m.card_id is not null then case when coalesce((source.counts->>k)::int,0)<m.pull_count then 'decrease' else 'tracked' end when destination.counts ? k then 'baseline_required' else 'initial' end)) into rows from (select distinct value k from jsonb_array_elements_text(payload->'card_ids')) selected left join pull_private.trade_transfer_marks m on m.source_id=source.id and m.target_id=destination.id and m.card_id=k;
 return jsonb_build_object('source_id',source.id,'source_version',source.version,'target_id',destination.id,'target_version',destination.version,'cards',rows);
end $$;
revoke all on function pull_private.trade_transfer_preview(jsonb) from public,anon;
grant execute on function pull_private.trade_transfer_preview(jsonb) to authenticated;
create function public.pull_trade_preview(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.trade_transfer_preview(payload);$$;
revoke all on function public.pull_trade_preview(jsonb) from public,anon;
grant execute on function public.pull_trade_preview(jsonb) to authenticated;
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('pull_private.copy_pulls_to_trade(jsonb)'::regprocedure);
 definition:=replace(definition,'merged jsonb;','merged jsonb;preview jsonb;k text;');
 definition:=replace(definition,' perform pull_private.validate_counts(payload->''counts'');',$new$
 if payload->>'protocol' is distinct from '2' then raise exception 'TRANSFER_PREVIEW_REQUIRED';end if;
 perform pull_private.validate_counts(payload->'counts');
 preview:=pull_private.trade_transfer_preview(jsonb_build_object('source_id',source.id,'target_id',destination.id,'card_ids',(select jsonb_agg(key) from jsonb_object_keys(payload->'counts') key)));
 for k in select jsonb_object_keys(payload->'counts') loop
  if (payload->'expected_marks'->>k)::int is distinct from (preview->'cards'->k->>'mark_version')::int then raise exception 'VERSION_CONFLICT';end if;
  if preview->'cards'->k->>'mode' in ('baseline_required','decrease') and (payload->'confirmations'->k) is distinct from 'true'::jsonb then raise exception 'TRANSFER_BASELINE_CONFIRMATION_REQUIRED';end if;
 end loop;
$new$);
 definition:=replace(definition,' merged:=destination.counts||', $new$
 insert into pull_private.trade_transfer_marks(source_id,target_id,card_id,pull_count)
 select source.id,destination.id,key,coalesce((source.counts->>key)::int,0) from jsonb_object_keys(payload->'counts') key
 on conflict(source_id,target_id,card_id) do update set pull_count=excluded.pull_count,version=trade_transfer_marks.version+1;
 merged:=destination.counts||$new$);
 definition:=replace(definition,'jsonb_object_keys(payload->''counts'') k where coalesce((source.counts->>k)','jsonb_object_keys(payload->''counts'') as selected_keys(card_key) where coalesce((source.counts->>card_key)');
 execute definition;
end $migration$;
