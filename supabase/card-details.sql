create table public.card_details (
 card_id text primary key references pull_private.cards(id),
 name text not null check(char_length(btrim(name)) between 1 and 100),
 rarity text not null check(rarity in ('Common','Rare','Double Rare','Pikachu Rare','Art Rare','Special Art Rare','Futuristic Rare','Reprint','RGB')),
 updated_at timestamptz not null default now()
);
alter table public.card_details enable row level security;
revoke all on public.card_details from anon,authenticated;
grant select on public.card_details to anon,authenticated;
grant insert,update on public.card_details to authenticated;
create policy card_details_read on public.card_details for select to anon,authenticated using (true);
create policy card_details_owner_insert on public.card_details for insert to authenticated with check ((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid);
create policy card_details_owner_update on public.card_details for update to authenticated using ((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid) with check ((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid);
alter publication supabase_realtime add table public.card_details;
