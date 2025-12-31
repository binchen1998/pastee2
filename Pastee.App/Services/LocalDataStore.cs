using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;
using Pastee.App.Models;

namespace Pastee.App.Services
{
    public class LocalDataStore
    {
        private readonly string _baseDirectory;
        private readonly string _dataFile;
        private readonly string _imageDirectory;
        private readonly string _draftFile;
        private readonly string _settingsFile;
        private static readonly System.Threading.SemaphoreSlim _fileLock = new System.Threading.SemaphoreSlim(1, 1);
        
        private readonly JsonSerializerOptions _options = new JsonSerializerOptions
        {
            WriteIndented = true,
            Converters = { 
                new JsonStringEnumConverter(),
                new Pastee.App.Infrastructure.FlexibleStringConverter(),
                new Pastee.App.Infrastructure.FlexibleBoolConverter(),
                new Pastee.App.Infrastructure.UniversalDateTimeOffsetConverter()
            }
        };

        public LocalDataStore()
        {
            _baseDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PasteeNative");
            _imageDirectory = Path.Combine(_baseDirectory, "images");
            _dataFile = Path.Combine(_baseDirectory, "clipboard.json");
            _draftFile = Path.Combine(_baseDirectory, "drafts.json");
            _settingsFile = Path.Combine(_baseDirectory, "settings.json");

            Directory.CreateDirectory(_baseDirectory);
            Directory.CreateDirectory(_imageDirectory);
        }

        public async Task SaveWindowSettingsAsync(double width, double height, string? hotkey = null, bool? hideAfterPaste = null, bool? sidebarVisible = null)
        {
            await _fileLock.WaitAsync();
            try
            {
                var current = await LoadWindowSettingsInternalAsync();
                
                var settings = new Dictionary<string, object> 
                { 
                    { "Width", width > 0 ? width : (current?.Width ?? 520) }, 
                    { "Height", height > 0 ? height : (current?.Height ?? 500) }
                };
                
                string finalHotkey = hotkey ?? current?.Hotkey ?? "Win + V";
                settings.Add("Hotkey", finalHotkey);
                
                bool finalHideAfterPaste = hideAfterPaste ?? current?.HideAfterPaste ?? true;
                settings.Add("HideAfterPaste", finalHideAfterPaste);
                
                bool finalSidebarVisible = sidebarVisible ?? current?.SidebarVisible ?? true;
                settings.Add("SidebarVisible", finalSidebarVisible);
                
                string json = JsonSerializer.Serialize(settings, _options);
                await File.WriteAllTextAsync(_settingsFile, json);
            }
            catch { }
            finally
            {
                _fileLock.Release();
            }
        }

        private async Task<WindowSettings?> LoadWindowSettingsInternalAsync()
        {
            if (!File.Exists(_settingsFile)) return null;
            try
            {
                string json = await File.ReadAllTextAsync(_settingsFile);
                return JsonSerializer.Deserialize<WindowSettings>(json, _options);
            }
            catch { return null; }
        }

        public async Task<WindowSettings?> LoadWindowSettingsAsync()
        {
            await _fileLock.WaitAsync();
            try
            {
                return await LoadWindowSettingsInternalAsync();
            }
            catch { return null; }
            finally
            {
                _fileLock.Release();
            }
        }

        public class WindowSettings
        {
            public double Width { get; set; }
            public double Height { get; set; }
            public string Hotkey { get; set; } = "Win + V";
            public bool HideAfterPaste { get; set; } = true;
            public bool SidebarVisible { get; set; } = true;
        }

    public async Task<IReadOnlyList<ClipboardEntry>> LoadDraftsAsync()
    {
        if (!File.Exists(_draftFile)) return Array.Empty<ClipboardEntry>();
        await _fileLock.WaitAsync();
        try
        {
            using (var stream = new FileStream(_draftFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                var items = await JsonSerializer.DeserializeAsync<List<ClipboardEntry>>(stream, _options);
                return items ?? (IReadOnlyList<ClipboardEntry>)Array.Empty<ClipboardEntry>();
            }
        }
        catch { return Array.Empty<ClipboardEntry>(); }
        finally { _fileLock.Release(); }
    }

    public async Task SaveDraftsAsync(IEnumerable<ClipboardEntry> entries)
    {
        await _fileLock.WaitAsync();
        try
        {
            using (var stream = new FileStream(_draftFile, FileMode.Create, FileAccess.Write, FileShare.Read))
            {
                await JsonSerializer.SerializeAsync(stream, entries, _options);
                await stream.FlushAsync();
            }
        }
        catch { }
        finally { _fileLock.Release(); }
    }

        public async Task<IReadOnlyList<ClipboardEntry>> LoadAsync()
        {
            if (!File.Exists(_dataFile))
            {
                return Array.Empty<ClipboardEntry>();
            }

            await _fileLock.WaitAsync();
            try
            {
                using (var stream = new FileStream(_dataFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                {
                    var items = await JsonSerializer.DeserializeAsync<List<ClipboardEntry>>(stream, _options);
                    return items ?? (IReadOnlyList<ClipboardEntry>)Array.Empty<ClipboardEntry>();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[LocalData] 读取失败: {ex.Message}");
                return Array.Empty<ClipboardEntry>();
            }
            finally
            {
                _fileLock.Release();
            }
        }

        public async Task SaveAsync(IEnumerable<ClipboardEntry> entries)
        {
            await _fileLock.WaitAsync();
            try
            {
                using (var stream = new FileStream(_dataFile, FileMode.Create, FileAccess.Write, FileShare.Read))
                {
                    await JsonSerializer.SerializeAsync(stream, entries, _options);
                    await stream.FlushAsync();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[LocalData] 写入失败: {ex.Message}");
            }
            finally
            {
                _fileLock.Release();
            }
        }

        public async Task<string> SaveImageAsync(BitmapSource image)
        {
            var fileName = string.Format("{0:N}.png", Guid.NewGuid());
            return await SaveImageWithFileNameAsync(image, fileName);
        }

        public async Task<string> SaveOriginalImageAsync(string id, BitmapSource image)
        {
            var fileName = string.Format("orig_{0}.png", id);
            return await SaveImageWithFileNameAsync(image, fileName);
        }

        public string? GetCachedOriginalImagePath(string id)
        {
            var fileName = string.Format("orig_{0}.png", id);
            var path = Path.Combine(_imageDirectory, fileName);
            return File.Exists(path) ? path : null;
        }

        private async Task<string> SaveImageWithFileNameAsync(BitmapSource image, string fileName)
        {
            var path = Path.Combine(_imageDirectory, fileName);

            // 强制转换为 Bgr32 格式，避免剪贴板图像 Alpha 通道异常导致的全黑问题
            var convertedImage = new FormatConvertedBitmap(image, System.Windows.Media.PixelFormats.Bgr32, null, 0);

            await using (var fileStream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.Read))
            {
                var encoder = new PngBitmapEncoder();
                encoder.Frames.Add(BitmapFrame.Create(convertedImage));
                encoder.Save(fileStream);
                await fileStream.FlushAsync();
            }

            return path;
        }
    }
}

