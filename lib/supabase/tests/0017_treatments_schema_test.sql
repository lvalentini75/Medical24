-- Medical 24 — pgTAP 0017 treatments schema (P07-A1).
-- Solo progetto dev: tutto in transazione, rollback finale, nessun dato resta.
--
-- Copre: esistenza e RLS forzata delle sette tabelle del modulo Cure;
-- un utente estraneo che legge zero righe dalle cure draft e dalle recensioni
-- pending inserite come postgres, e che legge la cura published e la
-- recensione approved; l'autore che legge la propria recensione pending;
-- il divieto di scrittura diretta su treatments e reviews per authenticated;
-- i preferiti (insert e delete del proprietario, zero righe per un altro
-- utente); il trigger che rifiuta un tag fuori vocabolario; rating_summaries
-- aggiornato quando una recensione passa ad approved e quando torna withdrawn;
-- il registro della migrazione 0017.

begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

-- ---------------------------------------------------------------------------
-- Fixture (come postgres, prima di qualunque set local role)
--   U1 estraneo, U2 autore della recensione pending, U3 autore dell'approvata
-- ---------------------------------------------------------------------------
insert into auth.users(id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('a1111111-1111-4111-8111-111111111117','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','stranger17@example.com','',now(),'{}','{}',now(),now()),
 ('a2222222-2222-4222-8222-222222222217','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','author17a@example.com','',now(),'{}','{}',now(),now()),
 ('a3333333-3333-4333-8333-333333333317','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','author17b@example.com','',now(),'{}','{}',now(),now())
on conflict(id) do nothing;

insert into public.facilities(id, name, kind, verified)
values ('f1000000-0000-4000-8000-000000000017','Centro Prova 17','poliambulatorio',true)
on conflict(id) do nothing;

insert into public.doctors(id, display_name, role, verified, facility_id)
values ('d1000000-0000-4000-8000-000000000017','Dott. Prova 17','fisioterapista',true,
        'f1000000-0000-4000-8000-000000000017')
on conflict(id) do nothing;

insert into public.treatment_tags(tag, label_it, label_en, kind, sort_order) values
 ('fisioterapia','Fisioterapia','Physiotherapy','categoria',10),
 ('lombalgia','Lombalgia','Low back pain','patologia',20)
on conflict(tag) do nothing;

insert into public.treatments(id, title, summary, description_sections, family, scope,
  category, conditions, tags, evidence_level, modality, status, doctor_id, facility_id, published_at)
values
 ('c1000000-0000-4000-8000-000000000017','Rieducazione lombare','Percorso in palestra medica.',
  '{"per_chi":"Adulti con lombalgia cronica","come_funziona":"Esercizio terapeutico progressivo",
    "durata":"Otto settimane","rischi_e_controindicazioni":"Dolore acuto in fase iniziale",
    "evidenze_e_limiti":"Linee guida internazionali"}'::jsonb,
  'tradizionale','riabilitazione','Fisioterapia', array['lombalgia'], array['fisioterapia','lombalgia'],
  'linee_guida','presenza','published','d1000000-0000-4000-8000-000000000017',
  'f1000000-0000-4000-8000-000000000017', now()),
 ('c2000000-0000-4000-8000-000000000017','Protocollo in bozza','Scheda non ancora pubblicata.',
  '{"per_chi":"Da definire"}'::jsonb,
  'sperimentale','terapia','Fisioterapia', array['lombalgia'], array['fisioterapia'],
  'non_valutato','ibrido','draft', null, null, null)
on conflict(id) do nothing;

insert into public.reviews(id, author_id, target_type, target_id, rating, sub_ratings, title, body, status)
values
 ('e1000000-0000-4000-8000-000000000017','a3333333-3333-4333-8333-333333333317','treatment',
  'c1000000-0000-4000-8000-000000000017', 4, '{"ascolto":4,"struttura":4}'::jsonb,
  'Percorso utile','Il percorso e stato utile e ben spiegato dal personale.','approved'),
 ('e2000000-0000-4000-8000-000000000017','a2222222-2222-4222-8222-222222222217','treatment',
  'c1000000-0000-4000-8000-000000000017', 5, '{"ascolto":5,"struttura":5}'::jsonb,
  'In attesa','Recensione ancora in moderazione, scritta per il test di accesso.','pending')
on conflict(id) do nothing;

