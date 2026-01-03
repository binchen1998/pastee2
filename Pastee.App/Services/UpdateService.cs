using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace Pastee.App.Services
{
    /// <summary>
    /// 版本检查响应
    /// </summary>
    public class VersionCheckResponse
    {
        [JsonPropertyName("update_available")]
        public bool UpdateAvailable { get; set; }

        [JsonPropertyName("latest_version")]
        public string? LatestVersion { get; set; }

        [JsonPropertyName("is_mandatory")]
        public bool IsMandatory { get; set; }

        [JsonPropertyName("release_notes")]
        public string? ReleaseNotes { get; set; }

        [JsonPropertyName("download_url")]
        public string? DownloadUrl { get; set; }
    }

    /// <summary>
    /// 自动更新服务
    /// </summary>
    public class UpdateService
    {
        private static readonly HttpClient _client;
        private const string BaseUrl = "https://api.pastee-app.com";
        private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(10);
        private readonly AuthService _authService = new AuthService();

        static UpdateService()
        {
            _client = new HttpClient { Timeout = RequestTimeout };
        }

        /// <summary>
        /// 获取当前应用版本
        /// </summary>
        public static string GetCurrentVersion()
        {
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            return version?.ToString(3) ?? "1.0.0";
        }

        /// <summary>
        /// 构建完整的下载URL（基于base URL和版本号）
        /// </summary>
        private static string BuildDownloadUrl(string baseUrl, string version)
        {
            // 确保base URL末尾没有斜杠
            var normalizedBaseUrl = baseUrl.TrimEnd('/');
            return $"{normalizedBaseUrl}/Pastee-{version}.exe";
        }

        /// <summary>
        /// 检查下载文件是否存在（HEAD请求）
        /// </summary>
        private async Task<bool> CheckFileExistsAsync(string url, CancellationToken cancellationToken = default)
        {
            try
            {
                var request = new HttpRequestMessage(HttpMethod.Head, url);
                var response = await _client.SendAsync(request, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    Debug.WriteLine($"[UpdateService] File exists: {url}");
                    return true;
                }
                
                Debug.WriteLine($"[UpdateService] File not found ({response.StatusCode}): {url}");
                return false;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[UpdateService] Check file exists error: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// 检查更新
        /// </summary>
        public async Task<VersionCheckResponse?> CheckForUpdateAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                var token = await _authService.GetSavedTokenAsync();
                if (string.IsNullOrEmpty(token))
                {
                    Debug.WriteLine("[UpdateService] No token, skipping update check");
                    return null;
                }

                var currentVersion = GetCurrentVersion();
                var requestBody = new { current_version = currentVersion };
                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var request = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrl}/version/check");
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                request.Content = content;

                var response = await _client.SendAsync(request, cancellationToken);

                if (!response.IsSuccessStatusCode)
                {
                    Debug.WriteLine($"[UpdateService] Check failed: {response.StatusCode}");
                    return null;
                }

                var responseJson = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<VersionCheckResponse>(responseJson);

                Debug.WriteLine($"[UpdateService] Check result: UpdateAvailable={result?.UpdateAvailable}, LatestVersion={result?.LatestVersion}");

                // 如果有更新，检查下载文件是否实际存在
                if (result?.UpdateAvailable == true && !string.IsNullOrEmpty(result.DownloadUrl) && !string.IsNullOrEmpty(result.LatestVersion))
                {
                    var fullDownloadUrl = BuildDownloadUrl(result.DownloadUrl, result.LatestVersion);
                    var fileExists = await CheckFileExistsAsync(fullDownloadUrl, cancellationToken);
                    
                    if (!fileExists)
                    {
                        Debug.WriteLine($"[UpdateService] Update file not available yet, skipping update notification");
                        return null;
                    }
                    
                    // 更新下载URL为完整路径
                    result.DownloadUrl = fullDownloadUrl;
                }

                return result;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[UpdateService] Check error: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 下载更新文件
        /// </summary>
        public async Task<string?> DownloadUpdateAsync(
            string downloadUrl, 
            IProgress<double>? progress = null,
            CancellationToken cancellationToken = default)
        {
            try
            {
                Debug.WriteLine($"[UpdateService] Downloading from: {downloadUrl}");

                var response = await _client.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
                response.EnsureSuccessStatusCode();

                var totalBytes = response.Content.Headers.ContentLength ?? -1L;
                var canReportProgress = totalBytes > 0 && progress != null;

                // 保存到临时文件
                var tempPath = Path.Combine(Path.GetTempPath(), $"PasteeSetup_{Guid.NewGuid():N}.exe");
                
                using (var contentStream = await response.Content.ReadAsStreamAsync())
                using (var fileStream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true))
                {
                    var buffer = new byte[8192];
                    long totalRead = 0;
                    int bytesRead;

                    while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length, cancellationToken)) > 0)
                    {
                        await fileStream.WriteAsync(buffer, 0, bytesRead, cancellationToken);
                        totalRead += bytesRead;

                        if (canReportProgress)
                        {
                            var percentage = (double)totalRead / totalBytes * 100;
                            progress!.Report(percentage);
                        }
                    }
                }

                Debug.WriteLine($"[UpdateService] Downloaded to: {tempPath}");
                return tempPath;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[UpdateService] Download error: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// 安装更新（运行安装程序并退出当前应用）
        /// </summary>
        public void InstallUpdate(string installerPath)
        {
            try
            {
                Debug.WriteLine($"[UpdateService] Starting installer: {installerPath}");

                var startInfo = new ProcessStartInfo
                {
                    FileName = installerPath,
                    UseShellExecute = true
                };
                Process.Start(startInfo);

                // 退出当前应用
                System.Windows.Application.Current.Dispatcher.Invoke(() =>
                {
                    System.Windows.Application.Current.Shutdown();
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[UpdateService] Install error: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// 在浏览器中打开下载链接
        /// </summary>
        public void OpenDownloadInBrowser(string downloadUrl)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = downloadUrl,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[UpdateService] Open browser error: {ex.Message}");
            }
        }
    }
}

