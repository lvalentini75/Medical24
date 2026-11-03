-- Medical 24 — pgTAP 0018 treatments read (P07-A2).
-- Solo progetto dev: tutto in transazione, rollback finale, nessun dato resta.
--
-- Copre le sei funzioni di lettura del modulo Cure:
--   search_treatments      testo libero su titolo, tag, nome del medico e nome
--                          della struttura; invisibilita' della bozza; filtri
--                          scope, family, modality, citta', prezzo massimo e
--                          durata; ordinamento per prezzo; total_count coerente
--                          con la paginazione;
--   facets_for_treatments  conteggi uguali al risultato della ricerca;
--   treatment_detail       medico, struttura e sole recensioni approved; null
--                          per una cura non visibile;
--   treatment_compare      rifiuto di 1 e di 5 id (22023), accettazione di 2;
--   reviews_for_target     solo approved, dalla piu' recente, autore ridotto;
--   featured_treatments    solo le cure in evidenza.
--
-- Fixture create come postgres prima di qualunque set local role: quattro cure
-- published di scope e famiglie diverse, una draft, un medico e due strutture
-- dimostrative, tre recensioni approved e una pending.

begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

-- ---------------------------------------------------------------------------
-- Fixture (come postgres)
-- ---------------------------------------------------------------------------
insert into auth.users(id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('a1111111-1111-4111-8111-111111111118','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','reader18@example.com','',now(),'{}',
  '{"full_name":"Luca Verdi"}',now(),now()),
 ('a2222222-2222-4222-8222-222222222218','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','author18a@example.com','',now(),'{}',
  '{"full_name":"Mario Rossi"}',now(),now()),
 ('a3333333-3333-4333-8333-333333333318','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','author18b@example.com','',now(),'{}',
  '{"full_name":"Anna Bianchi"}',now(),now()),
 ('a4444444-4444-4444-8444-444444444418','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','author18c@example.com','',now(),'{}',
  '{"full_name":"Giulia Neri"}',now(),now())
on conflict(id) do nothing;

insert into public.facilities(id, name, kind, city, region, verified, is_demo)
values
 ('f1000000-0000-4000-8000-000000000018','Centro Prova 18','poliambulatorio',
  'Milano','Lombardia',true,true),
 ('f2000000-0000-4000-8000-000000000018','Clinica Zeta 18','clinica',
  'Roma','Lazio',true,true)
on conflict(id) do nothing;

insert into public.doctors(id, display_name, role, verified, is_demo, facility_id)
values ('d1000000-0000-4000-8000-000000000018','Dott. Prova 18','fisioterapista',
        true,true,'f1000000-0000-4000-8000-000000000018')
on conflict(id) do nothing;

insert into public.treatment_tags(tag, label_it, label_en, kind, sort_order) values
 ('fisioterapia','Fisioterapia','Physiotherapy','categoria',10),
 ('lombalgia','Lombalgia','Low back pain','patologia',20),
 ('agopuntura','Agopuntura','Acupuncture','categoria',30),
 ('nutrizione','Nutrizione','Nutrition','categoria',40),
 ('postura','Postura','Posture','obiettivo',50)
on conflict(tag) do nothing;

insert into public.treatments(id, title, summary, description_sections, family, scope,
  category, conditions, tags, evidence_level, contraindications, price_from_cents,
  price_to_cents, session_minutes, sessions_count, course_weeks, waiting_days,
  modality, media, status, featured, is_demo, doctor_id, facility_id, published_at)
values
 ('c1000000-0000-4000-8000-000000000018','Rieducazione lombare',
  'Percorso in palestra medica.',
  '{"per_chi":"Adulti con lombalgia cronica","come_funziona":"Esercizio terapeutico"}'::jsonb,
  'tradizionale','riabilitazione','Fisioterapia', array['lombalgia'],
  array['fisioterapia','lombalgia'],'linee_guida',
  '[{"text":"Dolore acuto","severity":"media"}]'::jsonb,
  5000, 9000, 45, 10, 8, 7, 'presenza',
  '[{"type":"image","url":"https://example.invalid/c1.jpg"}]'::jsonb,
  'published', true, true,
  'd1000000-0000-4000-8000-000000000018','f1000000-0000-4000-8000-000000000018',
  now() - interval '10 days'),
 ('c2000000-0000-4000-8000-000000000018','Agopuntura per emicrania',
  'Cicli brevi con valutazione iniziale.',
  '{"per_chi":"Adulti con cefalea ricorrente"}'::jsonb,
  'naturale','terapia','Medicina complementare', array['cefalea'],
  array['agopuntura'],'osservazionale',
  '[{"text":"Terapia anticoagulante","severity":"alta"}]'::jsonb,
  3000, 6000, 30, 8, 6, 3, 'presenza',
  '[{"type":"image","url":"https://example.invalid/c2.jpg"}]'::jsonb,
  'published', false, true, null,'f2000000-0000-4000-8000-000000000018',
  now() - interval '8 days'),
 ('c3000000-0000-4000-8000-000000000018','Consulenza nutrizionale a distanza',
  'Valutazione e piano alimentare.',
  '{"per_chi":"Adulti in sovrappeso"}'::jsonb,
  'tradizionale','prevenzione','Nutrizione', array['sovrappeso'],
  array['nutrizione'],'studi_clinici','[]'::jsonb,
  8000, null, 60, 4, 12, 1, 'online', '[]'::jsonb,
  'published', false, true, null, null, now() - interval '6 days'),
 ('c4000000-0000-4000-8000-000000000018','Percorso posturale integrato',
  'Lavoro combinato in sede e a casa.',
  '{"per_chi":"Adulti sedentari"}'::jsonb,
  'altro','benessere','Benessere', array['postura'],
  array['postura'],'esperienziale','[]'::jsonb,
  12000, 18000, 90, 12, 10, 30, 'ibrido',
  '[{"type":"video","url":"https://example.invalid/c4.mp4"},
    {"type":"image","url":"https://example.invalid/c4.jpg"}]'::jsonb,
  'published', true, true,
  'd1000000-0000-4000-8000-000000000018','f1000000-0000-4000-8000-000000000018',
  now() - interval '4 days'),
 ('c5000000-0000-4000-8000-000000000018','Protocollo sperimentale in bozza',
  'Scheda non ancora pubblicata.',
  '{"per_chi":"Da definire"}'::jsonb,
  'sperimentale','terapia','Fisioterapia', array['lombalgia'],
  array['fisioterapia'],'non_valutato','[]'::jsonb,
  1000, null, 30, 1, 1, 0, 'ibrido', '[]'::jsonb,
  'draft', false, true, null, null, null)
