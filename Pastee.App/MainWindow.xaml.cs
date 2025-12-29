using System;
using System.ComponentModel;
using System.Windows;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Interop;
using System.Windows.Threading;
using Pastee.App.Models;
using Pastee.App.Services;
using Pastee.App.ViewModels;
using Pastee.App.Views;
using Forms = System.Windows.Forms;

namespace Pastee.App
{
    public partial class MainWindow : Window
    {
        private readonly ClipboardWatcher _clipboardWatcher = new ClipboardWatcher();
        private readonly MainViewModel _viewModel = new MainViewModel();
        private readonly LowLevelKeyboardHook _keyboardHook = new LowLevelKeyboardHook();
        private readonly HotkeyService _hotkeyService = new HotkeyService();
        private readonly UpdateService _updateService = new UpdateService();
        private readonly string _token;
        private Forms.NotifyIcon? _notifyIcon;
        private bool _isExplicitExit = false;
        private ClipboardPopup? _popup;
        private DispatcherTimer? _updateCheckTimer;
        private const int UpdateCheckIntervalHours = 6;

        public MainWindow(string token)
        {
            InitializeComponent();
            _token = token;
            DataContext = _viewModel;
            
            // Ensure this window stays hidden
            this.ShowInTaskbar = false;
            this.WindowState = WindowState.Normal;
            this.Hide();

            Loaded += OnLoaded;
            Closing += OnClosing;
            _viewModel.RequestEdit += OnRequestEdit;
            _viewModel.ItemCopied += OnItemCopied;
            _viewModel.PropertyChanged += OnViewModelPropertyChanged;

            InitializeTrayIcon();
            _popup = new ClipboardPopup(_viewModel);
            _popup.RequestLogout += (s, e) => OnLogout(this, new RoutedEventArgs());
            
            // 启动时显示主窗口
            ShowPopup();
        }

