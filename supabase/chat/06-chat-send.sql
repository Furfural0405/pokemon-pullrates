create function pull_private.chat_send_operation(operation text,payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; c pull_private.chat_conversations; rule pull_private.chat_rules; d pull_private.chat_devices; identity pull_private.chat_identities; report pull_private.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from pull_private.profiles where id=auth.uid();
 select * into rule from pull_private.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 select * into c from pull_private.chat_conversations where id=(payload->>'conversation_id')::uuid and (a=me.id or b=me.id) for update;
 if not found then raise exception 'CONVERSATION_NOT_FOUND';end if;
 other_id:=case when c.a=me.id then c.b else c.a end;
 select * into target from pull_private.profiles where id=other_id;
 is_blocked:=exists(select 1 from pull_private.chat_blocks where (blocker=me.id and blocked=other_id) or (blocker=other_id and blocked=me.id));
 if exists(select 1 from pull_private.chat_bans where user_id in (me.id,other_id)) or target.status<>'approved' or target.username is null or target.username_blocked then raise exception 'CHAT_SUSPENDED';end if;
 if is_blocked then raise exception 'CHAT_BLOCKED';end if;
 if operation='respond' then
  if c.status<>'pending' or c.inviter=me.id or payload->>'response' not in ('accepted','rejected') then raise exception 'INVALID_REQUEST';end if;
  update pull_private.chat_conversations set status=payload->>'response',version=version+1,updated_at=now() where id=c.id;
  return jsonb_build_object('ok',true);
 end if;
 if c.status<>'accepted' then raise exception 'REQUEST_NOT_ACCEPTED';end if;
 if operation in ('retention-propose','retention-respond') then
  if (payload->>'version')::integer is distinct from c.version then raise exception 'VERSION_CONFLICT';end if;
  if operation='retention-propose' then
   ttl_value:=(payload->>'ttl')::int;if ttl_value not in (0,86400,604800,2592000,7776000) or ttl_value is null then raise exception 'INVALID_RETENTION';end if;
   update pull_private.chat_conversations set proposed_ttl=ttl_value,proposer=me.id,version=version+1 where id=c.id;
  else
   if c.proposer is null or c.proposer=me.id or jsonb_typeof(payload->'accept') is distinct from 'boolean' then raise exception 'INVALID_RETENTION';end if;
   update pull_private.chat_conversations set ttl=case when (payload->>'accept')::boolean then proposed_ttl else ttl end,proposed_ttl=null,proposer=null,version=version+1 where id=c.id;
  end if;
  return jsonb_build_object('ok',true);
 end if;
 if operation='send' then
  if (select count(*) from pull_private.chat_messages where sender=me.id and sent_at>now()-interval '1 minute')>=30 then raise exception 'MESSAGE_LIMIT';end if;
  v_id:=(payload->>'id')::uuid;
  if pg_column_size(payload)>24000 or payload->'envelope'->>'v' is distinct from '1' or payload->'envelope'->'context'->>'type' is distinct from 'message' or payload->'envelope'->'context'->>'id' is distinct from v_id::text or payload->'envelope'->'context'->>'conversation_id' is distinct from c.id::text or payload->'envelope'->'context'->>'sender' is distinct from me.id::text or payload->'envelope'->>'signature' is null or payload->'envelope'->'body'->>'data' is null then raise exception 'INVALID_MESSAGE';end if;
  if (select count(*) from jsonb_object_keys(payload->'envelope'->'wraps'))<>2 or payload->'envelope'->'wraps'->me.id::text->>'key_id' is distinct from (select key_id from pull_private.chat_identities where user_id=me.id) or payload->'envelope'->'wraps'->other_id::text->>'key_id' is distinct from (select key_id from pull_private.chat_identities where user_id=other_id) then raise exception 'INVALID_MESSAGE_KEYS';end if;
  insert into pull_private.chat_messages(id,conversation_id,sender,envelope,expires_at) values(v_id,c.id,me.id,payload->'envelope',case when c.ttl=0 then null else clock_timestamp()+make_interval(secs=>c.ttl) end);
  update pull_private.chat_conversations set updated_at=now() where id=c.id;
  update pull_private.chat_members set archived=false where conversation_id=c.id;
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.chat_send_operation(text,jsonb) from public,anon,authenticated;
