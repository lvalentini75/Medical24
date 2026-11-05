# Medical 24 — AUDIT_P10 · inventario di sicurezza dello schema

Fonti lette: `doc/CONTEXT_CORE.md` (v1.3), `doc/SECURITY_CHECKLIST.md`, `doc/DATA_MODEL.md`, `lib/supabase/supabase_tables.sql`, `lib/supabase/supabase_policies.sql`, `lib/supabase/migrations/*` (0002–0024), `lib/supabase/tests/*` (0001–0024), `lib/supabase/config.toml`, `lib/supabase/functions/*`.

## 1. Tabelle

| Tabella | RLS attiva | RLS forzata | Policy per comando (ruoli) | Append-only (trigger) | Interruttore di sessione | Test pgTAP |
| --- | --- | --- | --- | --- | --- | --- |
| profiles | sì | sì | select/insert/update `profiles_*_own` (authenticated); nessun delete | no | — | 0001 |
| user_roles | sì | **no** | select `user_roles_select_own` (authenticated); all `user_roles_admin_write` (authenticated admin) | no | — | 0001 |
| consents | sì | sì | select/insert `consents_*_own` (authenticated); nessun update/delete | di fatto (nessuna policy) | — | 0001 |
| audit_log | sì | **no** | select `audit_log_select_own` (authenticated); nessun insert/update/delete | di fatto (nessuna policy) | — | 0001 |
| app_migrations | sì | no | **nessuna policy** (deny-all intenzionale) | no | — | 0003 (solo `has_table`) |
| documents | sì | sì | select/insert/update `documents_*` (authenticated); nessun delete (soft) | no | — | 0002, 0003 |
| document_pages | sì | sì | select/insert/update `document_pages_*` (authenticated) | no | — | 0002 |
| biomarker_catalog | sì | **no** | select `biomarker_catalog_select` (anon, authenticated); all `biomarker_catalog_write` (authenticated board) | no | — | 0005 |
| extractions | sì | sì | select `extractions_select` (authenticated); nessuna scrittura | no | — | 0005 |
| observations | sì | sì | select `observations_select`; insert `observations_manual_insert` (authenticated); nessun update/delete | sì `trg_observations_append_only` | `medical24.allow_observation_write` | 0005, 0007, 0015 |
| symptoms | sì | sì | select/insert/update (24 h) `symptoms_*` (authenticated); nessun delete | no (soft delete) | — | 0007 |
| alerts | sì | sì | select `alerts_select`; update `alerts_mark_read` (authenticated, grant su `read_at`) | no | — | 0007 |
| biomarker_watch | sì | sì | select/insert/update/delete `biomarker_watch_*` (authenticated) | no | — | 0007 |
| organs | sì | sì | select `organs_select` (authenticated); all `organs_write` (board/admin) | no | — | 0008, 0009 |
| organ_biomarker_map | sì | sì | select `organ_biomarker_map_select`; all `organ_biomarker_map_write` (board/admin) | no | — | 0008 |
| rule_versions | sì | sì | select `rule_versions_select` (active/draft); all `rule_versions_write` (board/admin) | no | — | 0008, 0010, 0013 |
| organ_states | sì | sì | select `organ_states_select` (authenticated); nessuna scrittura | sì `trg_organ_states_append_only` | `medical24.allow_organ_state_write` | 0008, 0009, 0010 |
| risk_scores | sì | sì | select `risk_scores_select` (authenticated); nessuna scrittura | sì `trg_risk_scores_append_only` (nessun interruttore) | — | 0011, 0012 |
| questionnaires | sì | sì | select `questionnaires_select` (true); all `questionnaires_write` (board/admin) | no | — | 0011 |
| questionnaire_answers | sì | sì | select/insert `questionnaire_answers_*` (authenticated) | no | — | 0011 |
| prevention_calendar | sì | sì | select `prevention_calendar_select` (true); all `prevention_calendar_write` (board/admin) | no | — | 0011 |
| recommendations | sì | sì | select `recommendations_select` (authenticated); nessuna scrittura | no | — | 0011, 0012 |
| threshold_overrides | sì | sì | select `threshold_overrides_select`; all `threshold_overrides_board_write` (board/admin) | no | — | 0011, 0012 |
| explanations | sì | sì | select `explanations_select` (authenticated); nessuna scrittura | no | — | 0013 |
| ai_models | sì | sì | select `ai_models_admin_select` (authenticated admin) | no | — | 0014 |
| ai_tasks | sì | sì | select `ai_tasks_admin_select` (authenticated admin) | no | — | 0014, 0016 |
| ai_prompts | sì | sì | select `ai_prompts_admin_select` (authenticated admin) | no | — | 0014 |
| ai_usage_ledger | sì | sì | select `ai_usage_admin_select` (authenticated admin) | di fatto (nessuna policy) | — | 0014 |
| platform_settings | sì | sì | select `platform_settings_admin_select` (authenticated admin) | no | — | 0014 |
| platform_settings_history | sì | sì | select `platform_settings_history_admin_select` (authenticated admin) | di fatto (nessuna policy) | — | 0014 |
| platform_events | sì | sì | select `platform_events_admin_select` (authenticated admin) | di fatto (nessuna policy) | — | 0014 |
| facilities | sì | sì | select `facilities_public_select` (anon, authenticated, verified/is_demo) + `facilities_admin_select` | no | — | 0017, 0018 |
| doctors | sì | sì | select `doctors_public_select` (anon, authenticated) + `doctors_admin_select` | no | — | 0017, 0018 |
| treatment_tags | sì | sì | select `treatment_tags_public_select` (anon, authenticated, true) | no | — | 0017 |
| treatments | sì | sì | select `treatments_public_select` (published) + `treatments_admin_select` | no | — | 0017, 0018, 0019 |
| reviews | sì | sì | select `reviews_public_select` / `reviews_author_select` / `reviews_admin_select` | no | — | 0017, 0018, 0019 |
| favorites | sì | sì | select/insert/delete `favorites_owner_*` (authenticated) | no | — | 0017, 0019 |
| rating_summaries | sì | sì | select `rating_summaries_public_select` (anon, authenticated, true) | no (solo trigger) | — | 0017 |
| share_links | sì | sì | select `share_links_owner_select` (authenticated); nessuna scrittura | no | — | 0021, 0024 |
| share_link_opens | sì | sì | select `share_link_opens_owner_select` (authenticated via join) | sì `trg_share_link_opens_append_only` | `medical24.allow_purge` | 0021, 0024 |
| dossier_snapshots | sì | sì | select `dossier_snapshots_owner_select` (authenticated) | sì `trg_dossier_snapshots_append_only` (solo `pdf_path`) | `medical24.allow_purge` | 0021, 0022 |
| questions | sì | sì | select `questions_owner_select` (authenticated); nessuna scrittura | no | — | 0021, 0023 |
| emergency_cards | sì | sì | select `emergency_cards_owner_select` (authenticated); nessuna scrittura | no | — | 0021, 0023 |
| share_open_attempts | **non esiste nel repository** | — | — | — | `medical24.allow_purge` (prevista) | nessuno |

