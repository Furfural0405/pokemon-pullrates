-- Combined reference. Apply the numbered files in supabase/chat in order.
create table pull_private.chat_rules(version text primary key,body text not null,active boolean not null default true);
create unique index chat_one_active_rules on pull_private.chat_rules(active) where active;
-- Rule body is inserted below by the build script; prior versions remain immutable.
create table pull_private.chat_consents(user_id uuid not null references pull_private.profiles(id),version text not null references pull_private.chat_rules(version),accepted_at timestamptz not null default clock_timestamp(),primary key(user_id,version));
create table pull_private.chat_identities(user_id uuid primary key references pull_private.profiles(id),public_bundle jsonb not null,key_id text not null,encrypted_vault jsonb not null,created_at timestamptz not null default now());
create table pull_private.chat_devices(id uuid primary key,owner_id uuid not null references pull_private.profiles(id),label text not null check(char_length(label) between 1 and 80),public_key jsonb not null,status text not null check(status in ('pending','approved','revoked')),encrypted_grant jsonb,created_at timestamptz not null default now(),approved_at timestamptz);
create index chat_device_owner on pull_private.chat_devices(owner_id);
create table pull_private.chat_conversations(id uuid primary key default gen_random_uuid(),a uuid not null references pull_private.profiles(id),b uuid not null references pull_private.profiles(id),inviter uuid not null references pull_private.profiles(id),status text not null default 'pending' check(status in ('pending','accepted','rejected')),ttl integer not null default 0 check(ttl in (0,86400,604800,2592000,7776000)),proposed_ttl integer check(proposed_ttl in (0,86400,604800,2592000,7776000)),proposer uuid,version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(a,b),check(a<b),check(inviter in (a,b)),check(proposer is null or proposer in (a,b)));
create index chat_conversation_b on pull_private.chat_conversations(b);
create table pull_private.chat_members(conversation_id uuid not null references pull_private.chat_conversations(id) on delete cascade,user_id uuid not null references pull_private.profiles(id),hidden_before bigint not null default 0,archived boolean not null default false,read_seq bigint not null default 0,primary key(conversation_id,user_id));
create table pull_private.chat_messages(id uuid primary key,seq bigint generated always as identity unique,conversation_id uuid not null references pull_private.chat_conversations(id),sender uuid not null references pull_private.profiles(id),envelope jsonb not null,sent_at timestamptz not null default clock_timestamp(),expires_at timestamptz);
create index chat_message_conversation on pull_private.chat_messages(conversation_id,seq);
create index chat_message_expiry on pull_private.chat_messages(expires_at) where expires_at is not null;
create table pull_private.chat_blocks(blocker uuid not null references pull_private.profiles(id),blocked uuid not null references pull_private.profiles(id),primary key(blocker,blocked),check(blocker<>blocked));
create table pull_private.chat_bans(user_id uuid primary key references pull_private.profiles(id),reason text not null,created_at timestamptz not null default now());
create table pull_private.chat_reports(id uuid primary key default gen_random_uuid(),conversation_id uuid not null references pull_private.chat_conversations(id),reporter uuid not null references pull_private.profiles(id),evidence jsonb not null,encrypted_packet jsonb,admin_key_id text not null,reporter_public jsonb not null,status text not null default 'draft' check(status in ('draft','open','closed')),created_at timestamptz not null default clock_timestamp());
create index chat_report_status on pull_private.chat_reports(status,created_at);
do $$declare t text;begin foreach t in array array['chat_rules','chat_consents','chat_identities','chat_devices','chat_conversations','chat_members','chat_messages','chat_blocks','chat_bans','chat_reports'] loop execute format('alter table pull_private.%I enable row level security',t);execute format('revoke all on pull_private.%I from public,anon,authenticated',t);end loop;end $$;

create function pull_private.chat_purge() returns void language sql set search_path='' as $$
 delete from pull_private.chat_messages where expires_at is not null and expires_at<=clock_timestamp();
 delete from pull_private.chat_reports where status='draft' and created_at<now()-interval '1 day';
$$;
revoke all on function pull_private.chat_purge() from public,anon,authenticated;


insert into pull_private.chat_rules(version,body) values('2026-10-16-v1',$rules$Chatregeln und Hinweise zur Nutzung

1. Respektvoll miteinander umgehen
Behandle andere freundlich und respektvoll. Beleidigungen, Belästigung, Drohungen, Diskriminierung sowie rassistische, antisemitische oder extremistische Inhalte sind untersagt. Respektiere abgelehnte Kontaktanfragen und Blockierungen. Umgehe sie nicht über andere Konten.

2. Ehrlich bleiben
Täusche andere nicht über deine Identität, Karten oder Absichten. Betrugsversuche, gefälschte Nachweise und das Vortäuschen einer Admin-Zugehörigkeit sind verboten.

3. Kontaktaufnahme statt Verkaufsabwicklung
Der Chat ist ausschließlich zur Kontaktaufnahme vorgesehen. Tauschgeschäfte, Verkäufe, Zahlungen und Versandabsprachen sollen außerhalb dieser Webseite stattfinden. Der Betreiber vermittelt oder garantiert keine Geschäfte und bietet keinen Käuferschutz.

4. Privatsphäre schützen
Veröffentliche keine persönlichen Daten anderer Personen ohne deren Zustimmung. Frage niemals nach Passwörtern, Wiederherstellungsschlüsseln oder Zahlungszugängen. Überlege sorgfältig, welche eigenen Daten du weitergibst. Spam, unerwünschte Massenanfragen, Schadsoftware und täuschende Links sind verboten.

5. Verschlüsselung und Meldungen verstehen
Die Nachrichten sind Ende-zu-Ende-verschlüsselt. Der Admin hat keinen allgemeinen Zugriff auf ihre Inhalte. Technische Angaben, etwa beteiligte Konten und Versandzeitpunkte, können für den Betrieb verarbeitet werden.
Jeder Teilnehmer kann eine Unterhaltung melden. Nach einer zusätzlichen ausdrücklichen Bestätigung wird der vollständige noch verfügbare Chatverlauf bis zur Meldung einschließlich der eigenen Nachrichten als Meldungskopie an den Admin übermittelt. Spätere Nachrichten werden nicht automatisch hinzugefügt. Melde nur tatsächliche oder begründet vermutete Verstöße. Absichtlich falsche Meldungen sind untersagt.

6. Aufbewahrung und Löschung beachten
Standardmäßig werden Nachrichten nicht automatisch gelöscht. Eine automatische Löschung nach 24 Stunden, 7, 30 oder 90 Tagen kann für jede Unterhaltung vereinbart werden. Änderungen benötigen die Zustimmung beider Teilnehmer und gelten für neue Nachrichten. Die Frist beginnt beim Versenden.
Bereits gelöschte Nachrichten können nicht mehr gemeldet werden. Zuvor eingereichte Meldungskopien bleiben für die Prüfung erhalten. Das Löschen eines Chats entfernt ihn nur aus deiner eigenen Ansicht. Screenshots oder andere Kopien beim Empfänger werden dadurch nicht gelöscht.
Lesebestätigungen zeigen ausschließlich „Gelesen“, ohne Lesezeitpunkt.

7. Verstöße haben Folgen
Der Admin prüft Meldungen und kann bei Verstößen verwarnen, Chatfunktionen einschränken oder Konten sperren. Blockiere andere Nutzer, wenn du keinen weiteren Kontakt möchtest.$rules$);

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

