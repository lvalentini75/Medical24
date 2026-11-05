export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      ai_models: {
        Row: {
          context_window: number | null
          display_name: string
          id: string
          notes: string | null
          price_cached_in_micro_usd_per_mtok: number | null
          price_in_micro_usd_per_mtok: number | null
          price_out_micro_usd_per_mtok: number | null
          provider: string
          status: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          context_window?: number | null
          display_name: string
          id: string
          notes?: string | null
          price_cached_in_micro_usd_per_mtok?: number | null
          price_in_micro_usd_per_mtok?: number | null
          price_out_micro_usd_per_mtok?: number | null
          provider: string
          status?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          context_window?: number | null
          display_name?: string
          id?: string
          notes?: string | null
          price_cached_in_micro_usd_per_mtok?: number | null
          price_in_micro_usd_per_mtok?: number | null
          price_out_micro_usd_per_mtok?: number | null
          provider?: string
          status?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      ai_prompts: {
        Row: {
          activated_at: string | null
          approved_at: string | null
          approved_by: string | null
          created_at: string
          created_by: string | null
          id: string
          last_test: Json | null
          notes: string | null
          retired_at: string | null
          status: string
          system_prompt: string
          task_id: string
          tool_schema: Json
          user_template: string
          version: string
        }
        Insert: {
          activated_at?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          last_test?: Json | null
          notes?: string | null
          retired_at?: string | null
          status?: string
          system_prompt: string
          task_id: string
          tool_schema?: Json
          user_template: string
          version: string
        }
        Update: {
          activated_at?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          last_test?: Json | null
          notes?: string | null
          retired_at?: string | null
          status?: string
          system_prompt?: string
          task_id?: string
          tool_schema?: Json
          user_template?: string
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_prompts_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "ai_tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_tasks: {
        Row: {
          active_prompt_id: string | null
          budget_action: string
          daily_budget_micro_usd: number | null
          description: string
          enabled: boolean
          enabled_fallback: boolean
          fallback_model_id: string | null
          id: string
          max_output_tokens: number
          model_id: string
          paused_until: string | null
          per_user_daily_limit: number | null
          request_options: Json
          requires_second_approval: boolean
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          active_prompt_id?: string | null
          budget_action?: string
          daily_budget_micro_usd?: number | null
          description: string
          enabled?: boolean
          enabled_fallback?: boolean
          fallback_model_id?: string | null
          id: string
          max_output_tokens: number
          model_id: string
          paused_until?: string | null
          per_user_daily_limit?: number | null
          request_options?: Json
          requires_second_approval?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          active_prompt_id?: string | null
          budget_action?: string
          daily_budget_micro_usd?: number | null
          description?: string
          enabled?: boolean
          enabled_fallback?: boolean
          fallback_model_id?: string | null
          id?: string
          max_output_tokens?: number
          model_id?: string
          paused_until?: string | null
          per_user_daily_limit?: number | null
          request_options?: Json
          requires_second_approval?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_tasks_active_prompt_fk"
            columns: ["active_prompt_id"]
            isOneToOne: false
            referencedRelation: "ai_prompts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_tasks_fallback_model_id_fkey"
            columns: ["fallback_model_id"]
            isOneToOne: false
            referencedRelation: "ai_models"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_tasks_model_id_fkey"
            columns: ["model_id"]
            isOneToOne: false
            referencedRelation: "ai_models"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_usage_ledger: {
        Row: {
          called_at: string
          cost_micro_usd: number
          error_code: string | null
          function_name: string
          id: string
          latency_ms: number
          model_id: string
          prompt_version: string
          request_id: string | null
          status: string
          subject_id: string | null
          task_id: string
          tokens_cached_in: number
          tokens_in: number
          tokens_out: number
        }
        Insert: {
          called_at?: string
          cost_micro_usd?: number
          error_code?: string | null
          function_name: string
          id?: string
          latency_ms?: number
          model_id: string
          prompt_version: string
          request_id?: string | null
          status: string
          subject_id?: string | null
          task_id: string
          tokens_cached_in?: number
          tokens_in?: number
          tokens_out?: number
        }
        Update: {
          called_at?: string
          cost_micro_usd?: number
          error_code?: string | null
          function_name?: string
          id?: string
          latency_ms?: number
          model_id?: string
          prompt_version?: string
          request_id?: string | null
          status?: string
          subject_id?: string | null
          task_id?: string
          tokens_cached_in?: number
          tokens_in?: number
          tokens_out?: number
        }
        Relationships: [
          {
            foreignKeyName: "ai_usage_ledger_model_id_fkey"
            columns: ["model_id"]
            isOneToOne: false
            referencedRelation: "ai_models"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_usage_ledger_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "ai_tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      alerts: {
        Row: {
          code: string
          created_at: string
          id: string
          level: Database["public"]["Enums"]["alert_level"]
          message_key: string
          read_at: string | null
          source_id: string
          source_table: string
          subject_id: string
          type: Database["public"]["Enums"]["alert_type"]
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          level: Database["public"]["Enums"]["alert_level"]
          message_key: string
          read_at?: string | null
          source_id: string
          source_table: string
          subject_id: string
          type: Database["public"]["Enums"]["alert_type"]
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          level?: Database["public"]["Enums"]["alert_level"]
          message_key?: string
          read_at?: string | null
          source_id?: string
          source_table?: string
          subject_id?: string
          type?: Database["public"]["Enums"]["alert_type"]
        }
        Relationships: []
      }
      app_migrations: {
        Row: {
          applied_at: string
          name: string
        }
        Insert: {
          applied_at?: string
          name: string
        }
        Update: {
          applied_at?: string
          name?: string
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          device: string | null
          id: string
          subject_id: string | null
          target_id: string | null
          target_table: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          device?: string | null
          id?: string
          subject_id?: string | null
          target_id?: string | null
          target_table?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          device?: string | null
          id?: string
          subject_id?: string | null
          target_id?: string | null
          target_table?: string | null
        }
        Relationships: []
      }
      biomarker_catalog: {
        Row: {
          age_note: string | null
          board_version: number
          category: string
          code: string
          created_at: string
          is_essential: boolean
          name_en: string
          name_it: string
          notes: string | null
          organs: string[]
          plausible_max: number | null
          plausible_min: number | null
          ref_high_f: number | null
          ref_high_m: number | null
          ref_low_f: number | null
          ref_low_m: number | null
          safety_high: number | null
          safety_low: number | null
          status: Database["public"]["Enums"]["catalog_status"]
          synonyms_en: string[]
          synonyms_it: string[]
          unit_alternatives: Json
          unit_canonical: string
          updated_at: string
        }
        Insert: {
          age_note?: string | null
          board_version?: number
          category: string
          code: string
          created_at?: string
          is_essential?: boolean
          name_en: string
          name_it: string
          notes?: string | null
          organs?: string[]
          plausible_max?: number | null
          plausible_min?: number | null
          ref_high_f?: number | null
          ref_high_m?: number | null
          ref_low_f?: number | null
          ref_low_m?: number | null
          safety_high?: number | null
          safety_low?: number | null
          status?: Database["public"]["Enums"]["catalog_status"]
          synonyms_en?: string[]
          synonyms_it?: string[]
          unit_alternatives?: Json
          unit_canonical: string
          updated_at?: string
        }
        Update: {
          age_note?: string | null
          board_version?: number
          category?: string
          code?: string
          created_at?: string
          is_essential?: boolean
          name_en?: string
          name_it?: string
          notes?: string | null
          organs?: string[]
          plausible_max?: number | null
          plausible_min?: number | null
          ref_high_f?: number | null
          ref_high_m?: number | null
          ref_low_f?: number | null
          ref_low_m?: number | null
          safety_high?: number | null
          safety_low?: number | null
          status?: Database["public"]["Enums"]["catalog_status"]
          synonyms_en?: string[]
          synonyms_it?: string[]
          unit_alternatives?: Json
          unit_canonical?: string
          updated_at?: string
        }
        Relationships: []
      }
      biomarker_watch: {
        Row: {
          code: string
          created_at: string
          favorite: boolean
          subject_id: string
          tracked: boolean
        }
        Insert: {
          code: string
          created_at?: string
          favorite?: boolean
          subject_id: string
          tracked?: boolean
        }
        Update: {
          code?: string
          created_at?: string
          favorite?: boolean
          subject_id?: string
          tracked?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "biomarker_watch_code_fkey"
            columns: ["code"]
            isOneToOne: false
            referencedRelation: "biomarker_catalog"
            referencedColumns: ["code"]
          },
        ]
      }
      consents: {
        Row: {
          created_at: string
          granted: boolean
          granted_at: string
          id: string
          locale: string
          revoked_at: string | null
          type: Database["public"]["Enums"]["consent_type"]
          user_id: string
          version: string
        }
        Insert: {
          created_at?: string
          granted?: boolean
          granted_at?: string
          id?: string
          locale?: string
          revoked_at?: string | null
          type: Database["public"]["Enums"]["consent_type"]
          user_id: string
          version: string
        }
        Update: {
          created_at?: string
          granted?: boolean
          granted_at?: string
          id?: string
          locale?: string
          revoked_at?: string | null
          type?: Database["public"]["Enums"]["consent_type"]
          user_id?: string
          version?: string
        }
        Relationships: []
      }
      data_exports: {
        Row: {
          bytes: number | null
          created_at: string
          error_code: string | null
          expires_at: string | null
          file_count: number | null
          id: string
          ready_at: string | null
          requested_at: string
          requested_by: string | null
          status: Database["public"]["Enums"]["data_export_status"]
          storage_path: string | null
          subject_id: string
          truncated: boolean
        }
        Insert: {
          bytes?: number | null
          created_at?: string
          error_code?: string | null
          expires_at?: string | null
          file_count?: number | null
          id?: string
          ready_at?: string | null
          requested_at?: string
          requested_by?: string | null
          status?: Database["public"]["Enums"]["data_export_status"]
          storage_path?: string | null
          subject_id: string
          truncated?: boolean
        }
        Update: {
          bytes?: number | null
          created_at?: string
          error_code?: string | null
          expires_at?: string | null
          file_count?: number | null
          id?: string
          ready_at?: string | null
          requested_at?: string
          requested_by?: string | null
          status?: Database["public"]["Enums"]["data_export_status"]
          storage_path?: string | null
          subject_id?: string
          truncated?: boolean
        }
        Relationships: []
      }
      doctors: {
        Row: {
          bio: string | null
          created_at: string
          created_by: string | null
          display_name: string
          facility_id: string | null
          id: string
          is_demo: boolean
          languages: string[]
          photo_url: string | null
          registry_body: string | null
          registry_number: string | null
          role: Database["public"]["Enums"]["doctor_role"]
          specialties: string[]
          updated_at: string
          user_id: string | null
          verified: boolean
        }
        Insert: {
          bio?: string | null
          created_at?: string
          created_by?: string | null
          display_name: string
          facility_id?: string | null
          id?: string
          is_demo?: boolean
          languages?: string[]
          photo_url?: string | null
          registry_body?: string | null
          registry_number?: string | null
          role?: Database["public"]["Enums"]["doctor_role"]
          specialties?: string[]
          updated_at?: string
          user_id?: string | null
          verified?: boolean
        }
        Update: {
          bio?: string | null
          created_at?: string
          created_by?: string | null
          display_name?: string
          facility_id?: string | null
          id?: string
          is_demo?: boolean
          languages?: string[]
          photo_url?: string | null
          registry_body?: string | null
          registry_number?: string | null
          role?: Database["public"]["Enums"]["doctor_role"]
          specialties?: string[]
          updated_at?: string
          user_id?: string | null
          verified?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "doctors_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
        ]
      }
      document_pages: {
        Row: {
          created_at: string
          document_id: string
          height: number | null
          id: string
          image_path: string | null
          ocr_text: string | null
          page_number: number
          thumb_path: string | null
          width: number | null
        }
        Insert: {
          created_at?: string
          document_id: string
          height?: number | null
          id?: string
          image_path?: string | null
          ocr_text?: string | null
          page_number: number
          thumb_path?: string | null
          width?: number | null
        }
        Update: {
          created_at?: string
          document_id?: string
          height?: number | null
          id?: string
          image_path?: string | null
          ocr_text?: string | null
          page_number?: number
          thumb_path?: string | null
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "document_pages_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
        ]
      }
      documents: {
        Row: {
          ai_tags: string[]
          category: Database["public"]["Enums"]["document_category"]
          created_at: string
          deleted_at: string | null
          doctor_name: string | null
          document_date: string | null
          duplicate_dismissed_at: string | null
          duplicate_of: string | null
          episode: string | null
          facility_name: string | null
          failure_reason: string | null
          id: string
          mime_type: string | null
          notes: string | null
          original_name: string | null
          owner_id: string
          page_count: number
          search: unknown
          sha256: string | null
          size_bytes: number | null
          source: Database["public"]["Enums"]["document_source"]
          status: Database["public"]["Enums"]["document_status"]
          storage_path: string
          subject_id: string
          tags: string[]
          title: string
          updated_at: string
        }
        Insert: {
          ai_tags?: string[]
          category?: Database["public"]["Enums"]["document_category"]
          created_at?: string
          deleted_at?: string | null
          doctor_name?: string | null
          document_date?: string | null
          duplicate_dismissed_at?: string | null
          duplicate_of?: string | null
          episode?: string | null
          facility_name?: string | null
          failure_reason?: string | null
          id?: string
          mime_type?: string | null
          notes?: string | null
          original_name?: string | null
          owner_id: string
          page_count?: number
          search?: unknown
          sha256?: string | null
          size_bytes?: number | null
          source?: Database["public"]["Enums"]["document_source"]
          status?: Database["public"]["Enums"]["document_status"]
          storage_path: string
          subject_id: string
          tags?: string[]
          title?: string
          updated_at?: string
        }
        Update: {
          ai_tags?: string[]
          category?: Database["public"]["Enums"]["document_category"]
          created_at?: string
          deleted_at?: string | null
          doctor_name?: string | null
          document_date?: string | null
          duplicate_dismissed_at?: string | null
          duplicate_of?: string | null
          episode?: string | null
          facility_name?: string | null
          failure_reason?: string | null
          id?: string
          mime_type?: string | null
          notes?: string | null
          original_name?: string | null
          owner_id?: string
          page_count?: number
          search?: unknown
          sha256?: string | null
          size_bytes?: number | null
          source?: Database["public"]["Enums"]["document_source"]
          status?: Database["public"]["Enums"]["document_status"]
          storage_path?: string
          subject_id?: string
          tags?: string[]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "documents_duplicate_of_fkey"
            columns: ["duplicate_of"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
        ]
      }
      dossier_snapshots: {
        Row: {
          generated_at: string
          id: string
          payload: Json
          pdf_path: string | null
          rule_versions: Json
          share_link_id: string | null
          subject_id: string
        }
        Insert: {
          generated_at?: string
          id?: string
          payload?: Json
          pdf_path?: string | null
          rule_versions?: Json
          share_link_id?: string | null
          subject_id: string
        }
        Update: {
          generated_at?: string
          id?: string
          payload?: Json
          pdf_path?: string | null
          rule_versions?: Json
          share_link_id?: string | null
          subject_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "dossier_snapshots_share_link_id_fkey"
            columns: ["share_link_id"]
            isOneToOne: false
            referencedRelation: "share_links"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_cards: {
        Row: {
          allergies: string[]
          blood_group: string | null
          conditions: string[]
          contacts: Json
          created_at: string
          fields_public: Json
          medications: string[]
          notes: string | null
          public_token: string
          subject_id: string
          updated_at: string
        }
        Insert: {
          allergies?: string[]
          blood_group?: string | null
          conditions?: string[]
          contacts?: Json
          created_at?: string
          fields_public?: Json
          medications?: string[]
          notes?: string | null
          public_token?: string
          subject_id: string
          updated_at?: string
        }
        Update: {
          allergies?: string[]
          blood_group?: string | null
          conditions?: string[]
          contacts?: Json
          created_at?: string
          fields_public?: Json
          medications?: string[]
          notes?: string | null
          public_token?: string
          subject_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      explanations: {
        Row: {
          cost_micro_usd: number
          created_at: string
          filter_ids: number[]
          filter_passed: boolean
          generated_at: string
          id: string
          inputs_hash: string
          lang: string
          level: string
          model: string
          prompt_version: string
          subject_id: string
          target_id: string
          target_type: string
          text: string
          tokens_in: number
          tokens_out: number
        }
        Insert: {
          cost_micro_usd?: number
          created_at?: string
          filter_ids?: number[]
          filter_passed?: boolean
          generated_at?: string
          id?: string
          inputs_hash: string
          lang: string
          level: string
          model: string
          prompt_version: string
          subject_id: string
          target_id: string
          target_type: string
          text: string
          tokens_in?: number
          tokens_out?: number
        }
        Update: {
          cost_micro_usd?: number
          created_at?: string
          filter_ids?: number[]
          filter_passed?: boolean
          generated_at?: string
          id?: string
          inputs_hash?: string
          lang?: string
          level?: string
          model?: string
          prompt_version?: string
          subject_id?: string
          target_id?: string
          target_type?: string
          text?: string
          tokens_in?: number
          tokens_out?: number
        }
        Relationships: []
      }
      extractions: {
        Row: {
          attempt: number
          cost_micro_usd: number | null
          created_at: string
          detected_category:
            | Database["public"]["Enums"]["document_category"]
            | null
          detected_date: string | null
          document_id: string
          failure_reason: string | null
          finished_at: string | null
          id: string
          lab_name: string | null
          mean_confidence: number | null
          model: string | null
          prompt_version: string | null
          raw: Json | null
          started_at: string | null
          status: Database["public"]["Enums"]["extraction_status"]
          subject_id: string
          tokens_in: number | null
          tokens_out: number | null
          updated_at: string
          values_saved: number
          values_to_review: number
          values_total: number
        }
        Insert: {
          attempt?: number
          cost_micro_usd?: number | null
          created_at?: string
          detected_category?:
            | Database["public"]["Enums"]["document_category"]
            | null
          detected_date?: string | null
          document_id: string
          failure_reason?: string | null
          finished_at?: string | null
          id?: string
          lab_name?: string | null
          mean_confidence?: number | null
          model?: string | null
          prompt_version?: string | null
          raw?: Json | null
          started_at?: string | null
          status?: Database["public"]["Enums"]["extraction_status"]
          subject_id: string
          tokens_in?: number | null
          tokens_out?: number | null
          updated_at?: string
          values_saved?: number
          values_to_review?: number
          values_total?: number
        }
        Update: {
          attempt?: number
          cost_micro_usd?: number | null
          created_at?: string
          detected_category?:
            | Database["public"]["Enums"]["document_category"]
            | null
          detected_date?: string | null
          document_id?: string
          failure_reason?: string | null
          finished_at?: string | null
          id?: string
          lab_name?: string | null
          mean_confidence?: number | null
          model?: string | null
          prompt_version?: string | null
          raw?: Json | null
          started_at?: string | null
          status?: Database["public"]["Enums"]["extraction_status"]
          subject_id?: string
          tokens_in?: number | null
          tokens_out?: number | null
          updated_at?: string
          values_saved?: number
          values_to_review?: number
          values_total?: number
        }
        Relationships: [
          {
            foreignKeyName: "extractions_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
        ]
      }
      facilities: {
        Row: {
          address: string | null
          city: string | null
          country: string
          created_at: string
          created_by: string | null
          email: string | null
          id: string
          is_demo: boolean
          kind: Database["public"]["Enums"]["facility_kind"]
          lat: number | null
          lng: number | null
          name: string
          opening_hours: Json
          phone: string | null
          photos: string[]
          region: string | null
          services: string[]
          ssn_accredited: boolean
          updated_at: string
          verified: boolean
          website: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          country?: string
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          is_demo?: boolean
          kind?: Database["public"]["Enums"]["facility_kind"]
          lat?: number | null
          lng?: number | null
          name: string
          opening_hours?: Json
          phone?: string | null
          photos?: string[]
          region?: string | null
          services?: string[]
          ssn_accredited?: boolean
          updated_at?: string
          verified?: boolean
          website?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          country?: string
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          is_demo?: boolean
          kind?: Database["public"]["Enums"]["facility_kind"]
          lat?: number | null
          lng?: number | null
          name?: string
          opening_hours?: Json
          phone?: string | null
          photos?: string[]
          region?: string | null
          services?: string[]
          ssn_accredited?: boolean
          updated_at?: string
          verified?: boolean
          website?: string | null
        }
        Relationships: []
      }
      favorites: {
        Row: {
          created_at: string
          target_id: string
          target_type: Database["public"]["Enums"]["review_target_type"]
          user_id: string
        }
        Insert: {
          created_at?: string
          target_id: string
          target_type: Database["public"]["Enums"]["review_target_type"]
          user_id: string
        }
        Update: {
          created_at?: string
          target_id?: string
          target_type?: Database["public"]["Enums"]["review_target_type"]
          user_id?: string
        }
        Relationships: []
      }
      observations: {
        Row: {
          catalog_version: number
          code: string
          confidence: number | null
          confirmed_at: string | null
          confirmed_by: string | null
          created_at: string
          display_name: string
          document_id: string | null
          effective_at: string
          extraction_id: string | null
          flag: Database["public"]["Enums"]["observation_flag"]
          id: string
          lab_high: number | null
          lab_low: number | null
          lab_name: string | null
          needs_review: boolean
          origin: Database["public"]["Enums"]["observation_origin"]
          ref_high: number | null
          ref_low: number | null
          review_status: Database["public"]["Enums"]["observation_review_status"]
          rule_version: string
          subject_id: string
          superseded_at: string | null
          supersedes_id: string | null
          unit: string | null
          unit_raw: string | null
          value_num: number | null
          value_raw: number | null
          value_text: string | null
        }
        Insert: {
          catalog_version?: number
          code: string
          confidence?: number | null
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          display_name?: string
          document_id?: string | null
          effective_at: string
          extraction_id?: string | null
          flag?: Database["public"]["Enums"]["observation_flag"]
          id?: string
          lab_high?: number | null
          lab_low?: number | null
          lab_name?: string | null
          needs_review?: boolean
          origin?: Database["public"]["Enums"]["observation_origin"]
          ref_high?: number | null
          ref_low?: number | null
          review_status?: Database["public"]["Enums"]["observation_review_status"]
          rule_version?: string
          subject_id: string
          superseded_at?: string | null
          supersedes_id?: string | null
          unit?: string | null
          unit_raw?: string | null
          value_num?: number | null
          value_raw?: number | null
          value_text?: string | null
        }
        Update: {
          catalog_version?: number
          code?: string
          confidence?: number | null
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          display_name?: string
          document_id?: string | null
          effective_at?: string
          extraction_id?: string | null
          flag?: Database["public"]["Enums"]["observation_flag"]
          id?: string
          lab_high?: number | null
          lab_low?: number | null
          lab_name?: string | null
          needs_review?: boolean
          origin?: Database["public"]["Enums"]["observation_origin"]
          ref_high?: number | null
          ref_low?: number | null
          review_status?: Database["public"]["Enums"]["observation_review_status"]
          rule_version?: string
          subject_id?: string
          superseded_at?: string | null
          supersedes_id?: string | null
          unit?: string | null
          unit_raw?: string | null
          value_num?: number | null
          value_raw?: number | null
          value_text?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "observations_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observations_extraction_id_fkey"
            columns: ["extraction_id"]
            isOneToOne: false
            referencedRelation: "extractions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observations_supersedes_id_fkey"
            columns: ["supersedes_id"]
            isOneToOne: false
            referencedRelation: "biomarker_series"
            referencedColumns: ["observation_id"]
          },
          {
            foreignKeyName: "observations_supersedes_id_fkey"
            columns: ["supersedes_id"]
            isOneToOne: false
            referencedRelation: "observations"
            referencedColumns: ["id"]
          },
        ]
      }
      organ_biomarker_map: {
        Row: {
          code: string
          created_at: string
          organ_id: string
          updated_at: string
          weight: number
        }
        Insert: {
          code: string
          created_at?: string
          organ_id: string
          updated_at?: string
          weight?: number
        }
        Update: {
          code?: string
          created_at?: string
          organ_id?: string
          updated_at?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: "organ_biomarker_map_code_fkey"
            columns: ["code"]
            isOneToOne: false
            referencedRelation: "biomarker_catalog"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "organ_biomarker_map_organ_id_fkey"
            columns: ["organ_id"]
            isOneToOne: false
            referencedRelation: "organs"
            referencedColumns: ["id"]
          },
        ]
      }
      organ_states: {
        Row: {
          computed_at: string
          confidence: number
          id: string
          inputs: Json
          organ_id: string
          rule_version: string
          state: Database["public"]["Enums"]["organ_state"]
          stress_score: number | null
          subject_id: string
        }
        Insert: {
          computed_at?: string
          confidence?: number
          id?: string
          inputs?: Json
          organ_id: string
          rule_version?: string
          state: Database["public"]["Enums"]["organ_state"]
          stress_score?: number | null
          subject_id: string
        }
        Update: {
          computed_at?: string
          confidence?: number
          id?: string
          inputs?: Json
          organ_id?: string
          rule_version?: string
          state?: Database["public"]["Enums"]["organ_state"]
          stress_score?: number | null
          subject_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organ_states_organ_id_fkey"
            columns: ["organ_id"]
            isOneToOne: false
            referencedRelation: "organs"
            referencedColumns: ["id"]
          },
        ]
      }
      organs: {
        Row: {
          anchor_x: number
          anchor_y: number
          created_at: string
          description_en: string
          description_it: string
          icon: string
          id: string
          name_en: string
          name_it: string
          sex: string
          sort_order: number
          updated_at: string
          version: string
        }
        Insert: {
          anchor_x: number
          anchor_y: number
          created_at?: string
          description_en?: string
          description_it?: string
          icon?: string
          id: string
          name_en: string
          name_it: string
          sex?: string
          sort_order: number
          updated_at?: string
          version?: string
        }
        Update: {
          anchor_x?: number
          anchor_y?: number
          created_at?: string
          description_en?: string
          description_it?: string
          icon?: string
          id?: string
          name_en?: string
          name_it?: string
          sex?: string
          sort_order?: number
          updated_at?: string
          version?: string
        }
        Relationships: []
      }
      platform_events: {
        Row: {
          at: string
          details: Json
          id: string
          kind: string
          source: string
          status: string
        }
        Insert: {
          at?: string
          details?: Json
          id?: string
          kind: string
          source: string
          status: string
        }
        Update: {
          at?: string
          details?: Json
          id?: string
          kind?: string
          source?: string
          status?: string
        }
        Relationships: []
      }
      platform_settings: {
        Row: {
          description: string | null
          is_public: boolean
          key: string
          updated_at: string
          updated_by: string | null
          value: Json
          version: number
        }
        Insert: {
          description?: string | null
          is_public?: boolean
          key: string
          updated_at?: string
          updated_by?: string | null
          value: Json
          version?: number
        }
        Update: {
          description?: string | null
          is_public?: boolean
          key?: string
          updated_at?: string
          updated_by?: string | null
          value?: Json
          version?: number
        }
        Relationships: []
      }
      platform_settings_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          id: string
          key: string
          value: Json
          version: number
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          id?: string
          key: string
          value: Json
          version: number
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          id?: string
          key?: string
          value?: Json
          version?: number
        }
        Relationships: []
      }
      prevention_calendar: {
        Row: {
          age_max: number | null
          age_min: number
          board_version: number
          category: string
          created_at: string
          id: string
          interval_months: number
          name_it: string
          notes: string | null
          organ_id: string | null
          sex: string
          status: Database["public"]["Enums"]["catalog_status"]
          updated_at: string
        }
        Insert: {
          age_max?: number | null
          age_min: number
          board_version?: number
          category: string
          created_at?: string
          id: string
          interval_months: number
          name_it: string
          notes?: string | null
          organ_id?: string | null
          sex: string
          status?: Database["public"]["Enums"]["catalog_status"]
          updated_at?: string
        }
        Update: {
          age_max?: number | null
          age_min?: number
          board_version?: number
          category?: string
          created_at?: string
          id?: string
          interval_months?: number
          name_it?: string
          notes?: string | null
          organ_id?: string | null
          sex?: string
          status?: Database["public"]["Enums"]["catalog_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "prevention_calendar_organ_id_fkey"
            columns: ["organ_id"]
            isOneToOne: false
            referencedRelation: "organs"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          birth_date: string | null
          country: string | null
          created_at: string
          data_region: Database["public"]["Enums"]["data_region"]
          deleted_at: string | null
          full_name: string | null
          gender: string | null
          id: string
          language: string
          managed_by: string | null
          onboarded_at: string | null
          timezone: string
          units: Database["public"]["Enums"]["unit_system"]
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          birth_date?: string | null
          country?: string | null
          created_at?: string
          data_region?: Database["public"]["Enums"]["data_region"]
          deleted_at?: string | null
          full_name?: string | null
          gender?: string | null
          id: string
          language?: string
          managed_by?: string | null
          onboarded_at?: string | null
          timezone?: string
          units?: Database["public"]["Enums"]["unit_system"]
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          birth_date?: string | null
          country?: string | null
          created_at?: string
          data_region?: Database["public"]["Enums"]["data_region"]
          deleted_at?: string | null
          full_name?: string | null
          gender?: string | null
          id?: string
          language?: string
          managed_by?: string | null
          onboarded_at?: string | null
          timezone?: string
          units?: Database["public"]["Enums"]["unit_system"]
          updated_at?: string
        }
        Relationships: []
      }
      questionnaire_answers: {
        Row: {
          answers: Json
          created_at: string
          id: string
          questionnaire_id: string
          subject_id: string
          submitted_at: string
          version: string
        }
        Insert: {
          answers: Json
          created_at?: string
          id?: string
          questionnaire_id: string
          subject_id: string
          submitted_at?: string
          version: string
        }
        Update: {
          answers?: Json
          created_at?: string
          id?: string
          questionnaire_id?: string
          subject_id?: string
          submitted_at?: string
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "questionnaire_answers_questionnaire_id_fkey"
            columns: ["questionnaire_id"]
            isOneToOne: false
            referencedRelation: "questionnaires"
            referencedColumns: ["id"]
          },
        ]
      }
      questionnaires: {
        Row: {
          created_at: string
          definition: Json
          id: string
          status: Database["public"]["Enums"]["rule_status"]
          title_key: string
          updated_at: string
          version: string
        }
        Insert: {
          created_at?: string
          definition?: Json
          id: string
          status?: Database["public"]["Enums"]["rule_status"]
          title_key: string
          updated_at?: string
          version: string
        }
        Update: {
          created_at?: string
          definition?: Json
          id?: string
          status?: Database["public"]["Enums"]["rule_status"]
          title_key?: string
          updated_at?: string
          version?: string
        }
        Relationships: []
      }
      questions: {
        Row: {
          answer: string | null
          answered_at: string | null
          answered_via: Database["public"]["Enums"]["question_channel"] | null
          body: string
          created_at: string
          doctor_email: string | null
          id: string
          share_link_id: string | null
          status: Database["public"]["Enums"]["question_status"]
          subject_id: string
          title: string
          updated_at: string
        }
        Insert: {
          answer?: string | null
          answered_at?: string | null
          answered_via?: Database["public"]["Enums"]["question_channel"] | null
          body: string
          created_at?: string
          doctor_email?: string | null
          id?: string
          share_link_id?: string | null
          status?: Database["public"]["Enums"]["question_status"]
          subject_id: string
          title: string
          updated_at?: string
        }
        Update: {
          answer?: string | null
          answered_at?: string | null
          answered_via?: Database["public"]["Enums"]["question_channel"] | null
          body?: string
          created_at?: string
          doctor_email?: string | null
          id?: string
          share_link_id?: string | null
          status?: Database["public"]["Enums"]["question_status"]
          subject_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "questions_share_link_id_fkey"
            columns: ["share_link_id"]
            isOneToOne: false
            referencedRelation: "share_links"
            referencedColumns: ["id"]
          },
        ]
      }
      rating_summaries: {
        Row: {
          rating_avg: number | null
          rating_count: number
          sub_avgs: Json
          target_id: string
          target_type: Database["public"]["Enums"]["review_target_type"]
          updated_at: string
        }
        Insert: {
          rating_avg?: number | null
          rating_count?: number
          sub_avgs?: Json
          target_id: string
          target_type: Database["public"]["Enums"]["review_target_type"]
          updated_at?: string
        }
        Update: {
          rating_avg?: number | null
          rating_count?: number
          sub_avgs?: Json
          target_id?: string
          target_type?: Database["public"]["Enums"]["review_target_type"]
          updated_at?: string
        }
        Relationships: []
      }
      recommendations: {
        Row: {
          calendar_id: string | null
          category: string
          code: string | null
          completed_at: string | null
          created_at: string
          dismiss_reason: string | null
          dismissed_at: string | null
          document_id: string | null
          due_at: string | null
          id: string
          interval_months: number
          organ_id: string | null
          origin: Database["public"]["Enums"]["recommendation_origin"]
          reason_key: string | null
          rule_version: string
          status: Database["public"]["Enums"]["recommendation_status"]
          subject_id: string
          title_key: string
          updated_at: string
        }
        Insert: {
          calendar_id?: string | null
          category: string
          code?: string | null
          completed_at?: string | null
          created_at?: string
          dismiss_reason?: string | null
          dismissed_at?: string | null
          document_id?: string | null
          due_at?: string | null
          id?: string
          interval_months?: number
          organ_id?: string | null
          origin?: Database["public"]["Enums"]["recommendation_origin"]
          reason_key?: string | null
          rule_version: string
          status?: Database["public"]["Enums"]["recommendation_status"]
          subject_id: string
          title_key: string
          updated_at?: string
        }
        Update: {
          calendar_id?: string | null
          category?: string
          code?: string | null
          completed_at?: string | null
          created_at?: string
          dismiss_reason?: string | null
          dismissed_at?: string | null
          document_id?: string | null
          due_at?: string | null
          id?: string
          interval_months?: number
          organ_id?: string | null
          origin?: Database["public"]["Enums"]["recommendation_origin"]
          reason_key?: string | null
          rule_version?: string
          status?: Database["public"]["Enums"]["recommendation_status"]
          subject_id?: string
          title_key?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recommendations_calendar_id_fkey"
            columns: ["calendar_id"]
            isOneToOne: false
            referencedRelation: "prevention_calendar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recommendations_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recommendations_organ_id_fkey"
            columns: ["organ_id"]
            isOneToOne: false
            referencedRelation: "organs"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          author_id: string
          body: string
          created_at: string
          helpful_count: number
          id: string
          moderated_at: string | null
          moderated_by: string | null
          moderation_note: string | null
          rating: number
          status: Database["public"]["Enums"]["review_status"]
          sub_ratings: Json
          target_id: string
          target_type: Database["public"]["Enums"]["review_target_type"]
          title: string | null
          updated_at: string
          verified: boolean
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string
          helpful_count?: number
          id?: string
          moderated_at?: string | null
          moderated_by?: string | null
          moderation_note?: string | null
          rating: number
          status?: Database["public"]["Enums"]["review_status"]
          sub_ratings?: Json
          target_id: string
          target_type: Database["public"]["Enums"]["review_target_type"]
          title?: string | null
          updated_at?: string
          verified?: boolean
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string
          helpful_count?: number
          id?: string
          moderated_at?: string | null
          moderated_by?: string | null
          moderation_note?: string | null
          rating?: number
          status?: Database["public"]["Enums"]["review_status"]
          sub_ratings?: Json
          target_id?: string
          target_type?: Database["public"]["Enums"]["review_target_type"]
          title?: string | null
          updated_at?: string
          verified?: boolean
        }
        Relationships: []
      }
      risk_scores: {
        Row: {
          computed_at: string
          factors: Json
          family: string
          id: string
          inputs: Json
          level: Database["public"]["Enums"]["risk_level"]
          projection_12m: Json | null
          rule_version: string
          score: number
          score_unit: string
          subject_id: string
        }
        Insert: {
          computed_at?: string
          factors?: Json
          family: string
          id?: string
          inputs?: Json
          level: Database["public"]["Enums"]["risk_level"]
          projection_12m?: Json | null
          rule_version: string
          score: number
          score_unit: string
          subject_id: string
        }
        Update: {
          computed_at?: string
          factors?: Json
          family?: string
          id?: string
          inputs?: Json
          level?: Database["public"]["Enums"]["risk_level"]
          projection_12m?: Json | null
          rule_version?: string
          score?: number
          score_unit?: string
          subject_id?: string
        }
        Relationships: []
      }
      rule_versions: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          created_at: string
          definition: Json
          id: string
          notes: string | null
          status: Database["public"]["Enums"]["rule_status"]
          type: string
          updated_at: string
          version: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          definition?: Json
          id?: string
          notes?: string | null
          status?: Database["public"]["Enums"]["rule_status"]
          type: string
          updated_at?: string
          version: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          definition?: Json
          id?: string
          notes?: string | null
          status?: Database["public"]["Enums"]["rule_status"]
          type?: string
          updated_at?: string
          version?: string
        }
        Relationships: []
      }
      share_link_opens: {
        Row: {
          id: string
          ip_hash: string | null
          opened_at: string
          outcome: Database["public"]["Enums"]["share_open_outcome"]
          share_link_id: string
          user_agent_hash: string | null
        }
        Insert: {
          id?: string
          ip_hash?: string | null
          opened_at?: string
          outcome: Database["public"]["Enums"]["share_open_outcome"]
          share_link_id: string
          user_agent_hash?: string | null
        }
        Update: {
          id?: string
          ip_hash?: string | null
          opened_at?: string
          outcome?: Database["public"]["Enums"]["share_open_outcome"]
          share_link_id?: string
          user_agent_hash?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "share_link_opens_share_link_id_fkey"
            columns: ["share_link_id"]
            isOneToOne: false
            referencedRelation: "share_links"
            referencedColumns: ["id"]
          },
        ]
      }
      share_links: {
        Row: {
          code: string
          created_at: string
          created_by: string
          expires_at: string
          failed_attempts: number
          id: string
          last_opened_at: string | null
          locked_until: string | null
          max_opens: number
          opens_count: number
          pin_hash: string
          revoked_at: string | null
          scope: Json
          subject_id: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by: string
          expires_at?: string
          failed_attempts?: number
          id?: string
          last_opened_at?: string | null
          locked_until?: string | null
          max_opens?: number
          opens_count?: number
          pin_hash: string
          revoked_at?: string | null
          scope?: Json
          subject_id: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string
          expires_at?: string
          failed_attempts?: number
          id?: string
          last_opened_at?: string | null
          locked_until?: string | null
          max_opens?: number
          opens_count?: number
          pin_hash?: string
          revoked_at?: string | null
          scope?: Json
          subject_id?: string
        }
        Relationships: []
      }
      share_open_attempts: {
        Row: {
          created_at: string
          id: string
          ip_hash: string
          outcome: string
        }
        Insert: {
          created_at?: string
          id?: string
          ip_hash: string
          outcome: string
        }
        Update: {
          created_at?: string
          id?: string
          ip_hash?: string
          outcome?: string
        }
        Relationships: []
      }
      subject_delegates: {
        Row: {
          accepted_at: string | null
          created_at: string
          created_by: string
          id: string
          invited_email: string
          relationship: string | null
          revoked_at: string | null
          role: Database["public"]["Enums"]["delegate_role"]
          scope: Json
          status: Database["public"]["Enums"]["delegate_status"]
          subject_id: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          created_by: string
          id?: string
          invited_email: string
          relationship?: string | null
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["delegate_role"]
          scope?: Json
          status?: Database["public"]["Enums"]["delegate_status"]
          subject_id: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string
          id?: string
          invited_email?: string
          relationship?: string | null
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["delegate_role"]
          scope?: Json
          status?: Database["public"]["Enums"]["delegate_status"]
          subject_id?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      symptoms: {
        Row: {
          code: string | null
          created_at: string
          created_by: string
          deleted_at: string | null
          free_text: string | null
          id: string
          notes: string | null
          occurred_at: string
          severity: number
          storage_path: string | null
          subject_id: string
          updated_at: string
        }
        Insert: {
          code?: string | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          free_text?: string | null
          id?: string
          notes?: string | null
          occurred_at: string
          severity: number
          storage_path?: string | null
          subject_id: string
          updated_at?: string
        }
        Update: {
          code?: string | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          free_text?: string | null
          id?: string
          notes?: string | null
          occurred_at?: string
          severity?: number
          storage_path?: string | null
          subject_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      threshold_overrides: {
        Row: {
          code: string
          created_at: string
          doctor_id: string
          high: number | null
          id: string
          low: number | null
          reason: string
          subject_id: string | null
          unit: string
          updated_at: string
          valid_from: string
          valid_until: string | null
          version: number
        }
        Insert: {
          code: string
          created_at?: string
          doctor_id: string
          high?: number | null
          id?: string
          low?: number | null
          reason: string
          subject_id?: string | null
          unit: string
          updated_at?: string
          valid_from?: string
          valid_until?: string | null
          version?: number
        }
        Update: {
          code?: string
          created_at?: string
          doctor_id?: string
          high?: number | null
          id?: string
          low?: number | null
          reason?: string
          subject_id?: string | null
          unit?: string
          updated_at?: string
          valid_from?: string
          valid_until?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "threshold_overrides_code_fkey"
            columns: ["code"]
            isOneToOne: false
            referencedRelation: "biomarker_catalog"
            referencedColumns: ["code"]
          },
        ]
      }
      treatment_tags: {
        Row: {
          kind: Database["public"]["Enums"]["treatment_tag_kind"]
          label_en: string
          label_it: string
          sort_order: number
          tag: string
        }
        Insert: {
          kind: Database["public"]["Enums"]["treatment_tag_kind"]
          label_en: string
          label_it: string
          sort_order?: number
          tag: string
        }
        Update: {
          kind?: Database["public"]["Enums"]["treatment_tag_kind"]
          label_en?: string
          label_it?: string
          sort_order?: number
          tag?: string
        }
        Relationships: []
      }
      treatments: {
        Row: {
          category: string | null
          conditions: string[]
          contraindications: Json
          course_weeks: number | null
          created_at: string
          created_by: string | null
          currency: string
          description_sections: Json
          doctor_id: string | null
          evidence_level: Database["public"]["Enums"]["treatment_evidence_level"]
          expected_outcome: string | null
          facility_id: string | null
          family: Database["public"]["Enums"]["treatment_family"]
          featured: boolean
          id: string
          is_demo: boolean
          media: Json
          modality: Database["public"]["Enums"]["treatment_modality"]
          price_from_cents: number | null
          price_notes: string | null
          price_to_cents: number | null
          published_at: string | null
          requirements: string | null
          scope: Database["public"]["Enums"]["treatment_scope"]
          search_vector: unknown
          session_minutes: number | null
          sessions_count: number | null
          ssn_covered: boolean
          status: Database["public"]["Enums"]["treatment_status"]
          summary: string | null
          tags: string[]
          title: string
          updated_at: string
          version: number
          waiting_days: number | null
        }
        Insert: {
          category?: string | null
          conditions?: string[]
          contraindications?: Json
          course_weeks?: number | null
          created_at?: string
          created_by?: string | null
          currency?: string
          description_sections?: Json
          doctor_id?: string | null
          evidence_level?: Database["public"]["Enums"]["treatment_evidence_level"]
          expected_outcome?: string | null
          facility_id?: string | null
          family?: Database["public"]["Enums"]["treatment_family"]
          featured?: boolean
          id?: string
          is_demo?: boolean
          media?: Json
          modality?: Database["public"]["Enums"]["treatment_modality"]
          price_from_cents?: number | null
          price_notes?: string | null
          price_to_cents?: number | null
          published_at?: string | null
          requirements?: string | null
          scope?: Database["public"]["Enums"]["treatment_scope"]
          search_vector?: unknown
          session_minutes?: number | null
          sessions_count?: number | null
          ssn_covered?: boolean
          status?: Database["public"]["Enums"]["treatment_status"]
          summary?: string | null
          tags?: string[]
          title: string
          updated_at?: string
          version?: number
          waiting_days?: number | null
        }
        Update: {
          category?: string | null
          conditions?: string[]
          contraindications?: Json
          course_weeks?: number | null
          created_at?: string
          created_by?: string | null
          currency?: string
          description_sections?: Json
          doctor_id?: string | null
          evidence_level?: Database["public"]["Enums"]["treatment_evidence_level"]
          expected_outcome?: string | null
          facility_id?: string | null
          family?: Database["public"]["Enums"]["treatment_family"]
          featured?: boolean
          id?: string
          is_demo?: boolean
          media?: Json
          modality?: Database["public"]["Enums"]["treatment_modality"]
          price_from_cents?: number | null
          price_notes?: string | null
          price_to_cents?: number | null
          published_at?: string | null
          requirements?: string | null
          scope?: Database["public"]["Enums"]["treatment_scope"]
          search_vector?: unknown
          session_minutes?: number | null
          sessions_count?: number | null
          ssn_covered?: boolean
          status?: Database["public"]["Enums"]["treatment_status"]
          summary?: string | null
          tags?: string[]
          title?: string
          updated_at?: string
          version?: number
          waiting_days?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "treatments_doctor_id_fkey"
            columns: ["doctor_id"]
            isOneToOne: false
            referencedRelation: "doctors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "treatments_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      ai_usage_daily: {
        Row: {
          cached: number | null
          calls: number | null
          cost_micro_usd: number | null
          day: string | null
          errors: number | null
          latency_avg_ms: number | null
          latency_p95_ms: number | null
          model_id: string | null
          ok: number | null
          task_id: string | null
          tokens_cached_in: number | null
          tokens_in: number | null
          tokens_out: number | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_usage_ledger_model_id_fkey"
            columns: ["model_id"]
            isOneToOne: false
            referencedRelation: "ai_models"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_usage_ledger_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "ai_tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      biomarker_series: {
        Row: {
          canonical_unit: string | null
          canonical_value: number | null
          code: string | null
          doctor_high: number | null
          doctor_low: number | null
          document_id: string | null
          effective_at: string | null
          extraction_id: string | null
          flag: Database["public"]["Enums"]["observation_flag"] | null
          institutional_high: number | null
          institutional_low: number | null
          lab_high: number | null
          lab_low: number | null
          lab_name: string | null
          observation_id: string | null
          origin: Database["public"]["Enums"]["observation_origin"] | null
          subject_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "observations_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observations_extraction_id_fkey"
            columns: ["extraction_id"]
            isOneToOne: false
            referencedRelation: "extractions"
            referencedColumns: ["id"]
          },
        ]
      }
      latest_organ_states: {
        Row: {
          computed_at: string | null
          confidence: number | null
          id: string | null
          inputs: Json | null
          organ_id: string | null
          rule_version: string | null
          state: Database["public"]["Enums"]["organ_state"] | null
          stress_score: number | null
          subject_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "organ_states_organ_id_fkey"
            columns: ["organ_id"]
            isOneToOne: false
            referencedRelation: "organs"
            referencedColumns: ["id"]
          },
        ]
      }
      latest_risk_scores: {
        Row: {
          computed_at: string | null
          factors: Json | null
          family: string | null
          id: string | null
          inputs: Json | null
          level: Database["public"]["Enums"]["risk_level"] | null
          projection_12m: Json | null
          rule_version: string | null
          score: number | null
          score_unit: string | null
          subject_id: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      account_close: { Args: { p_subject: string }; Returns: Json }
      admin_ai_calls: {
        Args: {
          p_from: string
          p_limit?: number
          p_offset?: number
          p_status?: string
          p_task?: string
          p_to: string
        }
        Returns: Json[]
      }
      admin_ai_tasks: { Args: never; Returns: Json[] }
      admin_audit: {
        Args: {
          p_action?: string
          p_actor?: string
          p_from: string
          p_limit?: number
          p_offset?: number
          p_to: string
        }
        Returns: Json[]
      }
      admin_events: {
        Args: {
          p_from: string
          p_kind?: string
          p_limit?: number
          p_offset?: number
          p_to: string
        }
        Returns: Json[]
      }
      admin_overview: { Args: never; Returns: Json }
      admin_prompts: { Args: { p_task: string }; Returns: Json[] }
      admin_read_audit: { Args: { p_name: string }; Returns: undefined }
      admin_rules: { Args: never; Returns: Json[] }
      admin_usage: {
        Args: { p_from: string; p_task?: string; p_to: string }
        Returns: Json[]
      }
      ai_log_call: {
        Args: {
          p_error_code: string
          p_function_name: string
          p_latency_ms: number
          p_model_id: string
          p_prompt_version: string
          p_request_id: string
          p_status: string
          p_subject_id: string
          p_task_id: string
          p_tokens_cached_in: number
          p_tokens_in: number
          p_tokens_out: number
        }
        Returns: {
          cost_micro_usd: number
          id: string
        }[]
      }
      ai_model_set: { Args: { p_id: string; p_patch: Json }; Returns: Json }
      ai_prompt_activate: { Args: { p_id: string }; Returns: undefined }
      ai_prompt_approve: { Args: { p_id: string }; Returns: undefined }
      ai_prompt_create: {
        Args: {
          p_notes?: string
          p_system_prompt: string
          p_task: string
          p_tool_schema: Json
          p_user_template: string
        }
        Returns: string
      }
      ai_prompt_record_test: {
        Args: { p_id: string; p_result: Json }
        Returns: undefined
      }
      ai_prompt_rollback: { Args: { p_task: string }; Returns: string }
      ai_task_config: { Args: { p_task: string }; Returns: Json }
      ai_task_set: { Args: { p_patch: Json; p_task: string }; Returns: Json }
      analysis_limit: { Args: { p_user_id: string }; Returns: number }
      analysis_usage: {
        Args: never
        Returns: {
          max: number
          used: number
        }[]
      }
      auto_confirm_extraction: {
        Args: { p_extraction_id: string }
        Returns: number
      }
      biomarker_catalog_for_subject: {
        Args: { p_subject: string }
        Returns: {
          code: string
          essential: boolean
          favorite: boolean
          flag: Database["public"]["Enums"]["observation_flag"]
          latest_at: string
          latest_value: number
          name_en: string
          name_it: string
          tracked: boolean
          unit_canonical: string
          value_count: number
        }[]
      }
      biomarker_episodes: {
        Args: { p_code: string; p_subject: string }
        Returns: {
          episode_end: string
          episode_start: string
          items: Json
          level: string
        }[]
      }
      biomarker_stats: {
        Args: {
          p_code: string
          p_from?: string
          p_subject: string
          p_to?: string
        }
        Returns: {
          average: number
          change_from_previous: number
          latest_at: string
          latest_value: number
          maximum: number
          minimum: number
          value_count: number
        }[]
      }
      can_access_document: { Args: { p_document_id: string }; Returns: boolean }
      can_access_subject: { Args: { subject_id: string }; Returns: boolean }
      check_forbidden_phrases: {
        Args: { p_text: string }
        Returns: {
          categories: string[]
          ids: number[]
          matched: boolean
        }[]
      }
      ckd_epi_2021: {
        Args: { p_age: number; p_scr: number; p_sex: string }
        Returns: {
          level: Database["public"]["Enums"]["risk_level"]
          score: number
        }[]
      }
      complete_recommendation: {
        Args: { p_document?: string; p_id: string }
        Returns: undefined
      }
      compute_organ_states: { Args: { p_subject: string }; Returns: number }
      compute_organ_states_all: { Args: never; Returns: number }
      compute_risk_scores: { Args: { p_subject: string }; Returns: number }
      compute_risk_scores_all: { Args: never; Returns: number }
      confirm_observation: {
        Args: {
          p_effective_at?: string
          p_observation_id: string
          p_outcome?: string
          p_unit?: string
          p_value_num?: number
          p_value_text?: string
        }
        Returns: string
      }
      confirm_observation_internal: {
        Args: {
          p_actor: string
          p_effective_at?: string
          p_observation_id: string
          p_outcome?: string
          p_unit?: string
          p_value_num?: number
          p_value_text?: string
        }
        Returns: string
      }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      data_export_finish: {
        Args: {
          p_bytes?: number
          p_error?: string
          p_file_count?: number
          p_id: string
          p_path?: string
          p_status: Database["public"]["Enums"]["data_export_status"]
          p_truncated?: boolean
        }
        Returns: undefined
      }
      data_export_latest: { Args: { p_subject: string }; Returns: Json }
      data_export_request: { Args: { p_subject: string }; Returns: string }
      delegate_accept: { Args: { p_id: string }; Returns: Json }
      delegate_invite: {
        Args: { p_email: string; p_scope?: Json; p_subject: string }
        Returns: Json
      }
      delegate_revoke: { Args: { p_id: string }; Returns: Json }
      dev_call: {
        Args: { p_bearer?: string; p_body: Json; p_path: string }
        Returns: number
      }
      dismiss_recommendation: {
        Args: { p_id: string; p_reason?: string }
        Returns: undefined
      }
      doctor_upsert: { Args: { p_payload: Json }; Returns: string }
      document_limit: { Args: { p_user_id: string }; Returns: number }
      document_usage: {
        Args: never
        Returns: {
          max: number
          used: number
        }[]
      }
      documents_pending_extraction: {
        Args: { p_limit?: number }
        Returns: {
          document_id: string
          subject_id: string
        }[]
      }
      dossier_build: {
        Args: { p_scope?: Json; p_share_link_id?: string; p_subject: string }
        Returns: string
      }
      dossier_latest: { Args: { p_subject: string }; Returns: Json }
      dossier_snapshot_set_pdf: {
        Args: { p_path: string; p_snapshot: string }
        Returns: undefined
      }
      emergency_card_public: { Args: { p_token: string }; Returns: Json }
      emergency_card_regenerate_token: {
        Args: { p_subject: string }
        Returns: string
      }
      emergency_card_upsert: {
        Args: { p_payload: Json; p_subject: string }
        Returns: Json
      }
      enqueue_pending_extractions: {
        Args: { p_limit?: number }
        Returns: number
      }
      expire_stale_document_uploads: { Args: never; Returns: number }
      explanation_context: {
        Args: { p_subject: string; p_target_id: string; p_target_type: string }
        Returns: Json
      }
      explanation_lookup: {
        Args: {
          p_inputs_hash: string
          p_lang: string
          p_level: string
          p_subject: string
          p_target_id: string
          p_target_type: string
        }
        Returns: {
          explanation_id: string
          explanation_lang: string
          explanation_level: string
          explanation_text: string
          generated_at: string
          model: string
          prompt_version: string
        }[]
      }
      explanation_save: {
        Args: {
          p_cost_micro_usd: number
          p_filter_ids: number[]
          p_filter_passed: boolean
          p_inputs_hash: string
          p_lang: string
          p_level: string
          p_model: string
          p_prompt_version: string
          p_subject: string
          p_target_id: string
          p_target_type: string
          p_text: string
          p_tokens_in: number
          p_tokens_out: number
        }
        Returns: {
          explanation_id: string
          saved_at: string
        }[]
      }
      explanation_usage: {
        Args: { p_subject: string }
        Returns: {
          max_per_day: number
          used: number
        }[]
      }
      facets_for_treatments: {
        Args: {
          p_city?: string
          p_conditions?: string[]
          p_duration_bucket?: string
          p_family?: string[]
          p_max_price_cents?: number
          p_min_rating?: number
          p_modality?: string[]
          p_query?: string
          p_scope?: string[]
          p_tags?: string[]
        }
        Returns: Json
      }
      facility_upsert: { Args: { p_payload: Json }; Returns: string }
      family_managed_limit: { Args: never; Returns: number }
      family_member_register: {
        Args: {
          p_birth_date?: string
          p_declaration_version: string
          p_full_name: string
          p_gender?: string
          p_owner: string
          p_relationship?: string
          p_subject: string
        }
        Returns: Json
      }
      family_member_remove: { Args: { p_subject: string }; Returns: Json }
      family_member_update: {
        Args: {
          p_birth_date?: string
          p_full_name?: string
          p_gender?: string
          p_relationship?: string
          p_subject: string
        }
        Returns: Json
      }
      featured_treatments: {
        Args: { p_limit?: number }
        Returns: {
          cover_url: string
          doctor_display_name: string
          evidence_level: string
          facility_city: string
          facility_name: string
          family: string
          id: string
          is_demo: boolean
          modality: string
          price_from_cents: number
          rating_avg: number
          rating_count: number
          scope: string
          session_minutes: number
          summary: string
          title: string
        }[]
      }
      findrisc_score: {
        Args: { p: Json }
        Returns: {
          level: Database["public"]["Enums"]["risk_level"]
          score: number
        }[]
      }
      fracture_checklist_score: {
        Args: { p: Json }
        Returns: {
          level: Database["public"]["Enums"]["risk_level"]
          score: number
        }[]
      }
      has_role: {
        Args: { check_role: Database["public"]["Enums"]["app_role"] }
        Returns: boolean
      }
      home_snapshot: { Args: { p_subject: string }; Returns: Json }
      log_audit: {
        Args: {
          action: string
          device?: string
          subject_id?: string
          target_id?: string
          target_table?: string
        }
        Returns: string
      }
      m24_display_name_initial: { Args: { p_full: string }; Returns: string }
      m24_emergency_text_array: {
        Args: { p_doc: Json; p_key: string }
        Returns: string[]
      }
      m24_family_member_remove_internal: {
        Args: { p_actor: string; p_subject: string }
        Returns: Json
      }
      m24_has_url: { Args: { p_text: string }; Returns: boolean }
      m24_jsonb_bool: {
        Args: { p_default: boolean; p_doc: Json; p_key: string }
        Returns: boolean
      }
      m24_jsonb_int: { Args: { p_doc: Json; p_key: string }; Returns: number }
      m24_jsonb_keys_subset: {
        Args: { p_allowed: string[]; p_doc: Json }
        Returns: boolean
      }
      m24_jsonb_text: { Args: { p_doc: Json; p_key: string }; Returns: string }
      m24_jsonb_text_array: {
        Args: { p_doc: Json; p_key: string }
        Returns: string[]
      }
      m24_max_contraindication: { Args: { p_doc: Json }; Returns: string }
      m24_question_for_update: {
        Args: { p_id: string }
        Returns: {
          answer: string | null
          answered_at: string | null
          answered_via: Database["public"]["Enums"]["question_channel"] | null
          body: string
          created_at: string
          doctor_email: string | null
          id: string
          share_link_id: string | null
          status: Database["public"]["Enums"]["question_status"]
          subject_id: string
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "questions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      m24_random_code: { Args: never; Returns: string }
      m24_refresh_rating_summary: {
        Args: {
          p_id: string
          p_type: Database["public"]["Enums"]["review_target_type"]
        }
        Returns: undefined
      }
      m24_require_admin: { Args: never; Returns: string }
      m24_require_auth: { Args: never; Returns: string }
      m24_review_author_label: { Args: { p_author: string }; Returns: string }
      m24_seed_0020_treatments_demo: { Args: never; Returns: undefined }
      m24_target_exists: {
        Args: { p_id: string; p_type: string }
        Returns: boolean
      }
      m24_treatment_cover_url: { Args: { p_media: Json }; Returns: string }
      m24_treatment_search_doc: {
        Args: {
          p_category: string
          p_conditions: string[]
          p_sections: Json
          p_summary: string
          p_tags: string[]
          p_title: string
        }
        Returns: unknown
      }
      m24_treatments_filtered: {
        Args: {
          p_city?: string
          p_conditions?: string[]
          p_duration_bucket?: string
          p_family?: string[]
          p_max_price_cents?: number
          p_min_rating?: number
          p_modality?: string[]
          p_query?: string
          p_scope?: string[]
          p_tags?: string[]
        }
        Returns: {
          course_weeks: number
          cover_url: string
          created_at: string
          doctor_display_name: string
          doctor_id: string
          evidence_level: string
          facility_city: string
          facility_id: string
          facility_name: string
          family: string
          featured: boolean
          id: string
          is_demo: boolean
          modality: string
          price_from_cents: number
          price_to_cents: number
          published_at: string
          rank: number
          rating_avg: number
          rating_count: number
          scope: string
          session_minutes: number
          sessions_count: number
          summary: string
          title: string
          waiting_days: number
        }[]
      }
      m24_valid_contraindications: { Args: { p_doc: Json }; Returns: boolean }
      m24_valid_emergency_contacts: { Args: { p_doc: Json }; Returns: boolean }
      m24_valid_media: { Args: { p_doc: Json }; Returns: boolean }
      m24_valid_pin: { Args: { p_pin: string }; Returns: boolean }
      m24_valid_public_fields: { Args: { p_doc: Json }; Returns: boolean }
      m24_valid_share_scope: { Args: { p_doc: Json }; Returns: boolean }
      m24_valid_sub_ratings: { Args: { p_doc: Json }; Returns: boolean }
      moderate_review: {
        Args: { p_id: string; p_note?: string; p_status: string }
        Returns: undefined
      }
      my_pending_invitations: {
        Args: never
        Returns: {
          created_at: string
          id: string
          invited_by: string
          relationship: string
          subject_id: string
          subject_name: string
        }[]
      }
      my_subjects: {
        Args: never
        Returns: {
          full_name: string
          managed: boolean
          relationship: string
          role: Database["public"]["Enums"]["delegate_role"]
          subject_id: string
        }[]
      }
      normalize_for_filter: { Args: { p_text: string }; Returns: string }
      normalize_unit: {
        Args: { p_code: string; p_unit: string; p_value: number }
        Returns: {
          converted: boolean
          unit: string
          value_num: number
        }[]
      }
      observations_export: {
        Args: { p_subject: string }
        Returns: {
          code: string
          doctor_high: number
          doctor_low: number
          document_id: string
          effective_at: string
          flag: Database["public"]["Enums"]["observation_flag"]
          institutional_high: number
          institutional_low: number
          lab_high: number
          lab_low: number
          lab_name: string
          origin: Database["public"]["Enums"]["observation_origin"]
          unit: string
          value: number
        }[]
      }
      organ_biomarkers: {
        Args: { p_organ: string; p_subject: string }
        Returns: {
          code: string
          flag: Database["public"]["Enums"]["observation_flag"]
          is_present: boolean
          latest_at: string
          latest_value: number
          name_en: string
          name_it: string
          unit_canonical: string
          weight: number
        }[]
      }
      organ_comparison: {
        Args: { p_organ: string; p_subject: string }
        Returns: {
          at_12m: string
          at_6m: string
          current_at: string
          current_state: Database["public"]["Enums"]["organ_state"]
          current_stress_score: number
          state_12m: Database["public"]["Enums"]["organ_state"]
          state_6m: Database["public"]["Enums"]["organ_state"]
          stress_score_12m: number
          stress_score_6m: number
        }[]
      }
      organ_episodes: {
        Args: { p_organ: string; p_subject: string }
        Returns: {
          episode_end: string
          episode_start: string
        }[]
      }
      organ_history: {
        Args: { p_organ: string; p_subject: string }
        Returns: {
          computed_at: string
          confidence: number
          id: string
          inputs: Json
          rule_version: string
          state: Database["public"]["Enums"]["organ_state"]
          stress_score: number
        }[]
      }
      organ_ids_for_catalog_key: { Args: { p_key: string }; Returns: string[] }
      organ_overview: {
        Args: { p_subject: string }
        Returns: {
          anchor_x: number
          anchor_y: number
          computed_at: string
          confidence: number
          description_en: string
          description_it: string
          icon: string
          mapped_codes: number
          name_en: string
          name_it: string
          organ_id: string
          present_codes: number
          sex: string
          sort_order: number
          state: Database["public"]["Enums"]["organ_state"]
          stress_score: number
        }[]
      }
      platform_event: {
        Args: {
          p_details?: Json
          p_kind: string
          p_source: string
          p_status: string
        }
        Returns: string
      }
      platform_setting: { Args: { p_key: string }; Returns: Json }
      platform_setting_set: {
        Args: { p_description?: string; p_key: string; p_value: Json }
        Returns: number
      }
      purge_deleted_accounts: { Args: never; Returns: number }
      purge_share_open_attempts: { Args: never; Returns: number }
      purge_subject_data: { Args: { p_subject: string }; Returns: Json }
      question_answer_via_link: {
        Args: {
          p_answer: string
          p_question_id: string
          p_share_link_id: string
        }
        Returns: undefined
      }
      question_close: { Args: { p_id: string }; Returns: undefined }
      question_create: {
        Args: {
          p_body: string
          p_doctor_email?: string
          p_share_link_id?: string
          p_subject: string
          p_title: string
        }
        Returns: string
      }
      question_delete: { Args: { p_id: string }; Returns: undefined }
      question_record_answer: {
        Args: { p_answer: string; p_id: string }
        Returns: undefined
      }
      question_send: { Args: { p_id: string }; Returns: undefined }
      question_update: {
        Args: { p_body: string; p_id: string; p_title: string }
        Returns: undefined
      }
      questions_for_link: { Args: { p_share_link_id: string }; Returns: Json }
      rebuild_organ_biomarker_map: { Args: never; Returns: number }
      record_consent: {
        Args: {
          consent_locale?: string
          consent_type: Database["public"]["Enums"]["consent_type"]
          consent_version: string
          is_granted: boolean
        }
        Returns: string
      }
      refresh_recommendations: { Args: { p_subject: string }; Returns: number }
      reopen_recommendation: { Args: { p_id: string }; Returns: undefined }
      resolve_flag: {
        Args: { p_code: string; p_subject_id: string; p_value: number }
        Returns: Database["public"]["Enums"]["observation_flag"]
      }
      resolve_reference: {
        Args: { p_code: string; p_subject_id: string }
        Returns: {
          board_version: number
          ref_high: number
          ref_low: number
          safety_high: number
          safety_low: number
        }[]
      }
      resolve_thresholds: {
        Args: { p_code: string; p_subject: string }
        Returns: {
          board_version: number
          doctor_high: number
          doctor_id: string
          doctor_low: number
          doctor_reason: string
          institutional_high: number
          institutional_low: number
          laboratory_high: number
          laboratory_low: number
          unit: string
        }[]
      }
      reviews_for_target: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_target_id: string
          p_target_type: string
        }
        Returns: {
          author_label: string
          body: string
          created_at: string
          helpful_count: number
          id: string
          rating: number
          sub_ratings: Json
          target_id: string
          target_type: string
          title: string
          total_count: number
          verified: boolean
        }[]
      }
      rule_version_set_status: {
        Args: { p_id: string; p_status: string }
        Returns: undefined
      }
      run_compute_organ_states_all_logged: { Args: never; Returns: number }
      run_compute_risk_scores_all_logged: { Args: never; Returns: number }
      run_enqueue_pending_extractions_logged: {
        Args: { p_limit?: number }
        Returns: number
      }
      run_expire_stale_document_uploads_logged: { Args: never; Returns: number }
      run_platform_health_logged: { Args: never; Returns: string }
      run_purge_deleted_accounts_logged: { Args: never; Returns: number }
      run_purge_share_open_attempts_logged: { Args: never; Returns: number }
      score2_risk: {
        Args: {
          p_age: number
          p_hdl_mmol: number
          p_sbp: number
          p_sex: string
          p_smoker: boolean
          p_tc_mmol: number
        }
        Returns: {
          level: Database["public"]["Enums"]["risk_level"]
          score: number
        }[]
      }
      search_treatments: {
        Args: {
          p_city?: string
          p_conditions?: string[]
          p_duration_bucket?: string
          p_family?: string[]
          p_limit?: number
          p_max_price_cents?: number
          p_min_rating?: number
          p_modality?: string[]
          p_offset?: number
          p_query?: string
          p_scope?: string[]
          p_sort?: string
          p_tags?: string[]
        }
        Returns: {
          cover_url: string
          doctor_display_name: string
          evidence_level: string
          facility_city: string
          facility_name: string
          family: string
          featured: boolean
          id: string
          is_demo: boolean
          modality: string
          price_from_cents: number
          rating_avg: number
          rating_count: number
          scope: string
          session_minutes: number
          summary: string
          title: string
          total_count: number
        }[]
      }
      share_link_create: {
        Args: {
          p_expires_in?: string
          p_max_opens?: number
          p_pin: string
          p_scope?: Json
          p_subject: string
        }
        Returns: Json
      }
      share_link_is_active: { Args: { p_id: string }; Returns: boolean }
      share_link_open: {
        Args: {
          p_code: string
          p_ip_hash?: string
          p_pin: string
          p_ua_hash?: string
        }
        Returns: Json
      }
      share_link_revoke: { Args: { p_id: string }; Returns: undefined }
      share_links_for_subject: { Args: { p_subject: string }; Returns: Json }
      share_open_rate_check: { Args: { p_ip_hash: string }; Returns: boolean }
      soft_delete_account: { Args: never; Returns: undefined }
      soft_delete_document: {
        Args: { p_document_id: string }
        Returns: undefined
      }
      soft_delete_symptom: {
        Args: { p_symptom_id: string }
        Returns: undefined
      }
      start_extraction: { Args: { p_document_id: string }; Returns: string }
      subject_sex: { Args: { p_subject: string }; Returns: string }
      subject_view_log: { Args: { p_subject: string }; Returns: boolean }
      submit_review: {
        Args: {
          p_body?: string
          p_rating: number
          p_sub_ratings?: Json
          p_target_id: string
          p_target_type: string
          p_title?: string
        }
        Returns: string
      }
      toggle_favorite: {
        Args: { p_target_id: string; p_target_type: string }
        Returns: boolean
      }
      treatment_compare: {
        Args: { p_ids: string[] }
        Returns: {
          course_weeks: number
          doctor_display_name: string
          evidence_level: string
          facility_name: string
          id: string
          max_contraindication_severity: string
          modality: string
          price_from_cents: number
          price_to_cents: number
          rating_avg: number
          rating_count: number
          session_minutes: number
          sessions_count: number
          title: string
          waiting_days: number
        }[]
      }
      treatment_detail: { Args: { p_id: string }; Returns: Json }
      treatment_set_status: {
        Args: { p_id: string; p_status: string }
        Returns: undefined
      }
      treatment_upsert: { Args: { p_payload: Json }; Returns: string }
      withdraw_review: { Args: { p_id: string }; Returns: undefined }
    }
    Enums: {
      alert_level: "lab" | "institutional" | "doctor"
      alert_type: "info" | "warning" | "critical"
      app_role:
        | "user"
        | "caregiver"
        | "doctor"
        | "facility_admin"
        | "facility_staff"
        | "board"
        | "admin"
      catalog_status: "draft" | "validated" | "retired"
      consent_type:
        | "health_data"
        | "ai_processing"
        | "marketing"
        | "sharing"
        | "research"
        | "nutrition_diary"
        | "authored_content"
      data_export_status: "pending" | "ready" | "failed" | "expired"
      data_region: "eu" | "us"
      delegate_role: "owner" | "caregiver"
      delegate_status: "invited" | "active" | "revoked"
      doctor_role:
        | "medico"
        | "medico_dietologo"
        | "dietista"
        | "biologo_nutrizionista"
        | "fisioterapista"
        | "altro"
      document_category:
        | "exams"
        | "reports"
        | "prescriptions"
        | "radiology"
        | "vaccinations"
        | "invoices"
        | "consents"
        | "cards"
        | "other"
      document_source:
        | "camera"
        | "gallery"
        | "pdf"
        | "share_sheet"
        | "email"
        | "fse"
      document_status:
        | "uploading"
        | "uploaded"
        | "processing"
        | "analyzed"
        | "needs_review"
        | "failed"
      extraction_status:
        | "queued"
        | "classifying"
        | "extracting"
        | "normalizing"
        | "done"
        | "needs_review"
        | "failed"
      facility_kind:
        | "ospedale"
        | "clinica"
        | "poliambulatorio"
        | "studio"
        | "centro_riabilitazione"
        | "farmacia"
        | "altro"
      observation_flag:
        | "below"
        | "within"
        | "above"
        | "critical_low"
        | "critical_high"
        | "unknown"
      observation_origin: "document" | "manual" | "device"
      observation_review_status: "pending" | "confirmed" | "discarded"
      organ_state: "ok" | "monitor" | "attention" | "missing"
      question_channel: "link" | "app"
      question_status: "draft" | "sent" | "answered" | "closed"
      recommendation_origin: "rule" | "doctor"
      recommendation_status: "open" | "done" | "dismissed"
      review_status: "pending" | "approved" | "rejected" | "withdrawn"
      review_target_type: "treatment" | "doctor" | "facility"
      risk_level: "low" | "medium" | "high"
      rule_status: "draft" | "active" | "retired"
      share_open_outcome:
        | "ok"
        | "wrong_pin"
        | "expired"
        | "revoked"
        | "locked"
        | "exhausted"
      treatment_evidence_level:
        | "linee_guida"
        | "studi_clinici"
        | "osservazionale"
        | "esperienziale"
        | "non_valutato"
      treatment_family: "tradizionale" | "sperimentale" | "naturale" | "altro"
      treatment_modality: "presenza" | "online" | "ibrido" | "domicilio"
      treatment_scope:
        | "riabilitazione"
        | "prevenzione"
        | "benessere"
        | "diagnostica"
        | "terapia"
      treatment_status: "draft" | "verified" | "published" | "retired"
      treatment_tag_kind: "categoria" | "patologia" | "obiettivo" | "modalita"
      unit_system: "mg_dl" | "mmol_l"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      alert_level: ["lab", "institutional", "doctor"],
      alert_type: ["info", "warning", "critical"],
      app_role: [
        "user",
        "caregiver",
        "doctor",
        "facility_admin",
        "facility_staff",
        "board",
        "admin",
      ],
      catalog_status: ["draft", "validated", "retired"],
      consent_type: [
        "health_data",
        "ai_processing",
        "marketing",
        "sharing",
        "research",
        "nutrition_diary",
        "authored_content",
      ],
      data_export_status: ["pending", "ready", "failed", "expired"],
      data_region: ["eu", "us"],
      delegate_role: ["owner", "caregiver"],
      delegate_status: ["invited", "active", "revoked"],
      doctor_role: [
        "medico",
        "medico_dietologo",
        "dietista",
        "biologo_nutrizionista",
        "fisioterapista",
        "altro",
      ],
      document_category: [
        "exams",
        "reports",
        "prescriptions",
        "radiology",
        "vaccinations",
        "invoices",
        "consents",
        "cards",
        "other",
      ],
      document_source: [
        "camera",
        "gallery",
        "pdf",
        "share_sheet",
        "email",
        "fse",
      ],
      document_status: [
        "uploading",
        "uploaded",
        "processing",
        "analyzed",
        "needs_review",
        "failed",
      ],
      extraction_status: [
        "queued",
        "classifying",
        "extracting",
        "normalizing",
        "done",
        "needs_review",
        "failed",
      ],
      facility_kind: [
        "ospedale",
        "clinica",
        "poliambulatorio",
        "studio",
        "centro_riabilitazione",
        "farmacia",
        "altro",
      ],
      observation_flag: [
        "below",
        "within",
        "above",
        "critical_low",
        "critical_high",
        "unknown",
      ],
      observation_origin: ["document", "manual", "device"],
      observation_review_status: ["pending", "confirmed", "discarded"],
      organ_state: ["ok", "monitor", "attention", "missing"],
      question_channel: ["link", "app"],
      question_status: ["draft", "sent", "answered", "closed"],
      recommendation_origin: ["rule", "doctor"],
      recommendation_status: ["open", "done", "dismissed"],
      review_status: ["pending", "approved", "rejected", "withdrawn"],
      review_target_type: ["treatment", "doctor", "facility"],
      risk_level: ["low", "medium", "high"],
      rule_status: ["draft", "active", "retired"],
      share_open_outcome: [
        "ok",
        "wrong_pin",
        "expired",
        "revoked",
        "locked",
        "exhausted",
      ],
      treatment_evidence_level: [
        "linee_guida",
        "studi_clinici",
        "osservazionale",
        "esperienziale",
        "non_valutato",
      ],
      treatment_family: ["tradizionale", "sperimentale", "naturale", "altro"],
      treatment_modality: ["presenza", "online", "ibrido", "domicilio"],
      treatment_scope: [
        "riabilitazione",
        "prevenzione",
        "benessere",
        "diagnostica",
        "terapia",
      ],
      treatment_status: ["draft", "verified", "published", "retired"],
      treatment_tag_kind: ["categoria", "patologia", "obiettivo", "modalita"],
      unit_system: ["mg_dl", "mmol_l"],
    },
  },
} as const