on conflict(id) do nothing;

insert into public.reviews(id, author_id, target_type, target_id, rating, sub_ratings,
  title, body, status, verified, created_at)
values
 ('e1000000-0000-4000-8000-000000000018','a2222222-2222-4222-8222-222222222218',
  'treatment','c1000000-0000-4000-8000-000000000018', 4, '{"ascolto":4}'::jsonb,
  'Percorso utile','Il percorso e stato utile e ben spiegato dal personale.',
  'approved', true, now() - interval '2 days'),
 ('e2000000-0000-4000-8000-000000000018','a3333333-3333-4333-8333-333333333318',
  'treatment','c1000000-0000-4000-8000-000000000018', 5, '{"ascolto":5}'::jsonb,
  'Molto bene','Struttura ordinata e professionisti attenti alle esigenze.',
  'approved', false, now() - interval '1 days'),
 ('e3000000-0000-4000-8000-000000000018','a4444444-4444-4444-8444-444444444418',
  'treatment','c1000000-0000-4000-8000-000000000018', 2, '{}'::jsonb,
  'In moderazione','Recensione ancora in moderazione, scritta per il test.',
  'pending', false, now()),
 ('e4000000-0000-4000-8000-000000000018','a2222222-2222-4222-8222-222222222218',
  'treatment','c2000000-0000-4000-8000-000000000018', 3, '{}'::jsonb,
  'Nella media','Trattamento svolto con regolarita e senza particolari problemi.',
  'approved', false, now() - interval '3 days')
on conflict(id) do nothing;

-- ---------------------------------------------------------------------------
-- 1. Registro
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.app_migrations where name='0018_treatments_read'),
 1, '0018 registered');

-- ---------------------------------------------------------------------------
-- Contesto: utente autenticato qualunque (nessun ruolo speciale)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"a1111111-1111-4111-8111-111111111118","role":"authenticated"}', true);

-- ---------------------------------------------------------------------------
-- 2-7. search_treatments: testo libero e invisibilita' della bozza
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.search_treatments()), 4,
 'search returns the four published treatments');

select is((select count(*)::int from public.search_treatments(p_query=>'emicrania')), 1,
 'search finds a treatment by its title');

select is((select count(*)::int from public.search_treatments(p_tags=>array['nutrizione'])), 1,
 'search filters by tag');

select is((select count(*)::int from public.search_treatments(p_query=>'Prova 18')), 2,
 'search finds treatments by doctor display name');

select is((select count(*)::int from public.search_treatments(p_query=>'Zeta 18')), 1,
 'search finds treatments by facility name');

select is((select count(*)::int from public.search_treatments(p_query=>'bozza')), 0,
 'search never returns a draft treatment');

-- ---------------------------------------------------------------------------
-- 8-13. Filtri
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.search_treatments(p_scope=>array['riabilitazione'])), 1,
 'scope filter narrows the result');

select is((select count(*)::int from public.search_treatments(p_family=>array['naturale'])), 1,
 'family filter narrows the result');