insert into public.favorites(user_id, target_type, target_id)
values ('a2222222-2222-4222-8222-222222222217','treatment','c1000000-0000-4000-8000-000000000017')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Struttura (9)
-- ---------------------------------------------------------------------------
select has_table('public','facilities','facilities exists');
select has_table('public','doctors','doctors exists');
select has_table('public','treatment_tags','treatment_tags exists');
select has_table('public','treatments','treatments exists');
select has_table('public','reviews','reviews exists');
select has_table('public','favorites','favorites exists');
select has_table('public','rating_summaries','rating_summaries exists');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in
  ('public.facilities'::regclass,'public.doctors'::regclass,'public.treatment_tags'::regclass,
   'public.treatments'::regclass,'public.reviews'::regclass,'public.favorites'::regclass,
   'public.rating_summaries'::regclass)),
 'all seven treatment tables have forced RLS');
select is((select count(*)::int from public.app_migrations where name='0017_treatments_schema'),1,
 '0017 registered');

-- ---------------------------------------------------------------------------
-- Utente estraneo (11)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111117","role":"authenticated"}',true);

select is((select count(*)::int from public.treatments where status='draft'),0,
 'stranger reads zero draft treatments');
select is((select count(*)::int from public.reviews where status='pending'),0,
 'stranger reads zero pending reviews');
select is((select count(*)::int from public.treatments
           where id='c1000000-0000-4000-8000-000000000017'),1,
 'stranger reads the published treatment');
select is((select count(*)::int from public.reviews
           where id='e1000000-0000-4000-8000-000000000017'),1,
 'stranger reads the approved review');
select throws_ok(
 $$insert into public.treatments(title, status) values('Scrittura diretta','published')$$,
 '42501', null, 'authenticated cannot insert treatments directly');
select throws_ok(
 $$insert into public.reviews(author_id,target_type,target_id,rating,body)
   values(auth.uid(),'treatment','c1000000-0000-4000-8000-000000000017',5,
          'Testo abbastanza lungo per superare il minimo.')$$,
 '42501', null, 'authenticated cannot insert reviews directly');
select is((select count(*)::int from public.favorites),0,
 'stranger reads zero favorites of another user');
select lives_ok(
 $$insert into public.favorites(user_id,target_type,target_id)
   values(auth.uid(),'treatment','c1000000-0000-4000-8000-000000000017')$$,
 'owner inserts own favorite');
select is((select count(*)::int from public.favorites),1,'owner reads own favorite');
select lives_ok(
 $$delete from public.favorites where user_id=auth.uid()
   and target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'$$,
 'owner deletes own favorite');
select is((select count(*)::int from public.favorites),0,'favorite is gone after delete');

-- ---------------------------------------------------------------------------
-- Autore della recensione pending (1)
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222217","role":"authenticated"}',true);
select is((select count(*)::int from public.reviews where status='pending' and author_id=auth.uid()),1,
 'author reads own pending review');

-- ---------------------------------------------------------------------------
-- Trigger dei tag e rating_summaries (contesto interno, nessun JWT) (7)
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);

select throws_ok(
 $$insert into public.treatments(title, status, tags)
   values('Tag inesistente','draft', array['tag_che_non_esiste'])$$,
 '23514', null, 'tag trigger rejects a tag missing from treatment_tags');

select is((select rating_count from public.rating_summaries
           where target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'),
 1, 'rating summary counts only the approved review');
select is((select rating_avg from public.rating_summaries
           where target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'),
 4.00::numeric, 'rating average is the approved review rating');

update public.reviews set status='approved', moderated_at=clock_timestamp()
 where id='e2000000-0000-4000-8000-000000000017';
select is((select rating_count from public.rating_summaries
           where target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'),
 2, 'rating summary grows when a review becomes approved');
select is((select rating_avg from public.rating_summaries
           where target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'),
 4.50::numeric, 'rating average recomputed after approval');

update public.reviews set status='withdrawn' where id='e2000000-0000-4000-8000-000000000017';
select is((select rating_count from public.rating_summaries
           where target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'),
 1, 'rating summary shrinks when a review is withdrawn');
select is((select rating_avg from public.rating_summaries
           where target_type='treatment' and target_id='c1000000-0000-4000-8000-000000000017'),
 4.00::numeric, 'rating average recomputed after withdrawal');

select * from finish();
rollback;
