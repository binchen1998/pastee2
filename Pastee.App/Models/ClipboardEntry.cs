using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;
using Pastee.App.Infrastructure;

namespace Pastee.App.Models
{
    public class ClipboardEntry : INotifyPropertyChanged
    {
        [JsonPropertyName("id")]
        [System.Text.Json.Serialization.JsonConverter(typeof(Pastee.App.Infrastructure.FlexibleStringConverter))]
        public string Id { get; set; } = Guid.NewGuid().ToString();

        [JsonPropertyName("content_type")]
        public string ContentType { get; set; } = "text";

        [JsonPropertyName("content")]
        [System.Text.Json.Serialization.JsonConverter(typeof(Pastee.App.Infrastructure.FlexibleStringConverter))]
        public string? Content { get; set; }

        [JsonPropertyName("file_path")]
        public string? FilePath { get; set; }

        [JsonPropertyName("file_name")]
        public string? FileName { get; set; }

        [JsonPropertyName("thumbnail")]
        public string? Thumbnail { get; set; }

        [JsonPropertyName("original_deleted")]
        public bool OriginalDeleted { get; set; }

        [JsonPropertyName("created_at")]
        [JsonConverter(typeof(Pastee.App.Infrastructure.UniversalDateTimeOffsetConverter))]
        public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;

        [JsonPropertyName("is_bookmarked")]
        [System.Text.Json.Serialization.JsonConverter(typeof(Pastee.App.Infrastructure.FlexibleBoolConverter))]
        public bool IsBookmarked
        {
            get => _isBookmarked;
            set { _isBookmarked = value; OnPropertyChanged(); }
        }

        private bool _isBookmarked;

        // --- 前端本地追加的状态 ---
        private string? _displayImageData;
        private bool _isThumbnail;
        private bool _isDownloadingOriginal;

        [JsonIgnore]
        public string? DisplayImageData
        {
            get => _displayImageData;
            set { _displayImageData = value; OnPropertyChanged(); }
        }

        [JsonIgnore]
        public bool IsThumbnail
        {
            get => _isThumbnail;
            set { _isThumbnail = value; OnPropertyChanged(); }
        }

        [JsonIgnore]
        public bool IsDownloadingOriginal
        {
            get => _isDownloadingOriginal;
            set { _isDownloadingOriginal = value; OnPropertyChanged(); }
        }

        // --- 上传状态 ---
        private bool _isUploading;
        private bool _uploadFailed;

        [JsonIgnore]
        public bool IsUploading
        {
            get => _isUploading;
            set { _isUploading = value; OnPropertyChanged(); }
        }

        [JsonPropertyName("upload_failed")]
        public bool UploadFailed
        {
            get => _uploadFailed;
            set { _uploadFailed = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        public void UpdateText(string newText)
        {
            Content = newText;
            OnPropertyChanged(nameof(Content));
        }

        public void InitializeImageState()
        {
            if (ContentType != "image") return;

            // 1. 优先级：后端返回的缩略图 (通常在 Content 中，是 base64 格式)
            if (!string.IsNullOrEmpty(Content) && FlexibleStringConverter.IsBase64Like(Content))
            {
                DisplayImageData = Content;
                IsThumbnail = true;
            }
            // 2. 备选：Thumbnail 字段
            else if (!string.IsNullOrEmpty(Thumbnail))
            {
                DisplayImageData = Thumbnail;
                // 判断是否为缩略图：
                // - 如果是本地文件路径（不是 base64），则是原图
                // - 如果路径包含 "orig" 前缀，则是下载的原图
                // - 只有 base64 格式的才是缩略图
                bool isLocalFilePath = Thumbnail.Contains(":\\") || Thumbnail.StartsWith("/");
                bool isOriginalImage = Thumbnail.Contains("orig_") || Thumbnail.Contains("original");
                IsThumbnail = !isLocalFilePath && !isOriginalImage && FlexibleStringConverter.IsBase64Like(Thumbnail);
            }
        }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

