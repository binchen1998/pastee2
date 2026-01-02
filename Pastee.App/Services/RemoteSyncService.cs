using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;
using Pastee.App.Models;

namespace Pastee.App.Services
{
    /// <summary>
    /// 上传结果
    /// </summary>
    public class UploadResult
    {
        public bool Success { get; set; }
        public bool IsDuplicate { get; set; }
        public ClipboardEntry? Item { get; set; }
        public string? ErrorMessage { get; set; }

        public static UploadResult Ok(ClipboardEntry? item) => new UploadResult { Success = true, Item = item };
        public static UploadResult Duplicate() => new UploadResult { Success = true, IsDuplicate = true };
        public static UploadResult Fail(string message) => new UploadResult { Success = false, ErrorMessage = message };
    }

    /// <summary>
    /// 处理剪贴板项同步到远程服务器。
    /// </summary>
    public class RemoteSyncService
    {
        private static readonly HttpClient _client;
        private readonly string _deviceId;
        private string? _token;
        private const string BaseUrl = "https://api.pastee-app.com";

        static RemoteSyncService()
        {
            _client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        public RemoteSyncService(ApiService apiService, string deviceId)
        {
            _deviceId = deviceId;
        }

        public void SetToken(string token)
        {
            _token = token;
        }

        public async Task<UploadResult> PushAsync(ClipboardEntry entry)
        {
            try
            {
                using (var content = new MultipartFormDataContent())
                {
                    content.Add(new StringContent(entry.ContentType), "content_type");
                    content.Add(new StringContent(_deviceId), "device_id");
                    content.Add(new StringContent(entry.CreatedAt.ToString("O")), "created_at");

                    if (entry.ContentType == "text" || entry.ContentType == "url")
                    {
                        content.Add(new StringContent(entry.Content ?? string.Empty), "content");
                    }
                    else if (entry.ContentType == "image")
                    {
                        var filePath = entry.Thumbnail ?? entry.FilePath;
                        if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath))
                        {
                            return UploadResult.Fail("Image file not found");
                        }

                        var fileInfo = new FileInfo(filePath);
                        // 将文件内容读取到内存中，避免流生命周期问题
                        var fileBytes = await File.ReadAllBytesAsync(filePath);
                        var byteContent = new ByteArrayContent(fileBytes);
                        byteContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
                        content.Add(byteContent, "file", fileInfo.Name);
                    }

                    var request = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrl}/clipboard/items");
                    request.Content = content;
                    if (!string.IsNullOrEmpty(_token))
                    {
                        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);
                    }

                    System.Diagnostics.Debug.WriteLine($"[SyncService] 正在上传 ({entry.ContentType}): {entry.Id}");
                    var response = await _client.SendAsync(request);

                    // 处理 409 Conflict (重复项)
                    if (response.StatusCode == HttpStatusCode.Conflict)
                    {
                        System.Diagnostics.Debug.WriteLine($"[SyncService] 服务器返回 409 重复项: {entry.Id}");
                        return UploadResult.Duplicate();
                    }

                    if (response.IsSuccessStatusCode)
                    {
                        var json = await response.Content.ReadAsStringAsync();
                        var result = JsonSerializer.Deserialize<ClipboardEntry>(json, new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });
                        System.Diagnostics.Debug.WriteLine($"[SyncService] 上传成功: {entry.Id}");
                        return UploadResult.Ok(result);
                    }

                    var errorContent = await response.Content.ReadAsStringAsync();
                    System.Diagnostics.Debug.WriteLine($"[SyncService] 上传失败 {response.StatusCode}: {errorContent}");
                    return UploadResult.Fail($"Server returned {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[SyncService] 上传异常: {ex.Message}");
                return UploadResult.Fail(ex.Message);
            }
        }
    }
}

