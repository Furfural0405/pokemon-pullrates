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
