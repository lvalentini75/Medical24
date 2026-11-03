-- Medical 24 - pgTAP 0020 treatments demo seed (P07-A4).
-- Solo progetto dev: verifica conteggi, integrita', ricerca e idempotenza.

begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

select is((select count(*)::int from public.app_migrations where name='0020_treatments_seed'),
  1, '0020 registered');
select is((select count(*)::int from public.facilities where id::text like 'f0200000-%'),
  10, 'seed contains ten facilities');
select is((select count(*)::int from public.doctors where id::text like 'd0200000-%'),
  16, 'seed contains sixteen professionals');
select is((select count(*)::int from public.treatment_tags),
  40, 'controlled vocabulary contains forty tags');
select is((select count(*)::int from public.treatments where id::text like 'c0200000-%'),
  40, 'seed contains forty treatments');
select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%' and status='published'),
  40, 'all forty treatments are published');
select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%' and featured),
  8, 'exactly eight treatments are featured');
select is((select count(*)::int from public.reviews
            where id::text like 'e0200000-%' and status='approved'),
  120, 'seed contains 120 approved reviews');
select is((select count(*)::int from public.reviews
            where id::text like 'e0200000-%' and status='pending'),
  10, 'seed contains ten pending reviews');
select is((select count(*)::int from public.reviews
            where id::text like 'e0200000-%' and status='rejected'),
  4, 'seed contains four rejected reviews');

select ok((select bool_and(is_demo) from public.facilities where id::text like 'f0200000-%'),
  'all seeded facilities are demo');
select ok((select bool_and(is_demo) from public.doctors where id::text like 'd0200000-%'),
  'all seeded professionals are demo');
select ok((select bool_and(is_demo) from public.treatments where id::text like 'c0200000-%'),
  'all seeded treatments are demo');
select ok(not exists(select 1 from public.treatments
  where id::text like 'c0200000-%' and status='published'
    and doctor_id is null and facility_id is null),
  'every published treatment has a doctor or a facility');
select ok(not exists(select 1 from public.treatments
  where id::text like 'c0200000-%'
    and nullif(btrim(description_sections->>'evidenze_e_limiti'),'') is null),
  'every treatment has a non-empty evidence and limits section');
select ok(not exists(select 1 from public.treatments t
  cross join lateral unnest(t.tags) as x(tag)
  where t.id::text like 'c0200000-%'
    and not exists(select 1 from public.treatment_tags g where g.tag=x.tag)),
  'every treatment tag exists in the vocabulary');
select is((select count(*)::int from public.rating_summaries rs
  where rs.target_type='treatment' and rs.target_id in
    (select id from public.treatments where id::text like 'c0200000-%')
    and rs.rating_count > 0), 40,
  'rating summaries exist for every reviewed treatment');
select ok(not exists(select 1 from public.rating_summaries rs
  where rs.target_type='treatment' and rs.target_id in
    (select id from public.treatments where id::text like 'c0200000-%')
    and (rs.rating_avg < 3.8 or rs.rating_avg > 4.8)),
  'treatment averages stay between 3.8 and 4.8');

set local role anon;
select ok((select count(*) from public.search_treatments(p_query=>'fisioterapia')) >= 3,
  'search_treatments finds at least three physiotherapy treatments');
reset role;

select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%' and scope='riabilitazione'),
  12, 'distribution contains twelve rehabilitation treatments');
select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%'
              and scope in ('prevenzione','diagnostica') and evidence_level='linee_guida'),
  10, 'distribution contains ten prevention and diagnostic treatments');
select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%' and scope='benessere'
              and evidence_level in ('esperienziale','osservazionale')),
  8, 'distribution contains eight wellbeing treatments');
select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%' and scope='terapia'
              and family='tradizionale' and evidence_level='studi_clinici'),
  6, 'distribution contains six traditional therapies');
select is((select count(*)::int from public.treatments
            where id::text like 'c0200000-%' and family='sperimentale'
              and evidence_level='osservazionale'
              and description_sections->>'evidenze_e_limiti' ilike '%sperimentale%'),
  4, 'distribution contains four explicitly limited experimental paths');
select ok(not exists(select 1 from public.treatments
  where id::text like 'c0200000-%' and not
    (description_sections ?& array['per_chi','come_funziona','durata',
      'rischi_e_controindicazioni','evidenze_e_limiti'])),
  'all five description sections are populated');
select ok(not exists(select 1 from public.treatments
  where id::text like 'c0200000-%'
    and jsonb_array_length(contraindications) not between 1 and 3),
  'every treatment has one to three contraindications');
select ok(not exists(select 1 from public.treatments t
  where t.id::text like 'c0200000-%'
    and (jsonb_array_length(t.media) not between 1 and 2 or exists(
      select 1 from jsonb_array_elements(t.media) as m(item)
      where m.item->>'url' not like 'https://placehold.co/%'))),
  'every treatment has one or two neutral placeholder media');
select ok(not exists(select 1 from public.treatments
  where id::text like 'c0200000-%' and
    (price_from_cents is null or price_to_cents is null or session_minutes is null
      or sessions_count is null or course_weeks is null or waiting_days is null)),
  'prices and timing fields are populated');
select is((select count(*)::int from auth.users
            where id::text like 'a0200000-%' and email like '%@demo.medical24.app'),
  6, 'six demo auth users exist');

create temp table seed_counts as
select
  (select count(*) from public.facilities where id::text like 'f0200000-%') as facilities,
  (select count(*) from public.doctors where id::text like 'd0200000-%') as doctors,
  (select count(*) from public.treatments where id::text like 'c0200000-%') as treatments,
  (select count(*) from public.reviews where id::text like 'e0200000-%') as reviews,
  (select count(*) from public.rating_summaries where target_type='treatment' and target_id in
    (select id from public.treatments where id::text like 'c0200000-%')) as summaries;

select lives_ok($$select public.m24_seed_0020_treatments_demo()$$,
  'a second seed execution succeeds');
select is((select count(*) from public.facilities where id::text like 'f0200000-%'),
  (select facilities from seed_counts), 'second execution does not duplicate facilities');
select is((select count(*) from public.doctors where id::text like 'd0200000-%'),
  (select doctors from seed_counts), 'second execution does not duplicate professionals');
select is((select count(*) from public.treatments where id::text like 'c0200000-%'),
  (select treatments from seed_counts), 'second execution does not duplicate treatments');
select is((select count(*) from public.reviews where id::text like 'e0200000-%'),
  (select reviews from seed_counts), 'second execution does not duplicate reviews');
select is((select count(*) from public.rating_summaries where target_type='treatment'
            and target_id in (select id from public.treatments where id::text like 'c0200000-%')),
  (select summaries from seed_counts), 'second execution does not duplicate summaries');

select * from finish();
rollback;