## 2. Viste

| Vista | security_invoker | Chi può leggerla |
| --- | --- | --- |
| biomarker_series | sì | `authenticated` (grant); `anon` revocato; RLS di `observations` |
| latest_organ_states | sì (0009; la 0008 la creava senza) | `authenticated` (grant); `anon` revocato |
| latest_risk_scores | sì | `authenticated` (grant); `anon` revocato |
| ai_usage_daily | sì | `authenticated` (grant), filtrata dalla policy admin di `ai_usage_ledger` |

## 3. Funzioni

| Funzione (firma) | definer/invoker | set search_path | execute | Chiamanti | Test |
| --- | --- | --- | --- | --- | --- |
| set_updated_at() | invoker | **no** | default (public) | trigger | — |
| immutable_array_to_string(text[],text) | invoker | **no** | default (public) | colonna generata | — |
| handle_new_user() | definer | public | default (public) | trigger auth.users | 0001 |
| can_access_subject(uuid) | definer | public | authenticated | policy, funzioni | 0001 |
| has_role(app_role) | definer | public | authenticated | policy, funzioni | 0001 |
| log_audit(text,text,uuid,uuid,text) | definer | public | authenticated | funzioni app | 0001 |
| record_consent(consent_type,text,boolean,text) | definer | public | authenticated | app | 0001 |
| custom_access_token_hook(jsonb) | definer | public | solo supabase_auth_admin | Auth hook | — |
| soft_delete_account() | definer | public | authenticated | app | — |
| purge_deleted_accounts() | definer | public | revocato a anon/authenticated | cron (non schedulato) | — |
| document_limit(uuid) | definer | public | authenticated | trigger, app | 0003 |
| enforce_document_limit() | definer | public | default (public) | trigger | 0002 |
| audit_document_soft_delete() | definer | public | default (public) | trigger | 0002 |
| can_access_document(uuid) | definer | public | authenticated | policy pages | 0002 |
| expire_stale_document_uploads() | definer | public | revocato anon/authenticated | cron | — |
| document_usage() | invoker | public | authenticated | app | 0003 |
| soft_delete_document(uuid) | definer | public | authenticated | app | 0002 |
| normalize_unit(text,numeric,text) | definer | public | authenticated | Edge `extract`, funzioni | 0005 |
| resolve_reference(uuid,text) | definer | public | authenticated | Edge `extract`, funzioni | 0005 |
| resolve_flag(uuid,text,numeric) | definer | public | authenticated | Edge `extract`, funzioni | 0005, 0012 |
| start_extraction(uuid) | definer | public | authenticated | app, Edge `extract` | 0005 |
| confirm_observation(uuid,numeric,text,text,timestamptz,text) | definer | public | authenticated | app | 0005, 0015 |
| confirm_observation_internal(uuid,uuid,…) | definer | public | revocato public/anon/authenticated | `confirm_observation`, `auto_confirm_extraction` | 0015 |
| auto_confirm_extraction(uuid) | definer | public | service_role | Edge `extract` | 0015 |
| analysis_limit(uuid) / analysis_usage() | definer / invoker | public | authenticated | app, Edge `extract` | 0005 |
| documents_pending_extraction(int) | definer | public | revocato a tutti i ruoli app | `enqueue_pending_extractions` | — |
| enqueue_pending_extractions(int) | definer | public | revocato a tutti i ruoli app | cron wrapper, Edge `extract-batch` | — |
| observations_append_only() | **invoker** | **no** | revocato public/anon/authenticated | trigger | 0005 |
| prepare_manual_observation() | definer | public | revocato public/anon/authenticated | trigger | 0007 |
| supersede_previous_observation() | definer | public | revocato public/anon/authenticated | trigger | 0007 |
| protect_symptom_identity() | **invoker** | public | revocato public/anon/authenticated | trigger | 0007 |
| create_observation_alert() | definer | public | revocato public/anon/authenticated | trigger | 0007 |
| soft_delete_symptom(uuid) | definer | public | authenticated | app | 0007 |
| biomarker_stats(uuid,text,timestamptz,timestamptz) | invoker | public | authenticated | app | 0007 |
| biomarker_episodes(uuid,text) | invoker | public | authenticated | app | 0007 |
| biomarker_catalog_for_subject(uuid) | invoker | public | authenticated | app | 0007 |
| observations_export(uuid) | invoker | public | authenticated | app (export) | 0007 |
| home_snapshot(uuid) | invoker | public | authenticated | app | 0007 |
| organ_for_catalog_key(text) | invoker | **no** | droppata in 0009 | — | — |
| organ_ids_for_catalog_key(text) | invoker | public | revocato a tutti i ruoli app | `rebuild_organ_biomarker_map` | 0009 |
| rebuild_organ_biomarker_map() | definer | public | revocato a tutti i ruoli app | migrazioni | 0008 |
| organ_states_append_only() | **invoker** | **no** | revocato public/anon/authenticated | trigger | 0008 |
| compute_organ_states(uuid) | definer | public | authenticated | trigger, cron, app | 0008, 0010 |
| compute_organ_states_all() | definer | public | revocato a tutti i ruoli app | cron wrapper | 0008 |
| refresh_organ_states_from_observation() | definer | public | revocato public/anon/authenticated | trigger | 0008 |
| organ_overview / organ_biomarkers / organ_history / organ_comparison / organ_episodes | invoker | public | authenticated | app | 0008, 0009 |
| subject_sex(uuid) | definer | public | authenticated | funzioni organi | 0009 |
| risk_scores_append_only() | **invoker** | **no** | revocato public/anon/authenticated | trigger | 0011 |
| score2_risk / findrisc_score / ckd_epi_2021 / fracture_checklist_score | invoker (immutable) | **no** | authenticated | `compute_risk_scores` | 0011 |
| compute_risk_scores(uuid) | definer | public | authenticated | trigger, cron | 0011 |
| compute_risk_scores_all() | definer | public | revocato a tutti i ruoli app | cron wrapper | 0011 |
| refresh_risk_scores_from_input() | definer | public | revocato public/anon/authenticated | trigger | 0011 |
| resolve_thresholds(uuid,text) | definer | public | authenticated | app | 0011 |
| refresh_recommendations(uuid) | definer | public | authenticated | app, `complete_recommendation` | 0011, 0012 |
| complete_recommendation(uuid,uuid) | definer | public | authenticated | app | 0011 |
| dismiss_recommendation(uuid,text) / reopen_recommendation(uuid) | definer | public | authenticated | app | 0012 |
| validate_threshold_override() | definer | public | revocato public/anon/authenticated | trigger | 0011, 0012 |
| audit_threshold_override() | definer | public | revocato public/anon/authenticated | trigger | 0011 |
| normalize_for_filter(text) | invoker (immutable) | **no** | authenticated, service_role | `check_forbidden_phrases` | 0013 |
| check_forbidden_phrases(text) | definer | public | authenticated, service_role | Edge `explain`, `submit_review` | 0013 |
| explanation_lookup(…) | invoker | public | default (public) | Edge `explain` | 0013 |
| explanation_usage(uuid) | definer | public | authenticated, service_role | Edge `explain` | 0013 |
| explanation_save(…) | definer | public | solo service_role | Edge `explain` | 0013 |
| explanation_context(uuid,text,text) | definer | public | authenticated, service_role | Edge `explain` | 0013 |
| platform_setting(text) | definer | public | **anon**, authenticated, service_role (giustificato: chiavi `is_public` prima del login, la funzione nega le altre) | app, Edge | 0014, 0015 |
| platform_setting_set(text,jsonb,text) | definer | public | authenticated (admin dentro) | pannello admin | 0014 |
| ai_prompt_create / _approve / _activate / _rollback | definer | public | authenticated (admin dentro) | pannello admin | 0014 |
| ai_prompt_record_test(uuid,jsonb) | definer | public | service_role | Edge `explain` | 0014 |
| platform_event(text,text,text,jsonb) | definer | public | service_role | wrapper cron, funzioni | 0014 |
| ai_log_call(…) | definer | public | service_role | Edge `extract`, `explain` | 0014 |
| ai_task_config(text) | definer | public | service_role | Edge `extract`, `explain` | 0014, 0016 |
| ai_task_set(text,jsonb) / ai_model_set(text,jsonb) | definer | public | authenticated (admin dentro) | pannello admin | 0016 |
| admin_read_audit / admin_overview / admin_ai_tasks / admin_prompts / admin_usage / admin_events / admin_audit / admin_rules / admin_ai_calls | definer | public | authenticated (admin dentro) | pannello admin | 0014, 0016 |
| rule_version_set_status(uuid,text) | definer | public | authenticated (admin/board dentro) | pannello admin | 0014 |
| run_enqueue_pending_extractions_logged(int) | definer | public | service_role | cron | 0014 |
| run_compute_organ_states_all_logged() | definer | public | service_role | cron | 0014 |
| run_compute_risk_scores_all_logged() | definer | public | service_role | cron | 0014 |
| run_platform_health_logged() | definer | public | service_role | cron | 0014 |
| m24_jsonb_keys_subset / m24_valid_contraindications / m24_valid_media / m24_treatment_search_doc | invoker (immutable) | **no** | anon, authenticated, service_role | check, colonne generate | 0017 |
| m24_treatments_check_tags() | definer | public | revocato public/anon/authenticated | trigger | 0017 |
| m24_refresh_rating_summary(review_target_type,uuid) | definer | public | revocato public/anon/authenticated | trigger | 0017 |
| m24_reviews_refresh_summary() | definer | public | revocato public/anon/authenticated | trigger | 0017 |
| m24_display_name_initial / m24_treatment_cover_url / m24_max_contraindication | invoker (immutable) | **no** | anon, authenticated, service_role | letture cure | 0018 |
| m24_review_author_label(uuid) | definer | public | **anon**, authenticated, service_role (giustificato: restituisce solo il nome ridotto) | `reviews_for_target` | 0018 |
| m24_treatments_filtered(…) | invoker | public, extensions | anon, authenticated, service_role | ricerca/faccette/confronto | 0018 |
| search_treatments / facets_for_treatments / treatment_detail / treatment_compare / reviews_for_target / featured_treatments | invoker | public, extensions | anon, authenticated, service_role | app | 0018 |
| m24_require_auth / m24_require_admin / m24_target_exists / m24_has_url / m24_valid_sub_ratings / m24_jsonb_text / _int / _bool / _text_array | definer o invoker | public | authenticated, service_role | funzioni di scrittura cure | 0019 |
| submit_review / moderate_review / withdraw_review / treatment_upsert / treatment_set_status / doctor_upsert / facility_upsert / toggle_favorite | definer | public | authenticated, service_role | app, pannello admin | 0019 |
| m24_seed_0020_treatments_demo() | definer | public, auth | revocato public/anon/authenticated | seed | 0020 |
| m24_valid_share_scope(jsonb) / m24_valid_emergency_contacts(jsonb) / m24_valid_public_fields(jsonb) | invoker (immutable) | **no** | anon, authenticated, service_role | check delle tabelle 0021 | 0021 |
| m24_block_mutation() | **invoker** | **no** | revocato public/anon/authenticated | trigger append-only | 0021 |
| m24_guard_dossier_snapshot() | **invoker** | **no** | revocato public/anon/authenticated | trigger | 0021, 0022 |
| m24_audit_share_link() / m24_audit_share_link_open() | definer | public | revocato public/anon/authenticated | trigger | 0021, 0024 |
| dossier_build(uuid,jsonb,uuid) | definer | public, extensions | authenticated, service_role | app, `share_link_create` | 0022 |
| dossier_latest(uuid) | definer | public, extensions | authenticated, service_role | app | 0022 |
| dossier_snapshot_set_pdf(uuid,text) | definer | public, extensions | solo service_role | Edge `dossier-pdf` | 0022 |
| m24_question_for_update(uuid) | definer | public, extensions | revocato public/anon/authenticated | funzioni domande | 0023 |
| question_create / question_update / question_send / question_record_answer / question_close / question_delete | definer | public, extensions | authenticated | app | 0023 |
| questions_for_link(uuid) | definer | public, extensions | solo service_role | Edge `dossier-open` (via `share_link_open`) | 0023 |
| question_answer_via_link(uuid,uuid,text) | definer | public, extensions | solo service_role | Edge `dossier-open` | 0023 |
| m24_emergency_text_array(jsonb,text) | definer | public, extensions | revocato public/anon/authenticated | `emergency_card_upsert` | 0023 |
| emergency_card_upsert(uuid,jsonb) | definer | public, extensions | authenticated | app | 0023 |
| emergency_card_regenerate_token(uuid) | definer | public, extensions | authenticated | app | 0023 |
| emergency_card_public(text) | definer | public, extensions | **anon**, authenticated (giustificato: pagina pubblica ICE a token, solo i campi marcati) | pagina `/ice/:token` | 0023 |
| m24_valid_pin(text) | invoker (immutable) | **no** | revocato public/anon/authenticated | `share_link_create` | 0024 |
| m24_random_code() | invoker (volatile) | public, extensions | revocato public/anon/authenticated | `share_link_create` | 0024 |
| share_link_create(uuid,text,jsonb,interval,int) | definer | public, extensions | solo authenticated | app | 0024 |
| share_link_revoke(uuid) | definer | public, extensions | solo authenticated | app | 0024 |
| share_links_for_subject(uuid) | definer | public, extensions | solo authenticated | app | 0024 |
| share_link_open(text,text,text,text) | definer | public, extensions | solo service_role | Edge `dossier-open` | 0024 |
| share_open_rate_check(text) | definer | public, extensions | solo service_role | Edge `dossier-open` | 0024 |
| share_link_is_active(uuid) | **non esiste nel repository** | — | — | Edge `dossier-open` (la chiama) | nessuno |