select is((select count(*)::int from public.search_treatments(p_modality=>array['online'])), 1,
 'modality filter narrows the result');

select is((select count(*)::int from public.search_treatments(p_city=>'Roma')), 1,
 'city filter narrows the result');

select is((select count(*)::int from public.search_treatments(p_max_price_cents=>5000)), 2,
 'max price filter narrows the result');

select is((select count(*)::int from public.search_treatments(p_duration_bucket=>'30')), 1,
 'duration bucket filter narrows the result');

-- ---------------------------------------------------------------------------
-- 14-18. Ordinamento e paginazione
-- ---------------------------------------------------------------------------
select is((select price_from_cents from public.search_treatments(p_sort=>'prezzo_asc', p_limit=>1)),
 3000, 'prezzo_asc starts from the lowest price');

select is((select price_from_cents from public.search_treatments(
            p_sort=>'prezzo_asc', p_limit=>1, p_offset=>1)),
 5000, 'prezzo_asc second page keeps the ascending order');

select is((select price_from_cents from public.search_treatments(p_sort=>'prezzo_desc', p_limit=>1)),
 12000, 'prezzo_desc starts from the highest price');

select is((select distinct total_count from public.search_treatments(p_limit=>2)), 4::bigint,
 'total_count ignores pagination');

select is((select count(*)::int from public.search_treatments(p_limit=>2)), 2,
 'p_limit caps the returned rows');

-- ---------------------------------------------------------------------------
-- 19-22. Faccette
-- ---------------------------------------------------------------------------
select is((public.facets_for_treatments()->>'total')::int, 4,
 'facets total matches the search');

select is((public.facets_for_treatments()->'scope'->>'riabilitazione')::int, 1,
 'facets count scope like the search');

select is((public.facets_for_treatments()->'city'->>'Roma')::int, 1,
 'facets count city like the search');

select is((public.facets_for_treatments()->'modality'->>'online')::int, 1,
 'facets count modality like the search');

-- ---------------------------------------------------------------------------
-- 23-26. treatment_detail
-- ---------------------------------------------------------------------------
select is(public.treatment_detail('c1000000-0000-4000-8000-000000000018')
            ->'doctor'->>'display_name',
 'Dott. Prova 18', 'detail returns the doctor');

select is(public.treatment_detail('c1000000-0000-4000-8000-000000000018')
            ->'facility'->>'name',
 'Centro Prova 18', 'detail returns the facility');

select is(jsonb_array_length(public.treatment_detail('c1000000-0000-4000-8000-000000000018')
            ->'reviews'), 2, 'detail returns only approved reviews');

select ok(public.treatment_detail('c5000000-0000-4000-8000-000000000018') is null,
 'detail of a draft treatment is null');

-- ---------------------------------------------------------------------------
-- 27-29. treatment_compare
-- ---------------------------------------------------------------------------
select throws_ok(
 $$select * from public.treatment_compare(
     array['c1000000-0000-4000-8000-000000000018']::uuid[])$$,
 '22023', null, 'compare rejects a single id');

select throws_ok(
 $$select * from public.treatment_compare(array[
     'c1000000-0000-4000-8000-000000000018','c2000000-0000-4000-8000-000000000018',
     'c3000000-0000-4000-8000-000000000018','c4000000-0000-4000-8000-000000000018',
     'c5000000-0000-4000-8000-000000000018']::uuid[])$$,
 '22023', null, 'compare rejects five ids');

select is((select count(*)::int from public.treatment_compare(array[
   'c1000000-0000-4000-8000-000000000018',
   'c2000000-0000-4000-8000-000000000018']::uuid[])), 2,
 'compare accepts two ids');

-- ---------------------------------------------------------------------------
-- 30-32. reviews_for_target
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.reviews_for_target(
   'treatment','c1000000-0000-4000-8000-000000000018')), 2,
 'reviews_for_target returns only approved reviews');

select is((select author_label from public.reviews_for_target(
   'treatment','c1000000-0000-4000-8000-000000000018', 1, 0)),
 'Anna B.', 'reviews_for_target shortens the author surname and sorts by recency');

select is((select distinct total_count from public.reviews_for_target(
   'treatment','c1000000-0000-4000-8000-000000000018', 1, 0)), 2::bigint,
 'reviews_for_target total_count ignores pagination');

-- ---------------------------------------------------------------------------
-- 33-34. featured_treatments
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.featured_treatments(10)), 2,
 'featured_treatments returns the two featured treatments');

select ok((select bool_and(id in ('c1000000-0000-4000-8000-000000000018',
                                 'c4000000-0000-4000-8000-000000000018'))
             from public.featured_treatments(10)),
 'featured_treatments returns only featured treatments');

reset role; select set_config('request.jwt.claims','',true);

select * from finish();
rollback;
