using System;
using System.IO;
using System.Text.Json;
using System.Windows;

namespace Pastee.App.Services
{
    public enum AppTheme
    {
        Dark,
        Light
    }

    public static class ThemeService
    {
        private static readonly string _settingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "PasteeNative",
            "theme.json"
        );

        public static AppTheme CurrentTheme { get; private set; } = AppTheme.Dark;

        /// <summary>
        /// 加载保存的主题设置
        /// </summary>
        public static AppTheme LoadSavedTheme()
        {
            try
            {
                if (File.Exists(_settingsPath))
                {
                    var json = File.ReadAllText(_settingsPath);
                    var settings = JsonSerializer.Deserialize<ThemeSettings>(json);
                    if (settings != null && Enum.TryParse<AppTheme>(settings.Theme, out var theme))
                    {
                        CurrentTheme = theme;
                        return theme;
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ThemeService] Failed to load theme: {ex.Message}");
            }
            return AppTheme.Dark;
        }

        /// <summary>
        /// 保存主题设置
        /// </summary>
        public static void SaveTheme(AppTheme theme)
        {
            try
            {
                var dir = Path.GetDirectoryName(_settingsPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }

                var settings = new ThemeSettings { Theme = theme.ToString() };
                var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(_settingsPath, json);
                CurrentTheme = theme;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ThemeService] Failed to save theme: {ex.Message}");
            }
        }

        /// <summary>
        /// 应用主题到应用程序
        /// </summary>
        public static void ApplyTheme(AppTheme theme)
        {
            var app = Application.Current;
            if (app == null) return;

            var themePath = theme switch
            {
                AppTheme.Light => "Themes/Light.xaml",
                _ => "Themes/Dark.xaml"
            };

            try
            {
                // 创建新的资源字典
                var newTheme = new ResourceDictionary
                {
                    Source = new Uri(themePath, UriKind.Relative)
                };

                // 清除旧的主题资源并添加新的
                app.Resources.MergedDictionaries.Clear();
                app.Resources.MergedDictionaries.Add(newTheme);

                CurrentTheme = theme;
                SaveTheme(theme);

                System.Diagnostics.Debug.WriteLine($"[ThemeService] Applied theme: {theme}");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ThemeService] Failed to apply theme: {ex.Message}");
            }
        }

        /// <summary>
        /// 切换主题
        /// </summary>
        public static void ToggleTheme()
        {
            var newTheme = CurrentTheme == AppTheme.Dark ? AppTheme.Light : AppTheme.Dark;
            ApplyTheme(newTheme);
        }

        private class ThemeSettings
        {
            public string Theme { get; set; } = "Dark";
        }
    }
}









