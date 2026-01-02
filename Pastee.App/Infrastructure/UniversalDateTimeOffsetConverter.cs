using System;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Pastee.App.Infrastructure
{
    /// <summary>
    /// 确保 ISO 时间字符串始终被解析为 UTC，即使缺少 'Z' 后缀。
    /// 支持多种日期格式，包括带微秒的格式。
    /// </summary>
    public class UniversalDateTimeOffsetConverter : JsonConverter<DateTimeOffset>
    {
        // 支持的日期格式列表
        private static readonly string[] DateFormats = new[]
        {
            "yyyy-MM-dd'T'HH:mm:ss.ffffffK",  // ISO8601 with microseconds and timezone
            "yyyy-MM-dd'T'HH:mm:ss.ffffff",   // ISO8601 with microseconds, no timezone
            "yyyy-MM-dd'T'HH:mm:ss.fffK",     // ISO8601 with milliseconds and timezone
            "yyyy-MM-dd'T'HH:mm:ss.fff",      // ISO8601 with milliseconds, no timezone
            "yyyy-MM-dd'T'HH:mm:ssK",         // ISO8601 with timezone
            "yyyy-MM-dd'T'HH:mm:ss",          // ISO8601, no timezone
            "yyyy-MM-dd HH:mm:ss.ffffff",     // Space-separated with microseconds
            "yyyy-MM-dd HH:mm:ss.fff",        // Space-separated with milliseconds
            "yyyy-MM-dd HH:mm:ss",            // Space-separated
        };

        public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            var dateStr = reader.GetString();
            if (string.IsNullOrEmpty(dateStr)) return DateTimeOffset.MinValue;

            // 1. 首先尝试标准解析（支持带Z后缀的格式）
            if (DateTimeOffset.TryParse(dateStr, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out DateTimeOffset dto))
            {
                var finalDto = dto.ToUniversalTime();
                System.Diagnostics.Debug.WriteLine($"[DateConv] 标准解析成功: {dateStr} -> {finalDto:yyyy-MM-dd HH:mm:ss zzz}");
                return finalDto;
            }

            // 2. 尝试精确格式匹配（处理带微秒等特殊格式）
            foreach (var format in DateFormats)
            {
                if (DateTimeOffset.TryParseExact(dateStr, format, CultureInfo.InvariantCulture, 
                    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out dto))
                {
                    System.Diagnostics.Debug.WriteLine($"[DateConv] 格式'{format}'解析成功: {dateStr} -> {dto:yyyy-MM-dd HH:mm:ss zzz}");
                    return dto;
                }
            }

            // 3. 解析失败，记录警告
            System.Diagnostics.Debug.WriteLine($"[DateConv] ⚠️ 解析失败，返回MinValue: {dateStr}");
            return DateTimeOffset.MinValue;
        }

        public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options)
        {
            writer.WriteStringValue(value.ToString("O")); // 使用 ISO 8601 往回写
        }
    }
}

