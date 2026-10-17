-- A narrow read-only API, without granting anonymous access to account operations.
create function pull_private.visible_community_counts() returns jsonb language plpgsql security definer set search_path='' as $$
declare enabled boolean;
begin
 select show_public_counts into enabled from pull_private.settings where id=true;
 if coalesce(enabled,false) or exists(select 1 from pull_private.profiles where id=auth.uid() and role='admin' and status='approved') then
  return pull_private.community_counts()||jsonb_build_object('enabled',coalesce(enabled,false));
 end if;
 return jsonb_build_object('enabled',false,'counts',null,'boosters',null);
end $$;
revoke all on function pull_private.visible_community_counts() from public;
grant execute on function pull_private.visible_community_counts() to anon,authenticated;
create function public.pull_community_counts() returns jsonb language sql security invoker set search_path='' as $$select pull_private.visible_community_counts();$$;
revoke all on function public.pull_community_counts() from public;
grant execute on function public.pull_community_counts() to anon,authenticated;
create or replace function pull_private.public_rarity_statistics() returns jsonb language plpgsql security definer set search_path='' as $$
declare totals jsonb;visible_counts boolean;
begin
 totals:=pull_private.community_counts();
 visible_counts:=coalesce((select show_public_counts from pull_private.settings where id=true),false) or exists(select 1 from pull_private.profiles where id=auth.uid() and status='approved' and role='admin');
 return pull_private.rarity_statistics(totals->'counts',visible_counts);
end $$;
