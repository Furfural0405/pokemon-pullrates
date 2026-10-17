create function pull_private.copy_pulls_to_trade(payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare me pull_private.profiles;source pull_private.lists;destination pull_private.lists;merged jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 perform pg_advisory_xact_lock(3046103);
 select * into me from pull_private.profiles where id=auth.uid();
 if not found or me.status='rejected' then raise exception 'NOT_APPROVED';end if;
 select * into source from pull_private.lists where id=(payload->>'source_id')::uuid and owner_id=me.id and purpose='pulls' for update;
 if not found then raise exception 'SOURCE_PULL_LIST_REQUIRED';end if;
 select * into destination from pull_private.lists where id=(payload->>'target_id')::uuid and owner_id=me.id and purpose='trade' for update;
 if not found then raise exception 'OWN_TRADE_LIST_REQUIRED';end if;
 if source.version is distinct from (payload->>'source_version')::integer or destination.version is distinct from (payload->>'target_version')::integer then raise exception 'VERSION_CONFLICT';end if;
 perform pull_private.validate_counts(payload->'counts');
 if payload->'counts'='{}'::jsonb then raise exception 'NO_CARDS_SELECTED';end if;
 if exists(select 1 from jsonb_object_keys(payload->'counts') k where coalesce((source.counts->>k)::numeric,0)<=0) then raise exception 'CARD_NOT_IN_SOURCE';end if;
 merged:=destination.counts||(payload->'counts');
 insert into pull_private.history(actor,target,action,previous_state) values(me.id,me.id,'copy-to-trade',to_jsonb(destination)||jsonb_build_object('source_id',source.id,'source_version',source.version));
 if destination.is_legacy then
  update pull_private.profiles set counts=merged,version=version+1,updated_at=now() where id=me.id;
 else
  update pull_private.lists set counts=merged,version=version+1,updated_at=now() where id=destination.id;
 end if;
 select * into destination from pull_private.lists where id=destination.id;
 return to_jsonb(destination);
end $$;
revoke all on function pull_private.copy_pulls_to_trade(jsonb) from public,anon;
grant execute on function pull_private.copy_pulls_to_trade(jsonb) to authenticated;
create function public.pull_copy_to_trade(payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select pull_private.copy_pulls_to_trade(payload);$$;
revoke all on function public.pull_copy_to_trade(jsonb) from public,anon;
grant execute on function public.pull_copy_to_trade(jsonb) to authenticated;
