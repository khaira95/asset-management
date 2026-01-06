export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      assets: {
        Row: {
          id: number
          asset_name: string
          serial_number: string | null
          category_id: number | null
          status: 'active' | 'maintenance' | 'inactive' | 'disposed'
          staff_id: number | null
          purchase_date: string | null
          description: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: number
          asset_name: string
          serial_number?: string | null
          category_id?: number | null
          status?: 'active' | 'maintenance' | 'inactive' | 'disposed'
          staff_id?: number | null
          purchase_date?: string | null
          description?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: number
          asset_name?: string
          serial_number?: string | null
          category_id?: number | null
          status?: 'active' | 'maintenance' | 'inactive' | 'disposed'
          staff_id?: number | null
          purchase_date?: string | null
          description?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      categories: {
        Row: {
          id: number
          name: string
          code: string
          description: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: number
          name: string
          code: string
          description?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: number
          name?: string
          code?: string
          description?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      staff: {
        Row: {
          id: number
          name: string
          staff_id: string
          position: string | null
          phone_number: string | null
          email: string | null
          location_id: number | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: number
          name: string
          staff_id: string
          position?: string | null
          phone_number?: string | null
          email?: string | null
          location_id?: number | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: number
          name?: string
          staff_id?: string
          position?: string | null
          phone_number?: string | null
          email?: string | null
          location_id?: number | null
          created_at?: string
          updated_at?: string
        }
      }
      locations: {
        Row: {
          id: number
          name: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: number
          name: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: number
          name?: string
          created_at?: string
          updated_at?: string
        }
      }
      licenses: {
        Row: {
          id: number
          name: string
          license_key: string
          type: string | null
          purchased_date: string | null
          expiration_date: string | null
          seats_total: number
          seats_used: number
          cost: number | null
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: number
          name: string
          license_key: string
          type?: string | null
          purchased_date?: string | null
          expiration_date?: string | null
          seats_total?: number
          seats_used?: number
          cost?: number | null
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: number
          name?: string
          license_key?: string
          type?: string | null
          purchased_date?: string | null
          expiration_date?: string | null
          seats_total?: number
          seats_used?: number
          cost?: number | null
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      asset_history: {
        Row: {
          id: number
          asset_id: number
          user_id: string
          field_name: string
          old_value: string | null
          new_value: string | null
          change_type: string
          created_at: string
        }
        Insert: {
          id?: number
          asset_id: number
          user_id: string
          field_name: string
          old_value?: string | null
          new_value?: string | null
          change_type: string
          created_at?: string
        }
        Update: {
          id?: number
          asset_id?: number
          user_id?: string
          field_name?: string
          old_value?: string | null
          new_value?: string | null
          change_type?: string
          created_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      asset_status: 'active' | 'maintenance' | 'inactive' | 'disposed'
    }
  }
}

// Helper types
export type Asset = Database['public']['Tables']['assets']['Row']
export type Category = Database['public']['Tables']['categories']['Row']
export type Staff = Database['public']['Tables']['staff']['Row']
export type Location = Database['public']['Tables']['locations']['Row']
export type License = Database['public']['Tables']['licenses']['Row']
export type AssetHistory = Database['public']['Tables']['asset_history']['Row']