## 4. Trigger

| Tabella | Evento | Funzione | Scopo |
| --- | --- | --- | --- |
| auth.users | after insert | handle_new_user | crea profilo e ruolo `user` |
| profiles | before update | set_updated_at | timestamp |
| user_roles | before update | set_updated_at | timestamp |
| documents | before update | set_updated_at | timestamp |
| documents | before insert | enforce_document_limit | limite del piano |
| documents | after update | audit_document_soft_delete | audit `document.deleted` |
| biomarker_catalog | before update | set_updated_at | timestamp |
| extractions | before update | set_updated_at | timestamp |
| observations | before update/delete | observations_append_only | append-only |
| observations | before insert | prepare_manual_observation | normalizza e valida il valore manuale |
| observations | after insert | supersede_previous_observation | chiude la riga precedente |
| observations | after insert | create_observation_alert | avviso fuori intervallo |
| observations | after insert | refresh_risk_scores_from_input | ricalcolo rischi |
| observations | after insert | refresh_organ_states_from_observation | ricalcolo stati d'organo |
| symptoms | before update | set_updated_at / protect_symptom_identity | timestamp e immutabilità |
| organs | before update | set_updated_at | timestamp |
| organ_biomarker_map | before update | set_updated_at | timestamp |
| rule_versions | before update | set_updated_at | timestamp |
| organ_states | before update/delete | organ_states_append_only | append-only |
| risk_scores | before update/delete | risk_scores_append_only | append-only |
| questionnaire_answers | after insert | refresh_risk_scores_from_input | ricalcolo rischi |
| threshold_overrides | before insert/update | validate_threshold_override | limiti di sicurezza del board |
| threshold_overrides | after insert/update/delete | audit_threshold_override | audit |
| facilities / doctors / treatments / reviews | before update | set_updated_at | timestamp |
| treatments | before insert/update of tags | m24_treatments_check_tags | tag nel vocabolario |
| reviews | after insert/update/delete | m24_reviews_refresh_summary | ricalcolo `rating_summaries` |
| share_link_opens | before update/delete | m24_block_mutation | append-only con `allow_purge` |
| share_link_opens | after insert | m24_audit_share_link_open | audit `share_link.opened` |
| share_links | after insert/update | m24_audit_share_link | audit creazione e revoca |
| dossier_snapshots | before update/delete | m24_guard_dossier_snapshot | append-only salvo `pdf_path` |
| questions | before update | set_updated_at | timestamp |
| emergency_cards | before update | set_updated_at | timestamp |

