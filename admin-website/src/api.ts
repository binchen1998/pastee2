import type {
  DashboardResponse,
  UserListResponse,
  VersionInfo,
  CreateVersionRequest,
  LoginRequest,
  LoginResponse,
} from './types';

const BASE_URL = 'https://api.pastee-app.com';

class ApiService {
  private token: string | null = null;

  constructor() {
    this.token = localStorage.getItem('admin_token');
  }

  setToken(token: string | null) {
    this.token = token;
    if (token) {
      localStorage.setItem('admin_token', token);
    } else {
      localStorage.removeItem('admin_token');
    }
  }

  getToken(): string | null {
    return this.token;
  }

  isAuthenticated(): boolean {
    return !!this.token;
  }

  private async request<T>(
    method: string,
    endpoint: string,
    body?: unknown
  ): Promise<T> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(`${BASE_URL}${endpoint}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });

    if (response.status === 401) {
      this.setToken(null);
      window.location.href = '/login';
      throw new Error('Unauthorized');
    }

    if (!response.ok) {
      const error = await response.text();
      throw new Error(error || `Request failed with status ${response.status}`);
    }

    // Handle empty responses
    const text = await response.text();
    if (!text) return {} as T;
    
    return JSON.parse(text);
  }

  // Auth
  async login(data: LoginRequest): Promise<LoginResponse> {
    const response = await this.request<LoginResponse>('POST', '/auth/login', data);
    this.setToken(response.token);
    return response;
  }

  logout() {
    this.setToken(null);
  }

  // Dashboard
  async getDashboard(): Promise<DashboardResponse> {
    return this.request<DashboardResponse>('GET', '/admin/dashboard');
  }

  // Users
  async getUsers(page: number = 1, pageSize: number = 20, search?: string): Promise<UserListResponse> {
    let endpoint = `/admin/users?page=${page}&page_size=${pageSize}`;
    if (search) {
      endpoint += `&search=${encodeURIComponent(search)}`;
    }
    return this.request<UserListResponse>('GET', endpoint);
  }

  async deleteUser(userId: number): Promise<void> {
    await this.request<void>('DELETE', `/admin/users/${userId}`);
  }

  async resetUserPassword(userId: number): Promise<{ new_password: string }> {
    return this.request<{ new_password: string }>('POST', `/admin/users/${userId}/reset-password`);
  }

  // Versions
  async getVersions(): Promise<VersionInfo[]> {
    return this.request<VersionInfo[]>('GET', '/version/versions');
  }

  async createVersion(data: CreateVersionRequest): Promise<VersionInfo> {
    return this.request<VersionInfo>('POST', '/version/versions', data);
  }

  async deleteVersion(id: number): Promise<void> {
    await this.request<void>('DELETE', `/version/versions/${id}`);
  }
}

export const api = new ApiService();