        private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(MainViewModel.CurrentHotkey))
            {
                System.Diagnostics.Debug.WriteLine($"[MainWindow] Hotkey changing to: {_viewModel.CurrentHotkey}");
                
                // 统一使用底层钩子注册任何热键，确保拦截成功率
                _keyboardHook.Install(_viewModel.CurrentHotkey);
                
                // 实时持久化快捷键变更
                if (_popup != null)
                {
                    var dataStore = new LocalDataStore();
                    _ = dataStore.SaveWindowSettingsAsync(_popup.Width, _popup.Height, _viewModel.CurrentHotkey);
                }
            }
        }

        private void InitializeTrayIcon()
        {
            // 从文件加载托盘图标
            _notifyIcon = new Forms.NotifyIcon();
            
            // 尝试从exe同目录加载图标文件
            var iconPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "pastee.ico");
            if (System.IO.File.Exists(iconPath))
            {
                _notifyIcon.Icon = new System.Drawing.Icon(iconPath);
            }
            else
            {
                // 如果图标文件不存在，使用默认图标
                _notifyIcon.Icon = System.Drawing.SystemIcons.Application;
            }
            
            _notifyIcon.Text = "Pastee - Global Hotkey Active";
            _notifyIcon.Visible = true;

            var contextMenu = new Forms.ContextMenuStrip();
            contextMenu.Items.Add("Show Clipboard", null, (s, e) => ShowPopup());
            contextMenu.Items.Add("Settings", null, (s, e) => OnSettingsClick(s, EventArgs.Empty));
            contextMenu.Items.Add(new Forms.ToolStripSeparator());
            contextMenu.Items.Add("Exit", null, (s, e) => ExitApplication());

            _notifyIcon.ContextMenuStrip = contextMenu;
            _notifyIcon.Click += (s, e) => {
                if (e is System.Windows.Forms.MouseEventArgs me && me.Button == System.Windows.Forms.MouseButtons.Left)
                {
                    ShowPopup();
                }
            };
            _notifyIcon.DoubleClick += (s, e) => ShowPopup();
        }

        private void ShowPopup()
        {
            if (_popup == null) _popup = new ClipboardPopup(_viewModel);
            _popup.ShowPopup();
        }

        private void ExitApplication()
        {
            _isExplicitExit = true;
            _updateCheckTimer?.Stop();
            _popup?.Close();
            _keyboardHook.Uninstall();
            _hotkeyService.UnregisterHotkey();
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
            }
            Application.Current.Shutdown();
        }

        private async void OnLoaded(object? sender, RoutedEventArgs e)
        {
            await _viewModel.InitializeAsync(_token);
            _clipboardWatcher.ClipboardUpdated += OnClipboardUpdated;
            _clipboardWatcher.Start(this);
            
            // Initialize Hotkey via Low-Level Hook
            _keyboardHook.HotkeyPressed += ShowPopup;
            _keyboardHook.Install(_viewModel.CurrentHotkey);

            // Re-ensure hidden after loading
            this.Hide();

            // 启动自动更新检测
            await CheckForUpdatesAsync();
            StartUpdateCheckTimer();
        }

        /// <summary>
        /// 启动更新检查定时器（每6小时检查一次）
        /// </summary>
        private void StartUpdateCheckTimer()
        {
            _updateCheckTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromHours(UpdateCheckIntervalHours)
            };
            _updateCheckTimer.Tick += async (s, e) => await CheckForUpdatesAsync();
            _updateCheckTimer.Start();
            System.Diagnostics.Debug.WriteLine($"[MainWindow] Update check timer started, interval: {UpdateCheckIntervalHours} hours");
        }

        /// <summary>
        /// 检查更新
        /// </summary>
        private async Task CheckForUpdatesAsync()
        {
            try
            {
                System.Diagnostics.Debug.WriteLine("[MainWindow] Checking for updates...");
                var updateInfo = await _updateService.CheckForUpdateAsync();

                if (updateInfo != null && updateInfo.UpdateAvailable)
                {
                    System.Diagnostics.Debug.WriteLine($"[MainWindow] Update available: {updateInfo.LatestVersion}");
                    
                    // 在 UI 线程上显示更新窗口
                    await Dispatcher.InvokeAsync(() =>
                    {
                        var updateWindow = new UpdateWindow(updateInfo);
                        updateWindow.Show();
                    });
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine("[MainWindow] No update available");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MainWindow] Update check error: {ex.Message}");
            }
        }

        private void OnClosing(object? sender, CancelEventArgs e)
        {
            if (!_isExplicitExit)
            {
                e.Cancel = true;
                this.Hide();
                return;
            }

            _keyboardHook.Uninstall();
            _clipboardWatcher.ClipboardUpdated -= OnClipboardUpdated;
            _clipboardWatcher.Dispose();
        }

        private async void OnClipboardUpdated(object? sender, EventArgs e)
        {
            await _viewModel.OnClipboardUpdatedAsync();
        }

        private async void OnRequestEdit(object? sender, ClipboardEntry entry)
        {
            var dialog = new EditTextWindow(entry.Content ?? string.Empty, "Edit clipboard content:", 0, true)
            {
                Owner = _popup, // Set owner to popup so it centers there
                Title = "Edit Text"
            };

            if (dialog.ShowDialog() == true)
            {
                await _viewModel.UpdateEntryTextAsync(entry, dialog.EditedText);
            }
        }

        private void OnItemCopied(object? sender, EventArgs e)
        {
            _popup?.ShowToast();
        }

        private void OnSettingsClick(object? sender, EventArgs e)
        {
            var settingsWindow = new Views.SettingsWindow(_viewModel)
            {
                Title = "Settings"
            };

            // 关键修复：只有当弹窗已显示时才设置 Owner，否则会引发 InvalidOperationException
            if (_popup != null && _popup.IsVisible)
            {
                settingsWindow.Owner = _popup;
            }
            else
            {
                // 如果弹窗没显示，让设置窗口在屏幕中央显示
                settingsWindow.WindowStartupLocation = WindowStartupLocation.CenterScreen;
            }

            if (settingsWindow.ShowDialog() == true && settingsWindow.RequestedLogout)
            {
                OnLogout(this, new RoutedEventArgs());
            }
        }

        private void OnLogout(object sender, RoutedEventArgs e)
        {
            _isExplicitExit = true;
            var authService = new AuthService();
            authService.Logout();

            _popup?.Close();
            _keyboardHook.Uninstall();
            _hotkeyService.UnregisterHotkey();

            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
            }

            var loginWindow = new LoginWindow();
            loginWindow.Show();
            this.Close();
        }
    }
}