## 5. Edge Functions

| Funzione | verify_jwt | Segreti letti | SQL e tabelle usate (client) | Test Deno |
| --- | --- | --- | --- | --- |
| delete-account | true | SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY | `profiles` update, `audit_log` insert, `auth.admin.signOut` (service_role); identità con client utente | **nessuno** |
| document-ingest | true | SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY | `documents` select (utente), `documents`/`document_pages`/`audit_log` write e Storage `documents` (service_role) | **nessuno** |
| extract | true | SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, CLAUDE_API_KEY | `analysis_usage`, `start_extraction` (utente); `ai_task_config`, `ai_log_call`, `platform_setting`, `auto_confirm_extraction`, `normalize_unit`, `resolve_reference`, `resolve_flag` (service_role) | `index_test.ts` |
| extract-batch | true + confronto manuale con la service key | SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY | `enqueue_pending_extractions` (service_role) | **nessuno** |
| extract-batch-poll | true + confronto manuale con la service key | SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY | `extractions` select/update, invocazione di `extract` (service_role) | **nessuno** |
| explain | true | SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, CLAUDE_API_KEY | `explanation_context`, `explanation_lookup`, `explanation_usage` (utente); `ai_task_config`, `check_forbidden_phrases`, `ai_log_call`, `ai_prompt_record_test`, `explanation_save` (service_role) | `index_test.ts` |
| dossier-open | **false** | DOSSIER_HASH_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY | `share_open_rate_check`, `share_link_open`, `share_link_is_active`, `question_answer_via_link`, `dossier_snapshots` select, Storage `dossiers` (service_role) | `index_test.ts` |
| dossier-pdf | true | SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY | `dossier_snapshots` select (utente); `dossier_snapshot_set_pdf`, Storage `dossiers` e `brand` (service_role) | `index_test.ts` |

