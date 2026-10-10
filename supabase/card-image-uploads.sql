create table public.card_images (
 card_id text primary key references pull_private.cards(id),
 path text not null check (split_part(path,'/',1)=card_id and path ~ '^[a-z0-9-]+/[0-9a-f-]+\.webp$'),
 updated_at timestamptz not null default now()
);
alter table public.card_images enable row level security;
revoke all on public.card_images from anon,authenticated;
grant select on public.card_images to anon,authenticated;
grant insert,update on public.card_images to authenticated;
create policy card_images_read on public.card_images for select to anon,authenticated using(true);
create policy card_images_owner_insert on public.card_images for insert to authenticated with check ((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid);
create policy card_images_owner_update on public.card_images for update to authenticated using ((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid) with check ((select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('card-images','card-images',true,5242880,array['image/webp']);
create policy card_image_storage_owner_insert on storage.objects for insert to authenticated with check (bucket_id='card-images' and (select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid and name ~ '^[a-z0-9-]+/[0-9a-f-]+\.webp$');
create policy card_image_storage_owner_read on storage.objects for select to authenticated using (bucket_id='card-images' and (select auth.uid())='e094b5d1-43f8-4342-b66b-6f76f8165c2d'::uuid);
alter publication supabase_realtime add table public.card_images;
