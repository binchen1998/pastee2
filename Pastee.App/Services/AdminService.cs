using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Pastee.App.Services
{
    #region Data Models

    /// <summary>
    /// Dashboard API 响应结构
    /// </summary>
    public class DashboardResponse
    {
        [JsonPropertyName("today")]
        public DayStats? Today { get; set; }

        [JsonPropertyName("yesterday")]
        public DayStats? Yesterday { get; set; }

        [JsonPropertyName("growth_rates")]
        public GrowthRates? GrowthRates { get; set; }

        [JsonPropertyName("recent_week")]
        public List<DailyStats>? RecentWeek { get; set; }

        [JsonPropertyName("recent_month")]
        public List<DailyStats>? RecentMonth { get; set; }

        [JsonPropertyName("summary")]
        public DashboardSummary? Summary { get; set; }
    }

    public class DayStats
    {
        [JsonPropertyName("date")]
        public string? Date { get; set; }

        [JsonPropertyName("new_registrations")]
        public int NewRegistrations { get; set; }

        [JsonPropertyName("active_users")]
        public int ActiveUsers { get; set; }

        [JsonPropertyName("total_users")]
        public int TotalUsers { get; set; }
    }

    public class GrowthRates
    {
        [JsonPropertyName("registrations")]
        public double Registrations { get; set; }

        [JsonPropertyName("active_users")]
        public double ActiveUsers { get; set; }
    }

    public class DashboardSummary
    {
        [JsonPropertyName("total_users")]
        public int TotalUsers { get; set; }

        [JsonPropertyName("today_registrations")]
        public int TodayRegistrations { get; set; }

        [JsonPropertyName("today_active")]
        public int TodayActive { get; set; }

        [JsonPropertyName("week_avg_registrations")]
        public double WeekAvgRegistrations { get; set; }

        [JsonPropertyName("week_avg_active")]
        public double WeekAvgActive { get; set; }
    }

    public class DailyStats
    {
        [JsonPropertyName("date")]
        public string? Date { get; set; }

        [JsonPropertyName("new_registrations")]
        public int NewRegistrations { get; set; }

        [JsonPropertyName("active_users")]
        public int ActiveUsers { get; set; }

        [JsonPropertyName("total_users")]
        public int TotalUsers { get; set; }
    }

    public class AdminUser
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("created_at")]
        public string? CreatedAt { get; set; }

        [JsonPropertyName("last_active")]
        public string? LastActive { get; set; }

        [JsonPropertyName("is_verified")]
        public bool IsVerified { get; set; }

        [JsonPropertyName("storage_used")]
        public long StorageUsed { get; set; }

        [JsonPropertyName("storage_limit")]
        public long StorageLimit { get; set; }
    }

    public class UserListResponse
    {
        [JsonPropertyName("users")]
        public List<AdminUser>? Users { get; set; }

        [JsonPropertyName("total")]
        public int Total { get; set; }

        [JsonPropertyName("page")]
        public int Page { get; set; }

        [JsonPropertyName("page_size")]
        public int PageSize { get; set; }
    }

    public class VersionInfo
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("version")]
        public string? Version { get; set; }

        [JsonPropertyName("release_notes")]
        public string? ReleaseNotes { get; set; }

        [JsonPropertyName("download_url")]
        public string? DownloadUrl { get; set; }

        [JsonPropertyName("is_mandatory")]
        public bool IsMandatory { get; set; }

        [JsonPropertyName("created_at")]
        public string? CreatedAt { get; set; }
    }

    #endregion

    /// <summary>
    /// 管理员服务
    /// </summary>
    public class AdminService
    {
        private static readonly HttpClient _client;
        private const string BaseUrl = "https://api.pastee-app.com";
        private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(10);
        private readonly AuthService _authService = new AuthService();

        static AdminService()
        {
            _client = new HttpClient { Timeout = RequestTimeout };
        }

        /// <summary>
        /// 检查是否是管理员邮箱
        /// </summary>
        public static bool IsAdminEmail(string? email)
        {
            return string.Equals(email, "admin@pastee.im", StringComparison.OrdinalIgnoreCase);
        }

        private async Task<HttpRequestMessage> CreateAuthorizedRequestAsync(HttpMethod method, string endpoint)
        {
            var request = new HttpRequestMessage(method, $"{BaseUrl}{endpoint}");
            var token = await _authService.GetSavedTokenAsync();
            if (!string.IsNullOrEmpty(token))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            }
            return request;
        }

        /// <summary>
        /// 获取仪表盘数据
        /// </summary>
        public async Task<DashboardResponse?> GetDashboardDataAsync()
        {
            try
            {
                var request = await CreateAuthorizedRequestAsync(HttpMethod.Get, "/admin/dashboard");
                var response = await _client.SendAsync(request);

                if (!response.IsSuccessStatusCode)
                {
                    Debug.WriteLine($"[AdminService] Dashboard request failed: {response.StatusCode}");
                    return null;
                }

                var json = await response.Content.ReadAsStringAsync();
                Debug.WriteLine($"[AdminService] Dashboard response: {json}");
                return JsonSerializer.Deserialize<DashboardResponse>(json);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Dashboard error: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 获取用户列表
        /// </summary>
        public async Task<UserListResponse?> GetUsersAsync(int page = 1, int pageSize = 20, string? search = null)
        {
            try
            {
                var endpoint = $"/admin/users?page={page}&page_size={pageSize}";
                if (!string.IsNullOrEmpty(search))
                {
                    endpoint += $"&search={Uri.EscapeDataString(search)}";
                }

                var request = await CreateAuthorizedRequestAsync(HttpMethod.Get, endpoint);
                var response = await _client.SendAsync(request);

                if (!response.IsSuccessStatusCode)
                {
                    Debug.WriteLine($"[AdminService] Users request failed: {response.StatusCode}");
                    return null;
                }

                var json = await response.Content.ReadAsStringAsync();
                return JsonSerializer.Deserialize<UserListResponse>(json);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Users error: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 删除用户
        /// </summary>
        public async Task<bool> DeleteUserAsync(int userId)
        {
            try
            {
                var request = await CreateAuthorizedRequestAsync(HttpMethod.Delete, $"/admin/users/{userId}");
                var response = await _client.SendAsync(request);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Delete user error: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// 重置用户密码
        /// </summary>
        public async Task<string?> ResetUserPasswordAsync(int userId)
        {
            try
            {
                var request = await CreateAuthorizedRequestAsync(HttpMethod.Post, $"/admin/users/{userId}/reset-password");
                var response = await _client.SendAsync(request);

                if (!response.IsSuccessStatusCode) return null;

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                return doc.RootElement.GetProperty("new_password").GetString();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Reset password error: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 获取版本列表
        /// </summary>
        public async Task<List<VersionInfo>?> GetVersionsAsync()
        {
            try
            {
                var request = await CreateAuthorizedRequestAsync(HttpMethod.Get, "/version/versions");
                var response = await _client.SendAsync(request);

                if (!response.IsSuccessStatusCode) return null;

                var json = await response.Content.ReadAsStringAsync();
                return JsonSerializer.Deserialize<List<VersionInfo>>(json);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Versions error: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 发布新版本
        /// </summary>
        public async Task<bool> PublishVersionAsync(string version, string releaseNotes, string downloadUrl, bool isMandatory)
        {
            try
            {
                var request = await CreateAuthorizedRequestAsync(HttpMethod.Post, "/version/versions");
                var body = new { version, release_notes = releaseNotes, download_url = downloadUrl, is_mandatory = isMandatory };
                request.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");

                var response = await _client.SendAsync(request);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Publish version error: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// 删除版本
        /// </summary>
        public async Task<bool> DeleteVersionAsync(int id)
        {
            try
            {
                var request = await CreateAuthorizedRequestAsync(HttpMethod.Delete, $"/version/versions/{id}");
                var response = await _client.SendAsync(request);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AdminService] Delete version error: {ex.Message}");
                return false;
            }
        }
    }
}

