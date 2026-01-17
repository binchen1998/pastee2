// Dashboard Types
export interface DayStats {
  date: string;
  new_registrations: number;
  active_users: number;
  total_users: number;
}

export interface GrowthRates {
  registrations: number;
  active_users: number;
}

export interface DashboardSummary {
  total_users: number;
  today_registrations: number;
  today_active: number;
  week_avg_registrations: number;
  week_avg_active: number;
}

export interface DashboardResponse {
  today?: DayStats;
  yesterday?: DayStats;
  growth_rates?: GrowthRates;
  recent_week?: DailyStats[];
  recent_month?: DailyStats[];
  summary?: DashboardSummary;
}

export interface DailyStats {
  date: string;
  new_registrations: number;
  active_users: number;
  total_users: number;
}

// User Types
export interface AdminUser {
  id: number;
  email: string;
  created_at: string;
  last_active: string;
  is_verified: boolean;
  storage_used: number;
  storage_limit: number;
}

export interface UserListResponse {
  users: AdminUser[];
  total: number;
  page: number;
  page_size: number;
}

// Version Types
export interface VersionInfo {
  id: number;
  version: string;
  release_notes: string;
  download_url: string;
  is_mandatory: boolean;
  created_at: string;
}

export interface CreateVersionRequest {
  version: string;
  release_notes: string;
  download_url: string;
  is_mandatory: boolean;
}

// Auth Types
export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: {
    id: number;
    email: string;
  };
}
