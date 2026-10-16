create function pull_private.chat_identity_operation(operation text,payload jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare me pull_private.profiles; target pull_private.profiles; c pull_private.chat_conversations; rule pull_private.chat_rules; d pull_private.chat_devices; identity pull_private.chat_identities; report pull_private.chat_reports; result jsonb; other_id uuid; v_id uuid; ttl_value int; own_admin boolean; is_blocked boolean; n bigint; admin_id constant uuid:='e094b5d1-43f8-4342-b66b-6f76f8165c2d';
begin
 select * into me from pull_private.profiles where id=auth.uid();
 select * into rule from pull_private.chat_rules where active;
 own_admin:=me.id=admin_id and me.role='admin';
 if operation='identity-create' then
  if exists(select 1 from pull_private.chat_identities where user_id=me.id) then raise exception 'IDENTITY_EXISTS';end if;
  if pg_column_size(payload)>20000 or payload->'public_bundle'->>'v' is distinct from '1' or not(payload->'public_bundle' ? 'enc') or not(payload->'public_bundle' ? 'sig') or (payload->'public_bundle'->'enc') ? 'd' or (payload->'public_bundle'->'sig') ? 'd' or char_length(payload->>'key_id')<>43 or payload->'encrypted_vault'->>'iv' is null or payload->'encrypted_vault'->>'data' is null then raise exception 'INVALID_KEY';end if;
  insert into pull_private.chat_identities(user_id,public_bundle,key_id,encrypted_vault) values(me.id,payload->'public_bundle',payload->>'key_id',payload->'encrypted_vault');
  return jsonb_build_object('ok',true);
 end if;
 if operation='device-request' then
  if (select count(*) from pull_private.chat_devices where owner_id=me.id and status<>'revoked')>=20 then raise exception 'DEVICE_LIMIT';end if;
  if pg_column_size(payload)>6000 or payload->'public_key'->>'kty' is distinct from 'EC' or (payload->'public_key') ? 'd' then raise exception 'INVALID_KEY';end if;
  insert into pull_private.chat_devices(id,owner_id,label,public_key,status) values((payload->>'id')::uuid,me.id,left(coalesce(nullif(btrim(payload->>'label'),''),'Browser'),80),payload->'public_key','pending');return jsonb_build_object('ok',true);
 end if;
 if operation in ('device-approve','device-revoke') then
  select * into d from pull_private.chat_devices where id=(payload->>'id')::uuid and owner_id=me.id for update;if not found then raise exception 'DEVICE_NOT_FOUND';end if;
  if operation='device-revoke' then if d.status<>'pending' then raise exception 'DEVICE_ALREADY_APPROVED';end if;update pull_private.chat_devices set status='revoked',encrypted_grant=null where id=d.id;
  else
   if d.status<>'pending' or pg_column_size(payload)>10000 or payload->'grant'->>'data' is null then raise exception 'INVALID_DEVICE_GRANT';end if;
   update pull_private.chat_devices set status='approved',approved_at=now(),encrypted_grant=payload->'grant' where id=d.id;
  end if;
  return jsonb_build_object('ok',true);
 end if;
 raise exception 'UNKNOWN_OPERATION';
end $$;
revoke all on function pull_private.chat_identity_operation(text,jsonb) from public,anon,authenticated;