## 6. Cron

| Job | Orario | Wrapper con cron_run/cron_error |
| --- | --- | --- |
| enqueue-pending-extractions | 03:45 | sì (`run_enqueue_pending_extractions_logged`, 0014) |
| compute-organ-states | 04:15 | sì (`run_compute_organ_states_all_logged`, 0014) |
| medical24-risk-scores-nightly | 04:35 | sì (`run_compute_risk_scores_all_logged`, 0014) |
| platform-health | 05:00 | sì (`run_platform_health_logged`, 0014) |
| expire-stale-document-uploads | 03:15 | **no** (chiama direttamente `expire_stale_document_uploads()`) |
| purge-deleted-accounts | **non schedulato** (solo commentato in `supabase_tables.sql`) | **no** |
| purge dei tentativi di apertura | **non schedulato** (atteso dalla 0025) | — |

## 7. Storage

| Bucket | Pubblico/privato | Policy | Schema dei percorsi |
| --- | --- | --- | --- |
| documents | privato (`public = false`, 25 MB, MIME dichiarati) | `documents_storage_select/insert/update/delete` su `storage.objects` per `authenticated` con `can_access_subject(foldername[2])` | `subjects/{subject_id}/documents/{document_id}/original.ext`, `/page-NNN.jpg`, `/thumb-NNN.jpg` |
| dossiers | privato (creato a runtime dalla Edge `dossier-pdf`, `public: false`) | **nessuna policy in migrazione**: accesso solo via service_role e signed URL a 600 s | `subjects/{subject_id}/dossier/{snapshot_id}.pdf` |
| brand | pubblico (previsto dal CONTEXT_CORE) | **nessuna policy in migrazione** | `logo.png` |

