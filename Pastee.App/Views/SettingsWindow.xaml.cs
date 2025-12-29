using System;
using System.IO;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Input;
using Microsoft.Win32;
using System.Reflection;
using Pastee.App.Models;
using Pastee.App.Services;
using static Pastee.App.Services.ThemeService;

namespace Pastee.App.Views
{
    public partial class SettingsWindow : Window
    {
        public bool RequestedLogout { get; private set; }
        private const string AppName = "PasteeApp";
        private readonly ViewModels.MainViewModel _viewModel;

        public SettingsWindow(ViewModels.MainViewModel viewModel)
        {
            InitializeComponent();
            _viewModel = viewModel;
            EmailText.Text = viewModel.UserEmail;
            DeviceIdText.Text = viewModel.DeviceId;
            
            // 设置版本号
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            VersionText.Text = $"Version {version?.Major}.{version?.Minor}.{version?.Build}";
            
            InitializeAutoStartStatus();
            InitializeHideAfterPasteStatus();
            InitializeThemeStatus();
            
            // 检查是否是管理员，显示管理员面板入口
            if (AdminService.IsAdminEmail(viewModel.UserEmail))
            {
                AdminPanelSection.Visibility = Visibility.Visible;
            }
        }

        private void InitializeThemeStatus()
        {
            DarkModeCheckBox.IsChecked = ThemeService.CurrentTheme == AppTheme.Dark;
            UpdateThemeIcon();
        }

        private void UpdateThemeIcon()
        {
            if (ThemeService.CurrentTheme == AppTheme.Dark)
            {
                ThemeIcon.Text = "🌙";
            }
            else
            {
                ThemeIcon.Text = "☀️";
            }
        }

        private void OnThemeToggle(object sender, RoutedEventArgs e)
        {
            var newTheme = DarkModeCheckBox.IsChecked == true ? AppTheme.Dark : AppTheme.Light;
            ThemeService.SaveTheme(newTheme);
            UpdateThemeIcon();
            
            // 询问用户是否重启应用
            var themeName = newTheme == AppTheme.Dark ? "Dark Mode" : "Light Mode";
            var result = MessageBox.Show(
                $"Theme changed to {themeName}.\n\nRestart the app now to apply changes?",
                "Restart Required",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);
            
            if (result == MessageBoxResult.Yes)
            {
                RestartApplication();
            }
        }

        private void RestartApplication()
        {
            try
            {
                // 获取当前可执行文件路径
                var exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName;
                if (!string.IsNullOrEmpty(exePath))
                {
                    // 启动新实例
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = exePath,
                        UseShellExecute = true
                    });
                    
                    // 关闭当前应用
                    Application.Current.Shutdown();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to restart: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void InitializeHideAfterPasteStatus()
        {
            HideAfterPasteCheckBox.IsChecked = _viewModel.HideAfterPaste;
        }

        private void OnHideAfterPasteToggle(object sender, RoutedEventArgs e)
        {
            _viewModel.HideAfterPaste = HideAfterPasteCheckBox.IsChecked ?? true;
        }

        private void InitializeAutoStartStatus()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false))
                {
                    AutoStartCheckBox.IsChecked = key?.GetValue(AppName) != null;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Settings] Failed to read auto-start registry: {ex.Message}");
            }
        }

        private void OnAutoStartToggle(object sender, RoutedEventArgs e)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true))
                {
                    if (AutoStartCheckBox.IsChecked == true)
                    {
                        string path = Assembly.GetExecutingAssembly().Location;
                        // For .NET Core apps, .location might point to .dll, we want the .exe
                        if (path.EndsWith(".dll")) path = path.Substring(0, path.Length - 4) + ".exe";
                        key.SetValue(AppName, $"\"{path}\"");
                        System.Diagnostics.Debug.WriteLine($"[Settings] Auto-start enabled: {path}");
                    }
                    else
                    {
                        key.DeleteValue(AppName, false);
                        System.Diagnostics.Debug.WriteLine("[Settings] Auto-start disabled");
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to change auto-start setting: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void OnClose(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void OnHotkeySettingsClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            var hotkeyWindow = new HotkeyWindow(_viewModel.CurrentHotkey)
            {
                Owner = this
            };
            if (hotkeyWindow.ShowDialog() == true)
            {
                _viewModel.CurrentHotkey = hotkeyWindow.SelectedHotkey;
            }
        }

        private async void OnClearCacheClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            var confirm = new ConfirmWindow("Are you sure you want to clear all cached data and images? This will reset your local database.", "Clear")
            {
                Owner = this
            };

            if (confirm.ShowDialog() == true)
            {
                try
                {
                    var dataStore = new LocalDataStore();
                    
                    // 1. 清空本地数据库
                    await dataStore.SaveAsync(new List<ClipboardEntry>());
                    await dataStore.SaveDraftsAsync(new List<ClipboardEntry>());
                    
                    // 2. 删除图片缓存
                    string imagePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PasteeNative", "images");
                    if (Directory.Exists(imagePath))
                    {
                        foreach (var file in Directory.GetFiles(imagePath))
                        {
                            try { File.Delete(file); } catch { }
                        }
                    }

                    MessageBox.Show(this, "Cache cleared successfully. Please refresh the app to see changes.", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, $"Failed to clear cache: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void OnLogoutClick(object sender, RoutedEventArgs e)
        {
            RequestedLogout = true;
            DialogResult = true;
            Close();
        }

        private async void OnCheckUpdatesClick(object sender, RoutedEventArgs e)
        {
            try
            {
                var updateService = new UpdateService();
                var currentVersion = UpdateService.GetCurrentVersion();
                
                var response = await updateService.CheckForUpdateAsync();
                
                if (response != null && response.UpdateAvailable)
                {
                    // 关闭设置窗口
                    DialogResult = false;
                    Close();
                    
                    // 显示更新窗口
                    var updateWindow = new UpdateWindow(response)
                    {
                        WindowStartupLocation = WindowStartupLocation.CenterScreen
                    };
                    updateWindow.ShowDialog();
                }
                else
                {
                    MessageBox.Show(this, $"You are using the latest version ({currentVersion}).", "No Updates", MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, $"Failed to check for updates: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void OnSupportEmailClick(object sender, MouseButtonEventArgs e)
        {
            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "mailto:binary.chen@gmail.com?subject=Pastee Support",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Settings] Failed to open email client: {ex.Message}");
            }
        }

        private void OnAdminPanelClick(object sender, MouseButtonEventArgs e)
        {
            // 先关闭设置窗口，避免遮挡
            DialogResult = false;
            Close();
            
            // 打开管理员面板
            var adminWindow = new AdminDashboardWindow();
            adminWindow.Show();
        }
    }
}

