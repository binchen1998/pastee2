using System;
using System.Threading;
using System.Windows;
using Pastee.App.Services;
using Pastee.App.Views;

namespace Pastee.App
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        private static Mutex? _mutex;
        private static bool _mutexOwned = false;
        private const string MutexName = "PasteeApp_SingleInstance_Mutex";
        private readonly AuthService _authService = new AuthService();
        private CancellationTokenSource? _pipeCts;
        private static LoginWindow? _loginWindow;

        /// <summary>
        /// 当收到 OAuth 回调 token 时触发
        /// </summary>
        public static event Action<string>? OAuthTokenReceived;

        protected override async void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // 加载并应用保存的主题
            var savedTheme = ThemeService.LoadSavedTheme();
            ThemeService.ApplyTheme(savedTheme);

            // 检查是否是 OAuth 回调启动
            if (OAuthHelper.TryParseOAuthCallback(e.Args, out var callbackToken))
            {
                // 这是通过 pastee:// 协议启动的第二实例
                // 尝试将 token 发送给主实例
                await OAuthHelper.SendCallbackToMainInstanceAsync(callbackToken!);
                Shutdown();
                return;
            }

            // 单实例检查
            _mutex = new Mutex(true, MutexName, out bool createdNew);
            _mutexOwned = createdNew;
            if (!createdNew)
            {
                // 已有实例在运行，显示提示（非 OAuth 回调的情况）
                MessageBox.Show("Pastee is already running.", "Pastee", MessageBoxButton.OK, MessageBoxImage.Information);
                Shutdown();
                return;
            }

            // 注册自定义协议（确保 pastee:// 可以唤起应用）
            OAuthHelper.RegisterProtocol();

            // 启动命名管道服务器监听 OAuth 回调
            _pipeCts = new CancellationTokenSource();
            OAuthHelper.StartPipeServer(OnOAuthTokenReceived, _pipeCts.Token);

            // 1. 检查本地是否有保存的 token（不发送网络请求，支持离线使用）
            var token = await _authService.GetSavedTokenAsync();
            bool hasToken = !string.IsNullOrEmpty(token);

            if (!hasToken)
            {
                // 2. 没有 token，显示登录窗口
                _loginWindow = new LoginWindow();
                if (_loginWindow.ShowDialog() != true)
                {
                    // 用户关闭了登录窗口且未登录成功
                    Shutdown();
                    return;
                }
                _loginWindow = null;
                // 登录成功后重新获取 token
                token = await _authService.GetSavedTokenAsync();
            }

            // 3. 有 token，直接显示主窗口（网络错误时会显示缓存数据）
            var mainWindow = new MainWindow(token ?? string.Empty);
            mainWindow.Show();
        }

        private void OnOAuthTokenReceived(string token)
        {
            // 在 UI 线程上触发事件
            Dispatcher.BeginInvoke(new Action(() =>
            {
                System.Diagnostics.Debug.WriteLine($"[App] OAuth token received, notifying LoginWindow");
                OAuthTokenReceived?.Invoke(token);
            }));
        }

        protected override void OnExit(ExitEventArgs e)
        {
            _pipeCts?.Cancel();
            _pipeCts?.Dispose();
            
            // 只有当我们拥有 Mutex 时才释放它
            if (_mutex != null && _mutexOwned)
            {
                try
                {
                    _mutex.ReleaseMutex();
                }
                catch (ApplicationException)
                {
                    // Mutex 可能已经被释放或不属于当前线程
                }
            }
            _mutex?.Dispose();
            
            base.OnExit(e);
        }
    }
}