---

## Anomalie

1. **Migrazione 0025 assente dal repository** — `lib/supabase/migrations/` si ferma alla 0024; non esistono né `share_open_attempts`, né `share_link_is_active(uuid)`, né il test `0025_doctor_v1_hardening_test.sql`, benché il CONTEXT_CORE v1.3 li dia per applicati — **alta** — ripristinare o riscrivere la migrazione 0025 e il suo test prima di qualunque altro lavoro su M9.
2. **`lib/supabase/functions/dossier-open/handler.ts:377`** — la funzione chiama `share_link_is_active`, che nello schema del repository non esiste: ogni `answer` e ogni `pdf` ricadono su `active !== true` e rispondono 403 — **alta** — applicare la 0025 oppure creare `share_link_is_active(uuid)` riservata al `service_role`.
3. **`lib/supabase/migrations/20261113_090000_migration.sql:540`** — `share_open_rate_check` conta solo le righe `wrong_pin` di `share_link_opens`: un codice inesistente non lascia traccia (riga 400) e quindi l'enumerazione dei codici non è frenata — **alta** — registrare anche i `not_found` in `share_open_attempts` e contarli nel freno per IP (contenuto previsto dalla 0025).
4. **`lib/supabase/supabase_policies.sql:8`** — `user_roles` ha RLS attiva ma **non forzata**: il proprietario della tabella la aggira — **alta** — aggiungere `alter table public.user_roles force row level security;`.
5. **`lib/supabase/supabase_policies.sql:10`** — `audit_log` ha RLS attiva ma **non forzata** sul registro di tracciabilità — **alta** — aggiungere `force row level security`.
6. **`lib/supabase/migrations/20261025_090000_migration.sql:717`** — `biomarker_catalog` ha RLS attiva ma **non forzata** — **media** — aggiungere `force row level security`.
7. **`lib/supabase/migrations/20261024_104530_migration.sql:382`** — `app_migrations` ha RLS attiva e **nessuna policy**: deny-all voluto ma non dichiarato, e nessun test lo verifica — **bassa** — aggiungere un commento sulla tabella e un'asserzione pgTAP che `authenticated` legge zero righe.
8. **`lib/supabase/supabase_tables.sql:115`** — `set_updated_at()` è `security invoker` senza `set search_path` ed è eseguibile da `public`: è il trigger usato da 14 tabelle — **media** — aggiungere `set search_path = public` e revocare `execute` a `public`, `anon`, `authenticated`.
9. **`lib/supabase/migrations/20261024_104530_migration.sql:12`** — `immutable_array_to_string(text[],text)` senza `set search_path` ed eseguibile da `public`, usata dentro una colonna generata di `documents` — **bassa** — fissare `search_path` e revocare a `public`.
10. **`lib/supabase/migrations/20261025_090000_migration.sql:221`**, **`20261030_091500_migration.sql:329`**, **`20261030_093442_migration.sql:54`** — le tre funzioni di trigger append-only (`observations_append_only`, `organ_states_append_only`, `risk_scores_append_only`) sono `security invoker` senza `set search_path` — **media** — aggiungere `set search_path = public` a tutte e tre.
11. **`lib/supabase/migrations/20261110_090000_migration.sql:155` e `:173`** — `m24_block_mutation()` e `m24_guard_dossier_snapshot()`, guardie append-only del modulo Medico, sono `security invoker` senza `set search_path` — **media** — aggiungere `set search_path = public`.
12. **`lib/supabase/migrations/20261024_104530_migration.sql:147` e `:181`** — `enforce_document_limit()` e `audit_document_soft_delete()` sono `security definer` ma mantengono `execute` a `public` (nessuna `revoke`): chiunque può invocarle fuori dal trigger — **media** — `revoke execute … from public, anon, authenticated`.
13. **`lib/supabase/supabase_tables.sql:138`** — `handle_new_user()` è `security definer` e conserva `execute` a `public` — **media** — revocare `execute` a `public`, `anon`, `authenticated`.
14. **`lib/supabase/migrations/20261103_090000_migration.sql:267`** — `explanation_lookup(…)` non ha né `revoke … from public` né `grant` espliciti: resta eseguibile da `public` e quindi da `anon` — **media** — revocare a `public` e `anon`, concedere ad `authenticated` e `service_role` (è `security invoker`, quindi il rischio è contenuto dalla RLS di `explanations`).
15. **`lib/supabase/migrations/20261030_093442_migration.sql:252-309`** — `score2_risk`, `findrisc_score`, `ckd_epi_2021`, `fracture_checklist_score` sono pure ma senza `set search_path` e concesse ad `authenticated` — **bassa** — aggiungere `set search_path = public` per coerenza.
16. **`lib/supabase/migrations/20261103_090000_migration.sql:154`** e **`20261106_090000_migration.sql:77,90,105,123`**, **`20261107_090000_migration.sql:43,59,74`**, **`20261110_090000_migration.sql:75,111,133`**, **`20261113_090000_migration.sql:39`** — funzioni `immutable` senza `set search_path`; alcune (`m24_jsonb_keys_subset`, `m24_valid_*`, `m24_treatment_search_doc`) sono usate dentro `check` e colonne generate — **media** — fissare `set search_path = pg_catalog, public` su tutte le funzioni usate in vincoli e colonne generate.
17. **`lib/supabase/migrations/20261030_091500_migration.sql:348`** — la vista `latest_organic_states` nasce nella 0008 **senza** `security_invoker` ed è corretta solo nella 0009 (`20261031_090000_migration.sql:144`): un ambiente che abbia applicato la 0008 e non la 0009 espone stati d'organo di altri soggetti — **media** — verificare in dev che `latest_organ_states` abbia `security_invoker = true` e renderlo esplicito in una migrazione idempotente.
18. **`lib/supabase/migrations/20261024_104530_migration.sql:359`** — il cron `expire-stale-document-uploads` (03:15) chiama direttamente `expire_stale_document_uploads()` senza il wrapper `cron_run`/`cron_error` della 0014 — **media** — aggiungere `run_expire_stale_document_uploads_logged()` e rischedulare il job.
19. **`lib/supabase/supabase_tables.sql:352`** — `purge_deleted_accounts()` esiste ma la schedulazione è solo un commento: la purge a 30 giorni (art. 17 GDPR) **non è attiva** e non ha wrapper — **alta** — schedulare la purge dietro un wrapper `run_purge_deleted_accounts_logged()` e registrarne l'esito in `platform_events`.
20. **`lib/supabase/supabase_tables.sql:326`** — `purge_deleted_accounts()` cancella da `auth.users` contando sulla cascata, ma non alza `medical24.allow_purge`: la cascata su `share_link_opens` e `dossier_snapshots` viene bloccata con `42501` dalle guardie della 0021 e la purge fallisce — **alta** — alzare l'interruttore `medical24.allow_purge` (e abbassarlo) dentro la funzione, oppure gestire esplicitamente le tabelle append-only del modulo M9.
21. **`lib/supabase/functions/delete-account/index.ts:65`** — la cancellazione dell'account tocca solo `profiles.deleted_at` e `audit_log`: non revoca i `share_links` attivi, non invalida i `public_token` delle `emergency_cards`, non cancella i PDF del bucket `dossiers`. Un link condiviso e una scheda ICE restano aperti per 30 giorni dopo la richiesta di cancellazione — **alta** — revocare tutti i link attivi, rigenerare o azzerare il token ICE e rimuovere gli oggetti Storage del soggetto nella stessa chiamata.
22. **`lib/supabase/functions/dossier-pdf/handler.ts:200`** — il bucket `dossiers` viene creato a runtime dalla Edge Function e non ha alcuna policy dichiarata in migrazione, a differenza di `documents` — **media** — creare il bucket e le sue policy in una migrazione, con lo schema dei percorsi `subjects/{subject_id}/dossier/…`.
23. **`lib/supabase/functions/dossier-pdf/handler.ts:175`** — il bucket `brand` è usato dalla funzione ma non è dichiarato in nessuna migrazione né documentato con una policy — **bassa** — dichiarare il bucket pubblico `brand` e la sua policy di sola lettura in migrazione.
24. **`lib/supabase/functions/document-ingest/index.ts:146`** — il log di errore stampa `storage_path`, che contiene `subject_id` e `document_id` in chiaro: è un identificativo di dato sanitario nei log — **media** — registrare soltanto il codice `invalid_path`, senza il percorso.
25. **`lib/supabase/functions/delete-account/index.ts:1`**, **`document-ingest/index.ts:1`**, **`extract-batch/index.ts:1`**, **`extract-batch-poll/index.ts:1`** — quattro Edge Functions senza alcun test Deno e senza la forma `handler.ts` + `createHandler(deps)` prescritta dal CONTEXT_CORE §4 — **media** — portarle alla forma con handler iniettabile e aggiungere i test.
26. **`lib/supabase/functions/extract-batch/index.ts:48`** e **`extract-batch-poll/index.ts:49`** — l'autorizzazione confronta l'header con la service key in **tempo non costante** (`!==` su stringhe) — **bassa** — usare un confronto a tempo costante come in `dossier-open`.
27. **`lib/supabase/config.toml`** — `delete-account`, `document-ingest`, `extract`, `extract-batch`, `extract-batch-poll` hanno `verify_jwt = true`, ma `extract-batch` ed `extract-batch-poll` sono destinate al solo `service_role`: la configurazione non esprime la restrizione e resta affidata al confronto manuale nel codice — **bassa** — documentare la scelta nel file di configurazione.
28. **`doc/DATA_MODEL.md:5` vs schema reale** — il documento dichiara 56 tabelle; nello schema applicato ce ne sono 43. Mancano del tutto `family_members`, `medications`, `devices`, `push_tokens`, `doctor_patient_links`, `doctor_notes`, `subscriptions`, `payments`, `payouts`, `content_references`, `content_wiki`, `author_terms` e le tabelle v1.5/v2/v3 — **bassa** — nessuna azione sullo schema (sono di release successive), ma allineare la nota del DATA_MODEL ai moduli già realizzati.
29. **`doc/DATA_MODEL.md:57` vs `lib/supabase/migrations/20261110_090000_migration.sql:199`** — il DATA_MODEL descrive `share_links` con un `token`; la tabella reale ha `code` (6 cifre) e `pin_hash` (bcrypt) — **bassa** — aggiornare la riga del DATA_MODEL alla forma applicata.
30. **`doc/DATA_MODEL.md:60` vs `20261110_090000_migration.sql:315`** — il DATA_MODEL dà `questions` con `doctor_id` e accesso «entrambe le parti»; la tabella reale ha `doctor_email` e una sola policy di `select` per il proprietario — **bassa** — allineare la descrizione.
31. **`doc/DATA_MODEL.md:51` vs `20261106_090000_migration.sql:227`** — il DATA_MODEL dà `treatment_tags` con chiave `treatment_id`; la tabella reale è un vocabolario con chiave `tag` — **bassa** — allineare la descrizione.
32. **`doc/DATA_MODEL.md` (tabelle mancanti nel documento)** — `emergency_cards`, `dossier_snapshots`, `share_link_opens`, `app_migrations`, `alerts` (presente), `biomarker_watch`, `rating_summaries`, `platform_settings_history`, `platform_events`, `ai_models`, `ai_tasks`, `ai_prompts`, `ai_usage_ledger` non figurano o figurano senza riga propria, pur esistendo nello schema — **bassa** — aggiungere le righe mancanti al DATA_MODEL.
33. **`doc/DATA_MODEL.md:15`** — dichiara che i ruoli «finiscono nel JWT con l'auth hook», mentre il CONTEXT_CORE §7 prescrive che i ruoli **non** stiano nel JWT e si leggano con `has_role`; `custom_access_token_hook` esiste e li scrive davvero — **media** — decidere la regola unica e, se vale il CONTEXT_CORE, disattivare l'hook e correggere il DATA_MODEL.
34. **Copertura pgTAP assente** — `app_migrations`, `alerts` (solo `has_table`), `rating_summaries`, `favorites`, `treatment_tags`, `platform_settings_history`, `platform_events` e `ai_usage_ledger` non hanno un'asserzione «un utente estraneo ottiene zero righe» come richiede il punto 11 della SECURITY_CHECKLIST — **media** — aggiungere le asserzioni mancanti nel test del P10.
35. **`lib/supabase/tests/0016_task_request_options_test`** — il file non ha estensione `.sql` e non rispetta la convenzione `tests/NNNN_<nome>_test.sql` del CONTEXT_CORE §4 — **bassa** — rinominare il file.
