-- Medical 24 — pgTAP 0019 treatments write (P07-A3).
-- Solo progetto dev: tutto in transazione, rollback finale, nessun dato resta.
--
-- Copre le otto funzioni di scrittura e moderazione del modulo Cure:
--   submit_review          nasce pending; una sola per autore e bersaglio
--                          (review_exists, 23505); corpo con URL rifiutato;
--                          corpo con una frase vietata del board rifiutato;
--                          sesta recensione del giorno rifiutata (P0001);
--   moderate_review        negata all'utente (42501), accolta dall'admin, con
--                          rating_summaries aggiornato;
--   withdraw_review        negata a un altro utente (42501), accolta
--                          dall'autore, con riepilogo aggiornato;
--   treatment_upsert       negata all'utente (42501), crea una draft per
--                          l'admin, incrementa version su una cura published;
--   treatment_set_status   rifiuta published senza evidenze e lo accetta dopo
--                          l'aggiornamento, valorizzando published_at;
--   toggle_favorite        alterna true e false.
--
-- Fixture create come postgres prima di qualunque set local role: Alice utente,
-- Bob admin, Carla terza utente; quattro cure published, un medico e una
-- struttura dimostrativi, tre recensioni gia' depositate oggi da Alice.

begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

-- ---------------------------------------------------------------------------
-- Fixture (come postgres)
-- ---------------------------------------------------------------------------
insert into auth.users(id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('a1111111-1111-4111-8111-111111111119','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','alice19@example.com','',now(),'{}',
  '{"full_name":"Alice Rossi"}',now(),now()),
 ('a2222222-2222-4222-8222-222222222219','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','bob19@example.com','',now(),'{}',
  '{"full_name":"Bob Bianchi"}',now(),now()),
 ('a3333333-3333-4333-8333-333333333319','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','carla19@example.com','',now(),'{}',
  '{"full_name":"Carla Neri"}',now(),now())
on conflict(id) do nothing;

insert into public.user_roles(user_id, role)
values ('a2222222-2222-4222-8222-222222222219','admin')
on conflict(user_id, role) do nothing;

insert into public.facilities(id, name, kind, city, region, verified, is_demo)
values ('f1000000-0000-4000-8000-000000000019','Centro Prova 19','poliambulatorio',
        'Milano','Lombardia',true,true)
on conflict(id) do nothing;

insert into public.doctors(id, display_name, role, registry_body, registry_number,
  verified, is_demo, facility_id)
values ('d1000000-0000-4000-8000-000000000019','Dott. Prova 19','fisioterapista',
        'OMCeO Milano','12345', true, true,'f1000000-0000-4000-8000-000000000019')
on conflict(id) do nothing;

insert into public.treatment_tags(tag, label_it, label_en, kind, sort_order) values
 ('fisioterapia','Fisioterapia','Physiotherapy','categoria',10),
 ('lombalgia','Lombalgia','Low back pain','patologia',20)
on conflict(tag) do nothing;

insert into public.treatments(id, title, summary, description_sections, family, scope,
  category, conditions, tags, evidence_level, price_from_cents, session_minutes,
  modality, status, is_demo, doctor_id, facility_id, published_at)
values
 ('c1000000-0000-4000-8000-000000000019','Rieducazione lombare 19','Percorso guidato.',
  '{"per_chi":"Adulti","evidenze_e_limiti":"Prove di media qualita."}'::jsonb,
  'tradizionale','riabilitazione','Fisioterapia', array['lombalgia'],
  array['fisioterapia'],'linee_guida', 5000, 45, 'presenza','published', true,
  'd1000000-0000-4000-8000-000000000019','f1000000-0000-4000-8000-000000000019',
  now() - interval '10 days'),
 ('c2000000-0000-4000-8000-000000000019','Ginnastica dolce 19','Gruppi piccoli.',
  '{"per_chi":"Adulti"}'::jsonb,'tradizionale','benessere','Benessere', '{}',
  array['fisioterapia'],'esperienziale', 3000, 60, 'presenza','published', true,
  null,'f1000000-0000-4000-8000-000000000019', now() - interval '9 days'),
 ('c3000000-0000-4000-8000-000000000019','Valutazione posturale 19','Incontro singolo.',
  '{"per_chi":"Adulti"}'::jsonb,'tradizionale','prevenzione','Prevenzione', '{}',
  array['fisioterapia'],'osservazionale', 7000, 30, 'online','published', true,
  null,'f1000000-0000-4000-8000-000000000019', now() - interval '8 days'),
 ('c4000000-0000-4000-8000-000000000019','Percorso respiratorio 19','Ciclo breve.',
  '{"per_chi":"Adulti"}'::jsonb,'tradizionale','terapia','Terapia', '{}',
  array['fisioterapia'],'studi_clinici', 9000, 45, 'ibrido','published', true,
  null,'f1000000-0000-4000-8000-000000000019', now() - interval '7 days')
on conflict(id) do nothing;

-- Tre recensioni gia' depositate oggi da Alice su altri bersagli: restano
-- pending, quindi non toccano rating_summaries, ma contano per il tetto.
insert into public.reviews(author_id, target_type, target_id, rating, body, status)
values
 ('a1111111-1111-4111-8111-111111111119','treatment','c2000000-0000-4000-8000-000000000019',
  4,'Prima recensione del giorno scritta per il test.','pending'),
 ('a1111111-1111-4111-8111-111111111119','treatment','c3000000-0000-4000-8000-000000000019',
  4,'Seconda recensione del giorno scritta per il test.','pending'),
 ('a1111111-1111-4111-8111-111111111119','doctor','d1000000-0000-4000-8000-000000000019',
  5,'Terza recensione del giorno scritta per il test.','pending')
on conflict do nothing;

create temp table m24_ids(k text primary key, v uuid);
grant all on m24_ids to authenticated;

-- ---------------------------------------------------------------------------
-- 1. Registro
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.app_migrations where name='0019_treatments_write'),
 1, '0019 registered');

