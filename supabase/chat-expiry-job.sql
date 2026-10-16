create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('pullrates-chat-expiry','* * * * *',$job$select pull_private.chat_purge();$job$);
