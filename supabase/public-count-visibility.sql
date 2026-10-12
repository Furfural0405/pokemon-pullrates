alter table pull_private.settings add column show_public_counts boolean not null default false;
create function pull_private.community_counts() returns jsonb language sql set search_path='' as $$
 with effective as (
 select case when role='admin' then counts else snapshot end counts from pull_private.profiles
 where status='approved' and (role='admin' or snapshot is not null)
 ), totals as (
 select c.id,c.booster_slot,coalesce(sum(coalesce((e.counts->>c.id)::numeric,0)),0) n
 from pull_private.cards c left join effective e on true group by c.id,c.booster_slot
 ) select jsonb_build_object('counts',jsonb_object_agg(id,n),'boosters',coalesce(sum(n) filter(where booster_slot),0)) from totals;
$$;
revoke all on function pull_private.community_counts() from public,anon,authenticated;
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('pull_private.application(text,jsonb)'::regprocedure);
 definition:=replace(definition, E'begin\n if auth.uid() is null', E'begin\n if operation=''public-counts'' then\n  select to_jsonb(show_public_counts) into result from pull_private.settings where id=true;\n  if result=''true''::jsonb or exists(select 1 from pull_private.profiles where id=auth.uid() and role=''admin'' and status=''approved'') then\n   return pull_private.community_counts() || jsonb_build_object(''enabled'',result);\n  end if;\n  return jsonb_build_object(''enabled'',false,''counts'',null,''boosters'',null);\n end if;\n if auth.uid() is null');
 definition:=replace(definition, E' if operation=''users'' then', E' if operation=''set-count-visibility'' then\n  if me.id<>''e094b5d1-43f8-4342-b66b-6f76f8165c2d''::uuid then raise exception ''ADMIN_REQUIRED''; end if;\n  if jsonb_typeof(payload->''enabled'') is distinct from ''boolean'' then raise exception ''INVALID_SETTING''; end if;\n  update pull_private.settings set show_public_counts=(payload->>''enabled'')::boolean where id=true;\n  return jsonb_build_object(''ok'',true);\n end if;\n if operation=''users'' then');
 execute definition;
end $migration$;