-- ---------------------------------------------------------------------------
-- Alice, utente qualunque
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"a1111111-1111-4111-8111-111111111119","role":"authenticated"}', true);

-- 2-3. submit_review: accettata e pending
insert into m24_ids(k, v)
select 'rev', public.submit_review('treatment','c1000000-0000-4000-8000-000000000019',
  4, '{"efficacia":5,"costo":3}'::jsonb, 'Buon percorso',
  'Percorso chiaro e seguito con attenzione dal personale della struttura.');

select ok((select v from m24_ids where k='rev') is not null,
 'submit_review returns the new review id');

select is((select r.status::text from public.reviews r
            where r.id = (select v from m24_ids where k='rev')),
 'pending', 'a new review is born pending');

-- 4. Seconda recensione sullo stesso bersaglio
select throws_ok(
 $q$select public.submit_review('treatment','c1000000-0000-4000-8000-000000000019',
      5, '{}'::jsonb, null, 'Seconda recensione sullo stesso bersaglio, non ammessa.')$q$,
 '23505', null, 'a second review on the same target is rejected');

-- 5. Corpo con URL
select throws_ok(
 $q$select public.submit_review('treatment','c4000000-0000-4000-8000-000000000019',
      4, '{}'::jsonb, null, 'Trovi il programma completo su https://esempio.invalid/pagina.')$q$,
 '22023', null, 'a body containing a URL is rejected');

-- 6. Corpo con una frase vietata del board
select throws_ok(
 $q$select public.submit_review('treatment','c4000000-0000-4000-8000-000000000019',
      4, '{}'::jsonb, null, 'Stai tranquillo, niente di grave, il valore torna da solo.')$q$,
 '22023', null, 'a body matching a forbidden phrase is rejected');

-- Quarta recensione del giorno depositata direttamente: Alice arriva a cinque.
reset role; select set_config('request.jwt.claims','',true);
insert into public.reviews(author_id, target_type, target_id, rating, body, status)
values ('a1111111-1111-4111-8111-111111111119','facility','f1000000-0000-4000-8000-000000000019',
        4,'Quinta recensione del giorno scritta per il test.','pending')
on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"a1111111-1111-4111-8111-111111111119","role":"authenticated"}', true);

-- 7. Sesta recensione del giorno
select throws_ok(
 $q$select public.submit_review('treatment','c4000000-0000-4000-8000-000000000019',
      4, '{}'::jsonb, null, 'Sesta recensione del giorno, oltre il tetto consentito.')$q$,
 'P0001', null, 'the sixth review of the day is rejected');

-- 8. Moderazione negata all'utente
select throws_ok(
 $q$select public.moderate_review((select v from m24_ids where k='rev'),'approved',null)$q$,
 '42501', null, 'a normal user cannot moderate a review');

-- 15. treatment_upsert negata all'utente
select throws_ok(
 $q$select public.treatment_upsert('{"title":"Tentativo non ammesso"}'::jsonb)$q$,
 '42501', null, 'a normal user cannot upsert a treatment');

