using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace Pastee.App.Services
{
    /// <summary>
    /// OAuth 辅助类，处理自定义协议注册和回调
    /// </summary>
    public static class OAuthHelper
    {
        public const string ProtocolScheme = "pastee";
        public const string PipeName = "PasteeOAuthPipe";

        /// <summary>
        /// 注册自定义协议 pastee://
        /// </summary>
        public static void RegisterProtocol()
        {
            try
            {
                var exePath = Process.GetCurrentProcess().MainModule?.FileName;
                if (string.IsNullOrEmpty(exePath)) return;

                using var key = Registry.CurrentUser.CreateSubKey($@"Software\Classes\{ProtocolScheme}");
                if (key == null) return;

                key.SetValue("", $"URL:{ProtocolScheme} Protocol");
                key.SetValue("URL Protocol", "");

                using var iconKey = key.CreateSubKey("DefaultIcon");
                iconKey?.SetValue("", $"\"{exePath}\",0");

                using var commandKey = key.CreateSubKey(@"shell\open\command");
                commandKey?.SetValue("", $"\"{exePath}\" \"%1\"");

                Debug.WriteLine($"[OAuthHelper] Protocol '{ProtocolScheme}://' registered successfully");
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[OAuthHelper] Failed to register protocol: {ex.Message}");
            }
        }

        /// <summary>
        /// 检查命令行参数是否包含 OAuth 回调
        /// </summary>
        public static bool TryParseOAuthCallback(string[] args, out string? token)
        {
            token = null;
            
            foreach (var arg in args)
            {
                if (arg.StartsWith($"{ProtocolScheme}://", StringComparison.OrdinalIgnoreCase))
                {
                    return TryParseCallbackUrl(arg, out token);
                }
            }
            
            return false;
        }

        /// <summary>
        /// 解析回调 URL 提取 token
        /// </summary>
        public static bool TryParseCallbackUrl(string url, out string? token)
        {
            token = null;
            
            try
            {
                // pastee://oauth/callback?token=xxx
                var uri = new Uri(url);
                
                if (!uri.Host.Equals("oauth", StringComparison.OrdinalIgnoreCase) &&
                    !uri.AbsolutePath.StartsWith("/oauth", StringComparison.OrdinalIgnoreCase))
                {
                    return false;
                }

                var query = System.Web.HttpUtility.ParseQueryString(uri.Query);
                token = query["token"];
                
                return !string.IsNullOrEmpty(token);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[OAuthHelper] Failed to parse callback URL: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// 发送 OAuth 回调到主实例
        /// </summary>
        public static async Task<bool> SendCallbackToMainInstanceAsync(string token)
        {
            try
            {
                using var client = new NamedPipeClientStream(".", PipeName, PipeDirection.Out);
                await client.ConnectAsync(3000); // 3秒超时
                
                using var writer = new StreamWriter(client);
                await writer.WriteLineAsync($"OAUTH_TOKEN:{token}");
                await writer.FlushAsync();
                
                Debug.WriteLine("[OAuthHelper] Sent token to main instance via named pipe");
                return true;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[OAuthHelper] Failed to send callback to main instance: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// 启动监听 OAuth 回调的命名管道服务器
        /// </summary>
        public static void StartPipeServer(Action<string> onTokenReceived, CancellationToken cancellationToken)
        {
            Task.Run(async () =>
            {
                while (!cancellationToken.IsCancellationRequested)
                {
                    try
                    {
                        using var server = new NamedPipeServerStream(PipeName, PipeDirection.In, 1, 
                            PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                        
                        await server.WaitForConnectionAsync(cancellationToken);
                        
                        using var reader = new StreamReader(server);
                        var message = await reader.ReadLineAsync();
                        
                        if (message?.StartsWith("OAUTH_TOKEN:") == true)
                        {
                            var token = message.Substring("OAUTH_TOKEN:".Length);
                            Debug.WriteLine("[OAuthHelper] Received token from named pipe");
                            onTokenReceived?.Invoke(token);
                        }
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"[OAuthHelper] Pipe server error: {ex.Message}");
                        await Task.Delay(1000, cancellationToken);
                    }
                }
            }, cancellationToken);
        }

        /// <summary>
        /// 在系统浏览器中打开 URL
        /// </summary>
        public static void OpenInBrowser(string url)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = url,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[OAuthHelper] Failed to open browser: {ex.Message}");
            }
        }
    }
}


