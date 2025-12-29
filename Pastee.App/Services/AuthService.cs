using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Pastee.App.Services
{
    /// <summary>
    /// 认证操作结果
    /// </summary>
    public class AuthResult
    {
        public bool Success { get; set; }
        public string? Token { get; set; }
        public string? ErrorMessage { get; set; }
        public string? Email { get; set; }

        public static AuthResult Ok(string? token = null, string? email = null) 
            => new AuthResult { Success = true, Token = token, Email = email };
        
        public static AuthResult Fail(string message) 
            => new AuthResult { Success = false, ErrorMessage = message };
    }

    public class AuthService
    {
        private static readonly HttpClient _client;
        private const string BaseUrl = "https://api.pastee-app.com";
        private const string TokenKey = "pastee_token";
        private const string DeviceIdKey = "pastee_device_id";
        private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(10);
        private readonly string _tokenFilePath;
        private readonly string _deviceIdFilePath;

        static AuthService()
        {
            _client = new HttpClient { Timeout = RequestTimeout };
        }

        public AuthService()
        {
            var baseDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PasteeNative");
            Directory.CreateDirectory(baseDir);
            _tokenFilePath = Path.Combine(baseDir, "auth.token");
            _deviceIdFilePath = Path.Combine(baseDir, "device.id");
        }

        public string GetOrCreateDeviceId()
        {
            if (File.Exists(_deviceIdFilePath))
            {
                try
                {
                    return File.ReadAllText(_deviceIdFilePath).Trim();
                }
                catch { }
            }

            // 生成逻辑匹配前端逻辑
            string platform = Environment.OSVersion.Platform.ToString();
            string machineName = Environment.MachineName;
            string rawInfo = platform + machineName;
            
            // 简单哈希 (模拟 simpleHash)
            uint hash = 0;
            foreach (char c in rawInfo)
            {
                hash = (hash << 5) - hash + (uint)c;
            }
            string machineHash = Math.Abs((int)hash).ToString("x");
            string timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString("x");
            string uuid6 = Guid.NewGuid().ToString("N").Substring(0, 6);

            string deviceId = $"windows-{machineHash}-{timestamp}-{uuid6}";
            
            try
            {
                File.WriteAllText(_deviceIdFilePath, deviceId);
            }
            catch { }

            return deviceId;
        }

        /// <summary>
        /// 从 API 响应中提取错误信息
        /// </summary>
        private async Task<string> ExtractErrorMessageAsync(HttpResponseMessage response)
        {
            try
            {
                var content = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(content);
                
                // 尝试获取 detail 字段（FastAPI 标准错误格式）
                if (doc.RootElement.TryGetProperty("detail", out var detail))
                {
                    // detail 可能是字符串或对象
                    if (detail.ValueKind == JsonValueKind.String)
                    {
                        return detail.GetString() ?? "Unknown error";
                    }
                    else if (detail.ValueKind == JsonValueKind.Array)
                    {
                        // 验证错误通常是数组格式
                        var errors = new StringBuilder();
                        foreach (var err in detail.EnumerateArray())
                        {
                            if (err.TryGetProperty("msg", out var msg))
                            {
                                if (errors.Length > 0) errors.Append("; ");
                                errors.Append(msg.GetString());
                            }
                        }
                        return errors.Length > 0 ? errors.ToString() : "Validation error";
                    }
                    else if (detail.ValueKind == JsonValueKind.Object)
                    {
                        if (detail.TryGetProperty("message", out var msg))
                        {
                            return msg.GetString() ?? "Unknown error";
                        }
                    }
                }
                
                // 尝试获取 message 字段
                if (doc.RootElement.TryGetProperty("message", out var message))
                {
                    return message.GetString() ?? "Unknown error";
                }
                
                // 尝试获取 error 字段
                if (doc.RootElement.TryGetProperty("error", out var error))
                {
                    return error.GetString() ?? "Unknown error";
                }
            }
            catch
            {
                // JSON 解析失败
            }

            // 根据状态码返回默认错误信息
            return response.StatusCode switch
            {
                System.Net.HttpStatusCode.BadRequest => "Invalid request. Please check your input.",
                System.Net.HttpStatusCode.Unauthorized => "Invalid email or password.",
                System.Net.HttpStatusCode.Forbidden => "Account not verified. Please verify your email first.",
                System.Net.HttpStatusCode.NotFound => "Account not found.",
                System.Net.HttpStatusCode.Conflict => "Email already registered.",
                System.Net.HttpStatusCode.TooManyRequests => "Too many requests. Please try again later.",
                System.Net.HttpStatusCode.InternalServerError => "Server error. Please try again later.",
                System.Net.HttpStatusCode.ServiceUnavailable => "Service unavailable. Please try again later.",
                _ => $"Request failed ({(int)response.StatusCode})"
            };
        }

        /// <summary>
        /// 登录
        /// </summary>
        public async Task<AuthResult> LoginAsync(string email, string password)
        {
            try
            {
                using var content = new MultipartFormDataContent();
                content.Add(new StringContent(email), "username");
                content.Add(new StringContent(password), "password");

                var response = await _client.PostAsync($"{BaseUrl}/auth/token", content);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorMsg = await ExtractErrorMessageAsync(response);
                    return AuthResult.Fail(errorMsg);
                }

                var result = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(result);
                var token = doc.RootElement.GetProperty("access_token").GetString();
                
                if (!string.IsNullOrEmpty(token))
                {
                    await SaveTokenAsync(token);
                    return AuthResult.Ok(token);
                }
                
                return AuthResult.Fail("Failed to get access token.");
            }
            catch (HttpRequestException ex)
            {
                return AuthResult.Fail($"Network error: {ex.Message}");
            }
            catch (TaskCanceledException)
            {
                return AuthResult.Fail("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                return AuthResult.Fail($"Unexpected error: {ex.Message}");
            }
        }

        /// <summary>
        /// 注册新用户
        /// </summary>
        public async Task<AuthResult> RegisterAsync(string email, string password)
        {
            try
            {
                var requestBody = new { email, password };
                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _client.PostAsync($"{BaseUrl}/auth/register", content);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorMsg = await ExtractErrorMessageAsync(response);
                    return AuthResult.Fail(errorMsg);
                }

                var result = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(result);
                
                string? returnedEmail = null;
                if (doc.RootElement.TryGetProperty("email", out var emailProp))
                {
                    returnedEmail = emailProp.GetString();
                }
                
                return AuthResult.Ok(email: returnedEmail ?? email);
            }
            catch (HttpRequestException ex)
            {
                return AuthResult.Fail($"Network error: {ex.Message}");
            }
            catch (TaskCanceledException)
            {
                return AuthResult.Fail("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                return AuthResult.Fail($"Unexpected error: {ex.Message}");
            }
        }

        /// <summary>
        /// 验证邮箱
        /// </summary>
        public async Task<AuthResult> VerifyEmailAsync(string email, string verificationCode)
        {
            try
            {
                var requestBody = new { email, verification_code = verificationCode };
                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _client.PostAsync($"{BaseUrl}/auth/verify-email", content);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorMsg = await ExtractErrorMessageAsync(response);
                    return AuthResult.Fail(errorMsg);
                }

                return AuthResult.Ok();
            }
            catch (HttpRequestException ex)
            {
                return AuthResult.Fail($"Network error: {ex.Message}");
            }
            catch (TaskCanceledException)
            {
                return AuthResult.Fail("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                return AuthResult.Fail($"Unexpected error: {ex.Message}");
            }
        }

        /// <summary>
        /// 重新发送验证码
        /// </summary>
        public async Task<AuthResult> ResendVerificationAsync(string email)
        {
            try
            {
                var requestBody = new { email };
                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _client.PostAsync($"{BaseUrl}/auth/resend-verification", content);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorMsg = await ExtractErrorMessageAsync(response);
                    return AuthResult.Fail(errorMsg);
                }

                return AuthResult.Ok();
            }
            catch (HttpRequestException ex)
            {
                return AuthResult.Fail($"Network error: {ex.Message}");
            }
            catch (TaskCanceledException)
            {
                return AuthResult.Fail("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                return AuthResult.Fail($"Unexpected error: {ex.Message}");
            }
        }

        public async Task<bool> CheckAuthAsync()
        {
            var token = await GetSavedTokenAsync();
            if (string.IsNullOrEmpty(token)) return false;

            try
            {
                var request = new HttpRequestMessage(HttpMethod.Get, $"{BaseUrl}/auth/me");
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

                var response = await _client.SendAsync(request);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<string?> GetSavedTokenAsync()
        {
            if (!File.Exists(_tokenFilePath)) return null;
            try
            {
                return await File.ReadAllTextAsync(_tokenFilePath);
            }
            catch
            {
                return null;
            }
        }

        public async Task SaveTokenAsync(string token)
        {
            try
            {
                await File.WriteAllTextAsync(_tokenFilePath, token);
            }
            catch { }
        }

        public void Logout()
        {
            if (File.Exists(_tokenFilePath))
            {
                File.Delete(_tokenFilePath);
            }
        }

        /// <summary>
        /// 获取 Google OAuth 授权 URL
        /// </summary>
        public string GetGoogleAuthUrl()
        {
            // 后端会处理 OAuth 流程并重定向到 pastee://oauth/callback?token=xxx
            return $"{BaseUrl}/auth/oauth/google/authorize";
        }

        /// <summary>
        /// 使用 OAuth token 完成登录
        /// </summary>
        public async Task<AuthResult> CompleteOAuthLoginAsync(string token)
        {
            try
            {
                // 先保存 token
                await SaveTokenAsync(token);

                // 验证 token 是否有效（调用 /auth/me）
                var request = new HttpRequestMessage(HttpMethod.Get, $"{BaseUrl}/auth/me");
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

                var response = await _client.SendAsync(request);
                
                if (!response.IsSuccessStatusCode)
                {
                    // Token 无效，删除它
                    Logout();
                    var errorMsg = await ExtractErrorMessageAsync(response);
                    return AuthResult.Fail(errorMsg);
                }

                return AuthResult.Ok(token);
            }
            catch (HttpRequestException ex)
            {
                Logout();
                return AuthResult.Fail($"Network error: {ex.Message}");
            }
            catch (TaskCanceledException)
            {
                Logout();
                return AuthResult.Fail("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                Logout();
                return AuthResult.Fail($"Unexpected error: {ex.Message}");
            }
        }
    }
}

