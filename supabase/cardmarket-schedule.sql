-- Apply after cardmarket-values.sql and deploy cardmarket-refresh.
create extension if not exists pg_net with schema extensions;
do $$
declare token text;
begin
 if not exists(select 1 from vault.secrets where name='pullrates_market_worker_token') then
  token:=encode(extensions.gen_random_bytes(32),'hex');
  perform vault.create_secret(token,'pullrates_market_worker_token','Private token for 30-minute Cardmarket refresh');
 else
  select decrypted_secret into token from vault.decrypted_secrets where name='pullrates_market_worker_token';
 end if;
 insert into pull_private.market_worker_state(id,token_hash) values(true,encode(extensions.digest(token,'sha256'),'hex')) on conflict(id) do nothing;
end $$;
select cron.schedule('pullrates-cardmarket-refresh','*/30 * * * *',$job$
 select net.http_post(url:='https://tmsekorkrnglnfvhudyf.supabase.co/functions/v1/cardmarket-refresh',headers:=jsonb_build_object('Content-Type','application/json','x-price-worker-token',(select decrypted_secret from vault.decrypted_secrets where name='pullrates_market_worker_token')),body:='{}'::jsonb,timeout_milliseconds:=120000);
$job$);
