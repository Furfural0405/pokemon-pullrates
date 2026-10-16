create function pull_private.chat_application(operation text,payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; c pull_private.chat_conversations; rule pull_private.chat_rules; d pull_private.chat_devices; identity pull_private.chat_identities; report pull_private.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 -- Serialize chat changes; prevents request, report-snapshot and retention races.
 perform pg_advisory_xact_lock(3046104);
 select * into me from pull_private.profiles where id=auth.uid();
 if not found or me.status<>'approved' then raise exception 'CHAT_REQUIRES_APPROVAL';end if;
 own_admin:=me.id=admin_id and me.role='admin';
 select * into rule from pull_private.chat_rules where active;
 if not found then raise exception 'CHAT_NOT_CONFIGURED';end if;
 perform pull_private.chat_purge();
 if operation in ('admin-consents','admin-reports','admin-report','close-report','suspend') then return pull_private.chat_admin_operation(operation,payload);end if;
 if operation='state' then
  return jsonb_build_object('user_id',me.id,'username',me.username,'rule',to_jsonb(rule),'accepted',exists(select 1 from pull_private.chat_consents where user_id=me.id and version=rule.version),
   'banned',exists(select 1 from pull_private.chat_bans where user_id=me.id),'can_chat',me.username is not null and not me.username_blocked,
   'identity',(select to_jsonb(i) from pull_private.chat_identities i where user_id=me.id),
   'devices',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]') from pull_private.chat_devices x where owner_id=me.id),
   'admin_identity',(select jsonb_build_object('user_id',user_id,'public_bundle',public_bundle,'key_id',key_id) from pull_private.chat_identities where user_id=admin_id));
 end if;
 if me.username is null or me.username_blocked then raise exception 'CHAT_REQUIRES_USERNAME';end if;
 if operation='accept-rules' then
  if payload->>'version' is distinct from rule.version or payload->'confirmed' is distinct from 'true'::jsonb then raise exception 'RULE_CONFIRMATION_REQUIRED';end if;
  insert into pull_private.chat_consents(user_id,version) values(me.id,rule.version) on conflict do nothing;
  return (select to_jsonb(a) from pull_private.chat_consents a where user_id=me.id and version=rule.version);
 end if;
 if not exists(select 1 from pull_private.chat_consents where user_id=me.id and version=rule.version) then raise exception 'RULES_REQUIRED';end if;
 if operation in ('identity-create','device-request','device-approve','device-revoke') then return pull_private.chat_identity_operation(operation,payload);end if;
 if not exists(select 1 from pull_private.chat_identities where user_id=me.id) then raise exception 'IDENTITY_REQUIRED';end if;
 if not exists(select 1 from pull_private.chat_identities where user_id=admin_id) then raise exception 'ADMIN_KEY_REQUIRED';end if;
 if operation in ('conversations','request') then return pull_private.chat_contact_operation(operation,payload);end if;
 if operation in ('view','read','delete','block','unblock','report-prepare','report-submit') then return pull_private.chat_history_operation(operation,payload);end if;
 return pull_private.chat_send_operation(operation,payload);
end $$;
revoke all on function pull_private.chat_application(text,jsonb) from public,anon;
grant execute on function pull_private.chat_application(text,jsonb) to authenticated;
create function public.pull_chat(operation text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select pull_private.chat_application(operation,payload);$$;
revoke all on function public.pull_chat(text,jsonb) from public,anon;
grant execute on function public.pull_chat(text,jsonb) to authenticated;

