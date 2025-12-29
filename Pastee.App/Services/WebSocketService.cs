using System;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Pastee.App.Services
{
    public class WebSocketService : IDisposable
    {
        private ClientWebSocket? _webSocket;
        private readonly string _baseUrl = "wss://api.pastee-app.com/ws";
        private CancellationTokenSource? _cts;
        private string? _token;
        private string? _deviceId;
        
        // 心跳相关
        private const int HeartbeatIntervalMs = 30000; // 30秒发送一次心跳
        private const int PongTimeoutMs = 10000; // 10秒内未收到pong则判定超时
        private const int ReconnectIntervalMs = 5000; // 5秒重连间隔
        private Timer? _heartbeatTimer;
        private Timer? _pongTimeoutTimer;
        private bool _isIntentionallyClosed;
        private bool _waitingForPong;

        public event EventHandler<string>? MessageReceived;
        public event EventHandler? Connected;
        public event EventHandler? Disconnected;
        public event EventHandler? Connecting;

        public async Task ConnectAsync(string token, string deviceId, bool force = false)
        {
            _token = token;
            _deviceId = deviceId;
            _isIntentionallyClosed = false;
            
            if (force)
            {
                System.Diagnostics.Debug.WriteLine("[WS] 强制重连...");
                await StopAsync(intentional: false);
            }
            
            await ConnectInternalAsync();
        }

        private async Task ConnectInternalAsync()
        {
            if (_webSocket != null && _webSocket.State == WebSocketState.Open) return;

            Connecting?.Invoke(this, EventArgs.Empty);
            _cts = new CancellationTokenSource();
            _webSocket = new ClientWebSocket();
            
            try
            {
                var uri = new Uri($"{_baseUrl}/{_token}/{_deviceId}");
                System.Diagnostics.Debug.WriteLine($"[WS] 正在连接: {uri}");
                await _webSocket.ConnectAsync(uri, _cts.Token);
                System.Diagnostics.Debug.WriteLine("[WS] 连接成功");
                Connected?.Invoke(this, EventArgs.Empty);
                
                // 启动接收循环和心跳
                _ = ReceiveLoopAsync();
                StartHeartbeat();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[WS] 连接失败: {ex.Message}");
                Disconnected?.Invoke(this, EventArgs.Empty);
                ScheduleReconnect();
            }
        }

        private async Task ReceiveLoopAsync()
        {
            var buffer = new byte[1024 * 4];
            try
            {
                while (_webSocket?.State == WebSocketState.Open && _cts != null && !_cts.IsCancellationRequested)
                {
                    var result = await _webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), _cts.Token);
                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        System.Diagnostics.Debug.WriteLine("[WS] 收到关闭消息");
                        await HandleDisconnectAsync();
                        break;
                    }

                    var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    System.Diagnostics.Debug.WriteLine($"[WS] 收到原始消息: {message}");
                    
                    // 处理心跳响应
                    if (HandleHeartbeatResponse(message))
                    {
                        continue; // pong 消息不需要传递给业务层
                    }
                    
                    MessageReceived?.Invoke(this, message);
                }
            }
            catch (OperationCanceledException)
            {
                System.Diagnostics.Debug.WriteLine("[WS] 接收循环被取消");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[WS] 接收异常: {ex.Message}");
                await HandleDisconnectAsync();
            }
        }

        #region Heartbeat

        private void StartHeartbeat()
        {
            StopHeartbeat();
            _waitingForPong = false;
            
            System.Diagnostics.Debug.WriteLine("[WS] 启动心跳定时器");
            _heartbeatTimer = new Timer(async _ => await SendPingAsync(), null, HeartbeatIntervalMs, HeartbeatIntervalMs);
        }

        private void StopHeartbeat()
        {
            _heartbeatTimer?.Dispose();
            _heartbeatTimer = null;
            _pongTimeoutTimer?.Dispose();
            _pongTimeoutTimer = null;
            _waitingForPong = false;
        }

        private async Task SendPingAsync()
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open || _cts == null)
            {
                StopHeartbeat();
                return;
            }

            try
            {
                var pingMessage = JsonSerializer.Serialize(new { type = "ping" });
                var pingBytes = Encoding.UTF8.GetBytes(pingMessage);
                
                System.Diagnostics.Debug.WriteLine("[WS] 发送心跳 ping");
                await _webSocket.SendAsync(new ArraySegment<byte>(pingBytes), WebSocketMessageType.Text, true, _cts.Token);
                
                // 启动 pong 超时计时器
                _waitingForPong = true;
                _pongTimeoutTimer?.Dispose();
                _pongTimeoutTimer = new Timer(async _ => await HandlePongTimeoutAsync(), null, PongTimeoutMs, Timeout.Infinite);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[WS] 发送心跳失败: {ex.Message}");
                await HandleDisconnectAsync();
            }
        }

        private bool HandleHeartbeatResponse(string message)
        {
            try
            {
                using var doc = JsonDocument.Parse(message);
                if (doc.RootElement.TryGetProperty("type", out var typeProp))
                {
                    var type = typeProp.GetString();
                    if (type == "pong")
                    {
                        System.Diagnostics.Debug.WriteLine("[WS] 收到心跳 pong");
                        _waitingForPong = false;
                        _pongTimeoutTimer?.Dispose();
                        _pongTimeoutTimer = null;
                        return true;
                    }
                }
            }
            catch
            {
                // 不是 JSON 或没有 type 字段，不是心跳消息
            }
            return false;
        }

        private async Task HandlePongTimeoutAsync()
        {
            if (!_waitingForPong) return;
            
            System.Diagnostics.Debug.WriteLine("[WS] 心跳超时，未收到 pong");
            await HandleDisconnectAsync();
        }

        #endregion

        #region Reconnect

        private async Task HandleDisconnectAsync()
        {
            StopHeartbeat();
            
            if (_webSocket != null)
            {
                try
                {
                    if (_webSocket.State == WebSocketState.Open)
                    {
                        await _webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closing", CancellationToken.None);
                    }
                }
                catch { }
                
                _webSocket.Dispose();
                _webSocket = null;
            }
            
            Disconnected?.Invoke(this, EventArgs.Empty);
            
            if (!_isIntentionallyClosed)
            {
                ScheduleReconnect();
            }
        }

        private void ScheduleReconnect()
        {
            if (_isIntentionallyClosed) return;
            
            System.Diagnostics.Debug.WriteLine($"[WS] {ReconnectIntervalMs / 1000}秒后尝试重连...");
            Task.Delay(ReconnectIntervalMs).ContinueWith(async _ =>
            {
                if (!_isIntentionallyClosed)
                {
                    await ConnectInternalAsync();
                }
            });
        }

        #endregion

        public async Task StopAsync(bool intentional = true)
        {
            _isIntentionallyClosed = intentional;
            StopHeartbeat();
            _cts?.Cancel();
            
            if (_webSocket != null)
            {
                try
                {
                    if (_webSocket.State == WebSocketState.Open)
                    {
                        await _webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closing", CancellationToken.None);
                    }
                }
                catch { }
                
                _webSocket.Dispose();
                _webSocket = null;
            }
        }

        public void Dispose()
        {
            StopAsync(intentional: true).GetAwaiter().GetResult();
        }
    }
}
