import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec(`create role anon;create role authenticated;create schema auth;create schema pull_private;
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
create table pull_private.profiles(id uuid primary key references auth.users(id),email text,status text default 'pending',role text default 'user',counts jsonb default '{}',version int default 0,snapshot jsonb,snapshot_version int,updated_at timestamptz default now(),request_archived boolean default false);
create table pull_private.settings(id boolean primary key,admin_email text,show_public_counts boolean default false);
insert into pull_private.settings values(true,'owner@example.invalid',false);
create table pull_private.cards(id text primary key,booster_slot boolean);
create table pull_private.history(actor uuid,target uuid,action text,previous_state jsonb);
create table public.pull_rates(id int primary key,rates jsonb,updated_at timestamptz default now());
insert into public.pull_rates(id,rates) values(1,'{}');`);
const cards=JSON.parse(await readFile('cards.json','utf8'));
for(const c of cards)await db.query('insert into pull_private.cards values($1,$2)',[c.id,c.booster_slot]);
for(const f of JSON.parse(await readFile('tests/baseline-functions.json','utf8')))await db.exec(f.definition);
await db.exec(`create function public.pull_app(operation text,payload jsonb default '{}') returns jsonb language sql as $$select pull_private.application(operation,payload)$$;
create trigger register_user after insert on auth.users for each row execute function pull_private.register_user();
insert into auth.users(id,email) values('e094b5d1-43f8-4342-b66b-6f76f8165c2d','owner@example.invalid');
update pull_private.profiles set role='admin',status='approved',counts='{"017":10,"058":2}',version=4;
select pull_private.refresh_rates();`);
const before=(await db.query('select counts,version,snapshot from pull_private.profiles')).rows;
const ratesBefore=(await db.query('select rates from public.pull_rates')).rows;
await db.exec(await readFile('supabase/multiple-lists.sql','utf8'));
assert.deepEqual((await db.query('select counts,version,snapshot from pull_private.profiles')).rows,before);
await db.exec('select pull_private.refresh_rates()');
assert.deepEqual((await db.query('select rates from public.pull_rates')).rows,ratesBefore);
import {newIdentity,seal,open,unwrap,openWithKey,verify} from '../chat/crypto.js';
await db.exec(await readFile('supabase/encrypted-chat.sql','utf8'));
const owner='e094b5d1-43f8-4342-b66b-6f76f8165c2d',a='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',b='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',out='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
await db.exec(`update pull_private.profiles set username='Owner' where id='${owner}';insert into auth.users(id,email,raw_user_meta_data) values('${a}','a@example.invalid','{"username":"Alice"}'),('${b}','b@example.invalid','{"username":"Bob"}'),('${out}','out@example.invalid','{"username":"Other"}');update pull_private.profiles set status='approved';`);
async function as(id){await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id])}
async function rpc(op,p={}){return (await db.query('select public.pull_chat($1,$2::jsonb) value',[op,JSON.stringify(p)])).rows[0].value}
async function denied(op,p,text){await assert.rejects(()=>rpc(op,p),new RegExp(text))}
const keys={};for(const id of [owner,a,b,out]){await as(id);let s=await rpc('state');await denied('conversations',{},'RULES_REQUIRED');await denied('accept-rules',{version:s.rule.version,confirmed:false},'RULE_CONFIRMATION_REQUIRED');await rpc('accept-rules',{version:s.rule.version,confirmed:true});keys[id]=await newIdentity(id);await rpc('identity-create',{public_bundle:keys[id].publicBundle,key_id:keys[id].keyId,encrypted_vault:keys[id].vault});}
await as(a);await denied('admin-consents',{},'ADMIN_REQUIRED');const c=await rpc('request',{username:'Bob'});
const context={type:'message',id:crypto.randomUUID(),conversation_id:c.id,sender:a};const envelope=await seal({text:'Geheim für Alice und Bob'},{[a]:keys[a].publicBundle,[b]:keys[b].publicBundle},context,keys[a].material);
await denied('send',{conversation_id:c.id,id:context.id,envelope},'REQUEST_NOT_ACCEPTED');await denied('respond',{conversation_id:c.id,response:'accepted'},'INVALID_REQUEST');await as(b);await rpc('respond',{conversation_id:c.id,response:'accepted'});
await as(a);await rpc('send',{conversation_id:c.id,id:context.id,envelope});let v=await rpc('view',{conversation_id:c.id});assert.equal(v.messages[0].read,false);assert.ok(!JSON.stringify((await db.query('select * from pull_private.chat_messages')).rows).includes('Geheim'));
await as(out);await denied('view',{conversation_id:c.id},'CONVERSATION_NOT_FOUND');await as(owner);await denied('view',{conversation_id:c.id},'CONVERSATION_NOT_FOUND');const consents=await rpc('admin-consents');assert.equal(consents.length,4);assert.ok(consents[0].accepted_at);await rpc('accept-rules',{version:'2026-10-16-v1',confirmed:true});assert.deepEqual(await rpc('admin-consents'),consents);
await as(b);v=await rpc('view',{conversation_id:c.id});assert.equal((await open(v.messages[0].envelope,b,keys[b].material,keys[a].publicBundle,context)).text,'Geheim für Alice und Bob');await rpc('read',{conversation_id:c.id,seq:v.messages[0].seq});await as(a);v=await rpc('view',{conversation_id:c.id});assert.equal(v.messages[0].read,true);assert.ok(!Object.keys((await db.query('select * from pull_private.chat_members limit 1')).rows[0]).some(x=>/read.*at/.test(x)));
let conv=v.conversation;await rpc('retention-propose',{conversation_id:c.id,version:conv.version,ttl:86400});await denied('retention-respond',{conversation_id:c.id,version:conv.version+1,accept:true},'INVALID_RETENTION');await as(b);await rpc('retention-respond',{conversation_id:c.id,version:conv.version+1,accept:true});assert.equal((await rpc('view',{conversation_id:c.id})).conversation.ttl,86400);assert.equal((await db.query('select expires_at from pull_private.chat_messages')).rows[0].expires_at,null);
await rpc('delete',{conversation_id:c.id});assert.equal((await rpc('view',{conversation_id:c.id})).messages.length,0);assert.equal((await rpc('conversations')).length,0);await rpc('block',{conversation_id:c.id});await as(a);await denied('send',{conversation_id:c.id,id:crypto.randomUUID(),envelope},'CHAT_BLOCKED');await as(b);await rpc('unblock',{conversation_id:c.id});const second={...context,id:crypto.randomUUID(),sender:b};await rpc('send',{conversation_id:c.id,id:second.id,envelope:await seal({text:'Antwort'},{[a]:keys[a].publicBundle,[b]:keys[b].publicBundle},second,keys[b].material)});assert.ok((await db.query('select expires_at from pull_private.chat_messages where id=$1',[second.id])).rows[0].expires_at);
await denied('report-prepare',{conversation_id:c.id,confirmed:false},'REPORT_CONFIRMATION_REQUIRED');const report=await rpc('report-prepare',{conversation_id:c.id,confirmed:true});assert.equal(report.evidence.length,2);const messageKeys={};for(const m of report.evidence)messageKeys[m.id]=await unwrap(m.envelope,b,keys[b].material);const rc={type:'report',report_id:report.id,sender:b},packet=await seal({reason:'Beleidigung',keys:messageKeys},{[owner]:keys[owner].publicBundle},rc,keys[b].material);await rpc('report-submit',{conversation_id:c.id,report_id:report.id,confirmed:true,message_count:2,packet});
await as(a);await denied('admin-reports',{},'ADMIN_REQUIRED');await as(owner);assert.equal((await rpc('admin-reports')).length,1);const evidence=await rpc('admin-report',{report_id:report.id});const data=await open(evidence.encrypted_packet,owner,keys[owner].material,keys[b].publicBundle,rc);for(const m of evidence.evidence){await verify(m.envelope,m.sender_public,m.envelope.context);assert.ok((await openWithKey(m.envelope,data.keys[m.id])).text)}
await db.query("update pull_private.chat_messages set expires_at=now()-interval '1 hour'");await db.exec('select pull_private.chat_purge()');assert.equal(Number((await db.query('select count(*) from pull_private.chat_messages')).rows[0].count),0);assert.equal((await rpc('admin-report',{report_id:report.id})).evidence.length,2);await rpc('suspend',{user_id:a,suspended:true,reason:'Test'});await as(a);await denied('request',{username:'Other'},'CHAT_SUSPENDED');assert.deepEqual((await db.query('select counts,version,snapshot from pull_private.profiles where id=$1',[owner])).rows,before);
console.log('Chat database tests passed: consent history, contact approval, ciphertext only, admin/nonparticipant denial, read receipts without time, mutual retention, local deletion, blocking, encrypted full reports, expiry, bans, original values.');await db.close();