-- ---------------------------------------------------------------------------
-- Bob, admin
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"a2222222-2222-4222-8222-222222222219","role":"authenticated"}', true);

-- 9-11. Moderazione dell'admin e riepilogo
select lives_ok(
 $q$select public.moderate_review((select v from m24_ids where k='rev'),'approved','Va bene.')$q$,
 'an admin can approve a review');

select is((select r.status::text from public.reviews r
            where r.id = (select v from m24_ids where k='rev')),
 'approved', 'the moderated review becomes approved');

select is((select rs.rating_count from public.rating_summaries rs
            where rs.target_type='treatment'
              and rs.target_id='c1000000-0000-4000-8000-000000000019'),
 1, 'rating_summaries counts the approved review');

select is((select rs.rating_avg from public.rating_summaries rs
            where rs.target_type='treatment'
              and rs.target_id='c1000000-0000-4000-8000-000000000019'),
 4.00::numeric, 'rating_summaries stores the average of approved reviews');

-- 16-17. treatment_upsert dell'admin: nasce una bozza
insert into m24_ids(k, v)
select 'cure', public.treatment_upsert(jsonb_build_object(
  'title','Cura creata dal pannello 19',
  'facility_id','f1000000-0000-4000-8000-000000000019',
  'tags', jsonb_build_array('fisioterapia'),
  'description_sections', jsonb_build_object('per_chi','Adulti sedentari'),
  'price_from_cents', 4000,
  'session_minutes', 50));

select is((select t.status::text from public.treatments t
            where t.id = (select v from m24_ids where k='cure')),
 'draft', 'treatment_upsert creates a draft for the admin');

-- 18. draft -> verified
select lives_ok(
 $q$select public.treatment_set_status((select v from m24_ids where k='cure'),'verified')$q$,
 'draft moves to verified');

-- 19. verified -> published senza evidenze
select throws_ok(
 $q$select public.treatment_set_status((select v from m24_ids where k='cure'),'published')$q$,
 '22023', null, 'publishing without the evidence section is rejected');

-- 20-21. Aggiunta delle evidenze e pubblicazione
select lives_ok(
 $q$select public.treatment_upsert(jsonb_build_object(
     'id',(select v from m24_ids where k='cure'),
     'description_sections', jsonb_build_object(
       'per_chi','Adulti sedentari',
       'evidenze_e_limiti','Prove limitate e di qualita moderata.')))$q$,
 'the admin can add the evidence section');

select lives_ok(
 $q$select public.treatment_set_status((select v from m24_ids where k='cure'),'published')$q$,
 'publishing is accepted once the evidence section is filled');

select ok((select t.published_at is not null from public.treatments t
            where t.id = (select v from m24_ids where k='cure')),
 'published_at is set at the first publication');

-- 22. version incrementa su una modifica della cura published
select is((select public.treatment_upsert(jsonb_build_object(
             'id',(select v from m24_ids where k='cure'),
             'summary','Sommario aggiornato dopo la pubblicazione.'))
           is not null), true, 'a published treatment can be edited');

select is((select t.version from public.treatments t
            where t.id = (select v from m24_ids where k='cure')),
 2, 'editing a published treatment increments version');

-- ---------------------------------------------------------------------------
-- Carla: ritiro di una recensione altrui
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"a3333333-3333-4333-8333-333333333319","role":"authenticated"}', true);

select throws_ok(
 $q$select public.withdraw_review((select v from m24_ids where k='rev'))$q$,
 '42501', null, 'another user cannot withdraw a review');

-- ---------------------------------------------------------------------------
-- Alice: ritiro della propria recensione e preferiti
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"a1111111-1111-4111-8111-111111111119","role":"authenticated"}', true);

select lives_ok(
 $q$select public.withdraw_review((select v from m24_ids where k='rev'))$q$,
 'the author can withdraw her own review');

select is((select rs.rating_count from public.rating_summaries rs
            where rs.target_type='treatment'
              and rs.target_id='c1000000-0000-4000-8000-000000000019'),
 0, 'rating_summaries drops the withdrawn review');

select is(public.toggle_favorite('treatment','c1000000-0000-4000-8000-000000000019'),
 true, 'toggle_favorite adds the favorite');

select is(public.toggle_favorite('treatment','c1000000-0000-4000-8000-000000000019'),
 false, 'toggle_favorite removes the favorite');

reset role; select set_config('request.jwt.claims','',true);

select * from finish();
rollback;
