create function pull_private.chat_admin_operation(operation text,payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; c pull_private.chat_conversations; rule pull_private.chat_rules; d pull_private.chat_devices; identity pull_private.chat_identities; report pull_private.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from pull_private.profiles where id=auth.uid();
 select * into rule from pull_private.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 if operation='admin-consents' then
  if not own_admin then raise exception 'ADMIN_REQUIRED';end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('user_id',p.id,'username',p.username,'email',p.email,'version',a.version,'accepted_at',a.accepted_at) order by a.accepted_at desc),'[]') from pull_private.chat_consents a join pull_private.profiles p on p.id=a.user_id);
 end if;
 if operation='admin-reports' then
  if not own_admin then raise exception 'ADMIN_REQUIRED';end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'reporter',p.username,'created_at',r.created_at,'status',r.status,'message_count',jsonb_array_length(r.evidence)) order by r.created_at desc),'[]') from pull_private.chat_reports r join pull_private.profiles p on p.id=r.reporter where r.status<>'draft');
 end if;
 if operation in ('admin-report','close-report','suspend') then
  if not own_admin then raise exception 'ADMIN_REQUIRED';end if;
  if operation='suspend' then
   if (payload->>'user_id')::uuid=me.id then raise exception 'ADMIN_PROTECTED';end if;
   if coalesce((payload->>'suspended')::boolean,false) then insert into pull_private.chat_bans(user_id,reason) values((payload->>'user_id')::uuid,left(coalesce(payload->>'reason','Verstoß gegen Chatregeln'),500)) on conflict(user_id) do update set reason=excluded.reason;else delete from pull_private.chat_bans where user_id=(payload->>'user_id')::uuid;end if;
   return jsonb_build_object('ok',true);
  end if;
  select * into report from pull_private.chat_reports where id=(payload->>'report_id')::uuid and status<>'draft';if not found then raise exception 'REPORT_NOT_FOUND';end if;
  if operation='close-report' then update pull_private.chat_reports set status='closed' where id=report.id;return jsonb_build_object('ok',true);end if;
  return to_jsonb(report);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.chat_admin_operation(text,jsonb) from public,anon,authenticated;
