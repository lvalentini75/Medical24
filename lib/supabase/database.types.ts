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
          onboarded_at?: string | null
          timezone?: string
          units?: Database["public"]["Enums"]["unit_system"]
          updated_at?: string
        }
        Relationships: []
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
      [_ in never]: never
    }
    Functions: {
      can_access_document: { Args: { p_document_id: string }; Returns: boolean }
      can_access_subject: { Args: { subject_id: string }; Returns: boolean }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      document_limit: { Args: { p_user_id: string }; Returns: number }
      expire_stale_document_uploads: { Args: never; Returns: number }
      has_role: {
        Args: { check_role: Database["public"]["Enums"]["app_role"] }
        Returns: boolean
      }
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
      purge_deleted_accounts: { Args: never; Returns: number }
      record_consent: {
        Args: {
          consent_locale?: string
          consent_type: Database["public"]["Enums"]["consent_type"]
          consent_version: string
          is_granted: boolean
        }
        Returns: string
      }
      soft_delete_account: { Args: never; Returns: undefined }
    }
    Enums: {
      app_role:
        | "user"
        | "caregiver"
        | "doctor"
        | "facility_admin"
        | "facility_staff"
        | "board"
        | "admin"
      consent_type:
        | "health_data"
        | "ai_processing"
        | "marketing"
        | "sharing"
        | "research"
        | "nutrition_diary"
        | "authored_content"
      data_region: "eu" | "us"
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
      app_role: [
        "user",
        "caregiver",
        "doctor",
        "facility_admin",
        "facility_staff",
        "board",
        "admin",
      ],
      consent_type: [
        "health_data",
        "ai_processing",
        "marketing",
        "sharing",
        "research",
        "nutrition_diary",
        "authored_content",
      ],
      data_region: ["eu", "us"],
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
      unit_system: ["mg_dl", "mmol_l"],
    },
  },
} as const
