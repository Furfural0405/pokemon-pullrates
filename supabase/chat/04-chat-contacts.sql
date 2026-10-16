create function pull_private.chat_contact_operation(operation text,payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; c pull_private.chat_conversations; rule pull_private.chat_rules; d pull_private.chat_devices; identity pull_private.chat_identities; report pull_private.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from pull_private.profiles where id=auth.uid();
 select * into rule from pull_private.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 if operation='conversations' then
  return (select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'status',x.status,'inviter',x.inviter,'ttl',x.ttl,'proposed_ttl',x.proposed_ttl,'proposer',x.proposer,'version',x.version,'peer_id',p.id,'username',p.username,'blocked',exists(select 1 from pull_private.chat_blocks where (blocker=me.id and blocked=p.id) or (blocker=p.id and blocked=me.id)),'blocked_by_me',exists(select 1 from pull_private.chat_blocks where blocker=me.id and blocked=p.id),'unread',exists(select 1 from pull_private.chat_messages where conversation_id=x.id and sender<>me.id and seq>m.read_seq and seq>m.hidden_before)) order by x.updated_at desc),'[]') from pull_private.chat_conversations x join pull_private.chat_members m on m.conversation_id=x.id and m.user_id=me.id join pull_private.profiles p on p.id=case when x.a=me.id then x.b else x.a end where not m.archived);
 end if;
 if operation='request' then
  if exists(select 1 from pull_private.chat_bans where user_id=me.id) then raise exception 'CHAT_SUSPENDED';end if;
  select * into target from pull_private.profiles where lower(username)=lower(btrim(payload->>'username')) and status='approved' and not username_blocked and id<>me.id;
  if not found or not exists(select 1 from pull_private.chat_identities where user_id=target.id) or not exists(select 1 from pull_private.chat_consents where user_id=target.id and version=rule.version) or exists(select 1 from pull_private.chat_bans where user_id=target.id) then raise exception 'CONTACT_UNAVAILABLE';end if;
  if exists(select 1 from pull_private.chat_blocks where (blocker=me.id and blocked=target.id) or (blocker=target.id and blocked=me.id)) then raise exception 'CONTACT_UNAVAILABLE';end if;
  if (select count(*) from pull_private.chat_conversations where inviter=me.id and created_at>now()-interval '1 day')>=10 then raise exception 'REQUEST_LIMIT';end if;
  select * into c from pull_private.chat_conversations where a=least(me.id,target.id) and b=greatest(me.id,target.id);
  if found then
   if c.status='rejected' then
    if c.inviter=me.id then raise exception 'CONTACT_UNAVAILABLE';end if;
    update pull_private.chat_conversations set status='pending',inviter=me.id,version=version+1,updated_at=now() where id=c.id returning * into c;
    update pull_private.chat_members set archived=false where conversation_id=c.id;
   end if;
   update pull_private.chat_members set archived=false where conversation_id=c.id and user_id=me.id;
   return to_jsonb(c);
  end if;
  insert into pull_private.chat_conversations(a,b,inviter) values(least(me.id,target.id),greatest(me.id,target.id),me.id) returning * into c;
  insert into pull_private.chat_members(conversation_id,user_id) values(c.id,me.id),(c.id,target.id);
  return to_jsonb(c);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.chat_contact_operation(text,jsonb) from public,anon,authenticated;
