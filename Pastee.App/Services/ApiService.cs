using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;

namespace Pastee.App.Services
{
    public class ApiService
    {
        private static readonly HttpClient _client;
        private const string BaseUrl = "https://api.pastee-app.com";
        private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(10);
        private string? _token;

        static ApiService()
        {
            _client = new HttpClient { Timeout = RequestTimeout };
            _client.DefaultRequestHeaders.Accept.Clear();
            _client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        }

        public ApiService()
        {
        }

        public void SetToken(string token)
        {
            _token = token;
        }

        public async Task<T?> GetAsync<T>(string endpoint, System.Threading.CancellationToken ct = default) where T : class
        {
            var request = CreateRequest(HttpMethod.Get, endpoint);
            return await SendRequestAsync<T>(request, ct);
        }

        public async Task<T?> PostAsync<T>(string endpoint, object data, System.Threading.CancellationToken ct = default) where T : class
        {
            var request = CreateRequest(HttpMethod.Post, endpoint);
            var json = JsonSerializer.Serialize(data, _jsonOptions);
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            return await SendRequestAsync<T>(request, ct);
        }

        public async Task<string?> PostRawAsync(string endpoint, object data, System.Threading.CancellationToken ct = default)
        {
            var request = CreateRequest(HttpMethod.Post, endpoint);
            var json = JsonSerializer.Serialize(data, _jsonOptions);
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            try
            {
                var response = await _client.SendAsync(request, ct);
                if (response.IsSuccessStatusCode) return await response.Content.ReadAsStringAsync();
                return null;
            }
            catch { return null; }
        }

        public async Task<T?> PostMultipartAsync<T>(string endpoint, MultipartFormDataContent content, System.Threading.CancellationToken ct = default) where T : class
        {
            var request = CreateRequest(HttpMethod.Post, endpoint);
            request.Content = content;
            return await SendRequestAsync<T>(request, ct);
        }

        public async Task<T?> PutAsync<T>(string endpoint, object data, System.Threading.CancellationToken ct = default) where T : class
        {
            var request = CreateRequest(HttpMethod.Post, endpoint);
            var json = JsonSerializer.Serialize(data, _jsonOptions);
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            return await SendRequestAsync<T>(request, ct);
        }

        public async Task<T?> PatchAsync<T>(string endpoint, object data, System.Threading.CancellationToken ct = default) where T : class
        {
            var request = new HttpRequestMessage(new HttpMethod("PATCH"), $"{BaseUrl}{endpoint}");
            if (!string.IsNullOrEmpty(_token))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
            }
            var json = JsonSerializer.Serialize(data, _jsonOptions);
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            return await SendRequestAsync<T>(request, ct);
        }

        public async Task<bool> DeleteAsync(string endpoint, System.Threading.CancellationToken ct = default)
        {
            var request = CreateRequest(HttpMethod.Delete, endpoint);
            try
            {
                var response = await _client.SendAsync(request, ct);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        private HttpRequestMessage CreateRequest(HttpMethod method, string endpoint)
        {
            var request = new HttpRequestMessage(method, $"{BaseUrl}{endpoint}");
            if (!string.IsNullOrEmpty(_token))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
            }
            return request;
        }

        private static readonly JsonSerializerOptions _jsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            Converters = { 
                new System.Text.Json.Serialization.JsonStringEnumConverter(),
                new Pastee.App.Infrastructure.FlexibleStringConverter(),
                new Pastee.App.Infrastructure.FlexibleBoolConverter(),
                new Pastee.App.Infrastructure.UniversalDateTimeOffsetConverter()
            }
        };

        public JsonSerializerOptions GetJsonOptions() => _jsonOptions;

        private async Task<T?> SendRequestAsync<T>(HttpRequestMessage request, System.Threading.CancellationToken ct = default) where T : class
        {
            try
            {
                System.Diagnostics.Debug.WriteLine($"[API] 发送请求: {request.Method} {request.RequestUri}");
                var response = await _client.SendAsync(request, ct);
                System.Diagnostics.Debug.WriteLine($"[API] 收到响应: {response.StatusCode} {request.RequestUri}");
                
                if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
                {
                    System.Diagnostics.Debug.WriteLine("[API] 授权失效 (401)");
                    UnauthorizedAccess?.Invoke(this, EventArgs.Empty);
                    return default;
                }

                if (response.StatusCode == System.Net.HttpStatusCode.Forbidden)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    System.Diagnostics.Debug.WriteLine($"[API] 请求被禁止 (403): {errorContent}");
                    if (errorContent.Contains("Storage limit", StringComparison.OrdinalIgnoreCase))
                    {
                        StorageLimitReached?.Invoke(this, EventArgs.Empty);
                    }
                    return default;
                }

                if (!response.IsSuccessStatusCode)
                {
                    var errorBody = await response.Content.ReadAsStringAsync();
                    System.Diagnostics.Debug.WriteLine($"[API] 请求失败: {response.StatusCode}. 响应体: {errorBody}");
                    return default;
                }

                var content = await response.Content.ReadAsStringAsync();
                System.Diagnostics.Debug.WriteLine($"[API] 请求成功. 响应体预览: {content.Substring(0, Math.Min(100, content.Length))}");
                return JsonSerializer.Deserialize<T>(content, _jsonOptions);
            }
            catch (OperationCanceledException)
            {
                System.Diagnostics.Debug.WriteLine($"[API] 请求已取消: {request.RequestUri}");
                return default;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[API] 请求异常: {ex.Message}");
                return default;
            }
        }

        public event EventHandler? UnauthorizedAccess;
        public event EventHandler? StorageLimitReached;
    }
}

