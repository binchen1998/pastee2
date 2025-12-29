using System;
using System.Globalization;
using System.IO;
using System.Windows.Data;
using System.Windows.Media.Imaging;

namespace Pastee.App.Infrastructure
{
    public class ImagePathConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            var path = value as string;
            if (string.IsNullOrEmpty(path)) return null;

            try
            {
                // 1. 处理 Base64
                if (IsBase64(path))
                {
                    System.Diagnostics.Debug.WriteLine($"[ImageConv] 尝试解析 Base64 (长度: {path.Length})");
                    string base64Data = path;
                    if (path.Contains(",")) base64Data = path.Split(',')[1];
                    
                    // 清理 Base64 字符串中的非法字符（如换行符）
                    base64Data = base64Data.Trim().Replace("\n", "").Replace("\r", "");
                    
                    byte[] binaryData = System.Convert.FromBase64String(base64Data);
                    using (var ms = new MemoryStream(binaryData))
                    {
                        var bitmap = new BitmapImage();
                        bitmap.BeginInit();
                        bitmap.CacheOption = BitmapCacheOption.OnLoad;
                        bitmap.StreamSource = ms;
                        bitmap.EndInit();
                        bitmap.Freeze();
                        return bitmap;
                    }
                }

                // 2. 处理本地文件路径
                if (path.Length < 260 && File.Exists(path))
                {
                    System.Diagnostics.Debug.WriteLine($"[ImageConv] 加载本地图片: {path}");
                    byte[] imageData = File.ReadAllBytes(path);
                    using (var ms = new MemoryStream(imageData))
                    {
                        var bitmap = new BitmapImage();
                        bitmap.BeginInit();
                        bitmap.CacheOption = BitmapCacheOption.OnLoad;
                        bitmap.StreamSource = ms;
                        bitmap.EndInit();
                        bitmap.Freeze();
                        return bitmap;
                    }
                }

                // 3. 处理网络 URL (含相对路径补全)
                if (path.StartsWith("http", StringComparison.OrdinalIgnoreCase) || path.StartsWith("/"))
                {
                    string finalUrl = path.StartsWith("/") ? $"https://api.pastee-app.com{path}" : path;
                    System.Diagnostics.Debug.WriteLine($"[ImageConv] 加载网络图片: {finalUrl}");
                    var bitmap = new BitmapImage();
                    bitmap.BeginInit();
                    bitmap.CacheOption = BitmapCacheOption.OnLoad;
                    bitmap.UriSource = new Uri(finalUrl);
                    bitmap.EndInit();
                    bitmap.Freeze();
                    return bitmap;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ImageConv] 转换异常: {ex.Message}. 路径预览: {path.Substring(0, Math.Min(50, path.Length))}");
                return null;
            }
            return null;
        }

        private bool IsBase64(string base64String)
        {
            if (string.IsNullOrEmpty(base64String)) return false;
            if (base64String.StartsWith("data:image", StringComparison.OrdinalIgnoreCase)) return true;
            if (base64String.Length < 100) return false; // 路径通常没这么长，base64 往往很长
            return true;
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}

