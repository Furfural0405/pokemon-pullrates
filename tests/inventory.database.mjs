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
await db.exec(`create table public.card_details(card_id text primary key,rarity text);`);
await db.exec(await readFile('supabase/rarity-catalog.sql','utf8'));await db.exec(await readFile('supabase/rarity-statistics.sql','utf8'));

const beforeStock=(await db.query('select counts,version,snapshot from pull_private.lists order by id')).rows;
await db.exec(await readFile('supabase/inventory-system.sql','utf8'));
assert.deepEqual((await db.query('select counts,version,snapshot from pull_private.lists order by id')).rows,beforeStock);
const owner='e094b5d1-43f8-4342-b66b-6f76f8165c2d',a='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',b='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
await db.exec(`insert into auth.users(id,email,raw_user_meta_data) values('${a}','a@example.invalid','{"username":"Alice"}'),('${b}','b@example.invalid','{"username":"Bob"}');update pull_private.profiles set status='approved';`);
async function as(id){await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id])}
async function rpc(op,p={}){return(await db.query('select public.pull_lists($1,$2::jsonb) value',[op,JSON.stringify(p)])).rows[0].value}
async function inv(op,p){return(await db.query('select public.pull_inventory($1,$2::jsonb) value',[op,JSON.stringify(p)])).rows[0].value}
async function preview(source,target,ids=['061']){return(await db.query('select public.pull_trade_preview($1::jsonb) value',[JSON.stringify({source_id:source,target_id:target,card_ids:ids})])).rows[0].value}
async function copy(p){return(await db.query('select public.pull_copy_to_trade($1::jsonb) value',[JSON.stringify(p)])).rows[0].value}
let seq=0;async function save(d,patch={}){return inv('save',{list_id:d.list.id,version:d.list.version,revision:d.revision,counts:d.list.counts,new_pulls:{},master:d.master,binder:d.binder,given:d.given,request_id:'11111111-1111-4111-8111-'+String(++seq).padStart(12,'0'),...patch})}
await as(a);let list=(await rpc('me')).lists[0];let d=await inv('get',{list_id:list.id});assert.equal(d.master_sets,0);assert.deepEqual(d.master,{});
d=await save(d,{counts:{'061':20},master:{'061':4}});assert.equal(d.available['061'],16);
const ratesBeforeStock=(await db.query('select rates from public.pull_rates')).rows;
d=await save(d,{given:{'061':3}});assert.equal(d.available['061'],13);assert.deepEqual((await db.query('select rates from public.pull_rates')).rows,ratesBeforeStock);
const payload={list_id:list.id,version:d.list.version,revision:d.revision,counts:d.list.counts,new_pulls:{'061':5},master:d.master,binder:d.binder,given:d.given,request_id:'22222222-2222-4222-8222-222222222222'};
d=await inv('save',payload);assert.equal(d.list.counts['061'],25);assert.equal(d.available['061'],18);await inv('save',payload);assert.equal((await inv('get',{list_id:list.id})).list.counts['061'],25);await assert.rejects(()=>inv('save',{...payload,new_pulls:{'061':6}}),/REQUEST_REUSED/);
await assert.rejects(()=>save(d,{binder:{'061':19}}),/STOCK_EXCEEDS_TOTAL/);assert.equal((await inv('get',{list_id:list.id})).available['061'],18);
await assert.rejects(()=>save(d,{new_pulls:{'061':1000000}}));
let trade=await rpc('create',{name:'Angebot',purpose:'trade'});trade=await rpc('save',{list_id:trade.id,version:trade.version,counts:{'061':13,'062':7}});
let p=await preview(list.id,trade.id);assert.equal(p.cards['061'].available,18);trade=await copy({...p,counts:{'061':18}});assert.equal(trade.counts['061'],18);assert.equal(trade.counts['062'],7);assert.equal((await inv('get',{list_id:list.id})).available['061'],18);
p=await preview(list.id,trade.id);trade=await copy({...p,counts:{'061':18}});assert.equal(trade.counts['061'],18);
p=await preview(list.id,trade.id);d=await save(d,{given:{'061':4}});await assert.rejects(()=>copy({...p,counts:{'061':18}}),/VERSION_CONFLICT/);p=await preview(list.id,trade.id);assert.equal(p.cards['061'].available,17);await assert.rejects(()=>copy({...p,counts:{'061':18}}),/OFFER_EXCEEDS_AVAILABLE/);await assert.rejects(()=>copy({...p,protocol:2,counts:{'061':17}}),/TRANSFER_PREVIEW_REQUIRED/);
// Public users and admin retain old pull views but cannot access private fields.
list=await rpc('settings',{...d.list,list_id:list.id,visibility:'public',display:'all'});d=await inv('get',{list_id:list.id});
for(const viewer of [b,owner]){await as(viewer);await assert.rejects(()=>inv('get',{list_id:list.id}),/OWN_PULL_LIST_REQUIRED/);const v=await rpc('view',{list_id:list.id});assert.equal(v.counts['061'],25);for(const key of ['master','binder','given','available','inventory'])assert.ok(!Object.hasOwn(v,key));if(viewer===owner){for(const l of await rpc('admin-lists'))assert.ok(!Object.hasOwn(l,'binder'));assert.ok(!JSON.stringify(await rpc('export-all')).includes('"master"'));}}
await db.exec('set role authenticated');await assert.rejects(()=>db.query('select * from pull_private.inventory'));await assert.rejects(()=>db.query("select pull_private.stock_result($1::uuid)",[list.id]));await db.exec('reset role');await as('');await db.exec('set role anon');await assert.rejects(()=>inv('get',{list_id:list.id}));await db.exec('reset role');
await as(a);await assert.rejects(()=>rpc('save',{list_id:list.id,version:d.list.version,counts:{'061':1}}),/STOCK_EXCEEDS_TOTAL/);
const required=cards.filter(c=>!c.id.startsWith('mew-rgb-'));const full=Object.fromEntries(required.map(c=>[c.id,2]));const binder=Object.fromEntries(required.map(c=>[c.id,1]));
d=await save(d,{counts:full,master:{},binder,given:{}});assert.equal(d.binder_sets,1);assert.equal(d.master_sets,0);assert.equal(d.previous_binder_sets,0);
const originalVersion=d.list.version;d=await inv('master',{list_id:list.id,version:d.list.version,revision:d.revision,delta:1});assert.equal(d.applied,true);assert.equal(d.master_sets,1);assert.equal(d.binder_sets,1);assert.equal(d.list.version,originalVersion);assert.equal(d.master['mew-rgb-r'],undefined);assert.equal(d.available['001'],0);
const beforeFailed=await inv('get',{list_id:list.id});const missing=await inv('master',{list_id:list.id,version:d.list.version,revision:d.revision,delta:1});assert.equal(missing.applied,false);assert.equal(missing.missing.length,173);assert.deepEqual(await inv('get',{list_id:list.id}),beforeFailed);
await assert.rejects(()=>rpc('settings',{...d.list,list_id:list.id,purpose:'trade'}),/CLEAR_STOCK_BEFORE_PURPOSE_CHANGE/);
d=await inv('master',{list_id:list.id,version:d.list.version,revision:d.revision,delta:-1});assert.equal(d.master_sets,0);assert.equal(d.binder_sets,1);assert.equal(d.available['001'],1);
const oldVersion=d.list.version;d=await save(d,{binder:{...binder,'energy-water':0}});assert.equal(d.binder_sets,0);assert.equal(d.list.version,oldVersion);
d=await save(d,{binder:{...binder}});assert.equal(d.binder_sets,1);assert.equal(d.previous_binder_sets,0);
// One missing energy cancels the entire bulk action and RGB never affects completion.
d=await save(d,{given:{'energy-water':1}});const failed=await inv('master',{list_id:list.id,version:d.list.version,revision:d.revision,delta:1});assert.equal(failed.applied,false);assert.deepEqual(failed.missing,[{card_id:'energy-water',missing:1}]);assert.equal((await inv('get',{list_id:list.id})).master_sets,0);
console.log('Inventory database passed: migration preservation, atomic/idempotent additions, private allocations, independent binders/sets, RGB exclusion, all-or-nothing bulk, stale checks, available-only transfers, legacy save guards and admin/public non-disclosure.');await db.close();
