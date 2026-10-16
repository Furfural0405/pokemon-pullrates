create function pull_private.chat_history_operation(operation text,payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
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
 if operation='view' then
  return jsonb_build_object('conversation',to_jsonb(c),'peer',jsonb_build_object('user_id',target.id,'username',target.username,'public_bundle',(select public_bundle from pull_private.chat_identities where user_id=target.id),'key_id',(select key_id from pull_private.chat_identities where user_id=target.id)),
   'messages',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('read',x.sender=me.id and x.seq<=(select read_seq from pull_private.chat_members where conversation_id=c.id and user_id=other_id)) order by x.seq),'[]') from (select * from pull_private.chat_messages where conversation_id=c.id and seq>(select hidden_before from pull_private.chat_members where conversation_id=c.id and user_id=me.id) and seq>coalesce((payload->>'after_seq')::bigint,0) order by seq limit 100) x));
 end if;
 if operation='read' then
  select coalesce(max(seq),0) into n from pull_private.chat_messages where conversation_id=c.id;
  update pull_private.chat_members set read_seq=greatest(read_seq,least(n,greatest(0,(payload->>'seq')::bigint))) where conversation_id=c.id and user_id=me.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation='delete' then
  update pull_private.chat_members set archived=true,hidden_before=(select coalesce(max(seq),hidden_before) from pull_private.chat_messages where conversation_id=c.id) where conversation_id=c.id and user_id=me.id;
  return jsonb_build_object('ok',true);
 end if;
 if operation in ('block','unblock') then
  if operation='block' then insert into pull_private.chat_blocks(blocker,blocked) values(me.id,other_id) on conflict do nothing;else delete from pull_private.chat_blocks where blocker=me.id and blocked=other_id;end if;
  return jsonb_build_object('ok',true);
 end if;
 if operation='report-prepare' then
  if payload->'confirmed' is distinct from 'true'::jsonb then raise exception 'REPORT_CONFIRMATION_REQUIRED';end if;
  if (select count(*) from pull_private.chat_reports where reporter=me.id and created_at>now()-interval '1 day')>=10 then raise exception 'REPORT_LIMIT';end if;
  select coalesce(jsonb_agg(to_jsonb(m)||jsonb_build_object('sender_public',i.public_bundle,'sender_username',p.username) order by m.seq),'[]') into result from pull_private.chat_messages m join pull_private.chat_identities i on i.user_id=m.sender join pull_private.profiles p on p.id=m.sender where m.conversation_id=c.id;
  if jsonb_array_length(result)=0 then raise exception 'NO_MESSAGES_TO_REPORT';end if;
  if pg_column_size(result)>15000000 then raise exception 'REPORT_TOO_LARGE';end if;
  insert into pull_private.chat_reports(conversation_id,reporter,evidence,admin_key_id,reporter_public) values(c.id,me.id,result,(select key_id from pull_private.chat_identities where user_id=admin_id),(select public_bundle from pull_private.chat_identities where user_id=me.id)) returning * into report;
  return to_jsonb(report);
 end if;
 if operation='report-submit' then
  select * into report from pull_private.chat_reports where id=(payload->>'report_id')::uuid and reporter=me.id and conversation_id=c.id and status='draft';if not found then raise exception 'REPORT_NOT_FOUND';end if;
  if payload->'confirmed' is distinct from 'true'::jsonb or (payload->>'message_count')::int is distinct from jsonb_array_length(report.evidence) or payload->'packet'->'context'->>'report_id' is distinct from report.id::text or payload->'packet'->'context'->>'sender' is distinct from me.id::text or payload->'packet'->'wraps'->admin_id::text->>'key_id' is distinct from report.admin_key_id or pg_column_size(payload)>2000000 then raise exception 'INVALID_REPORT';end if;
  update pull_private.chat_reports set encrypted_packet=payload->'packet',status='open' where id=report.id;
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.chat_history_operation(text,jsonb) from public,anon,authenticated;
