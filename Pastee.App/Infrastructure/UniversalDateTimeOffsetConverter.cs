using System;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Pastee.App.Infrastructure
{
    /// <summary>
    /// 确保 ISO 时间字符串始终被解析为 UTC，即使缺少 'Z' 后缀。
    /// </summary>
    public class UniversalDateTimeOffsetConverter : JsonConverter<DateTimeOffset>
    {
        public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            var dateStr = reader.GetString();
            if (string.IsNullOrEmpty(dateStr)) return DateTimeOffset.MinValue;

            // 关键修复：强制将服务器返回的 ISO 字符串视为 UTC 时间 (AssumeUniversal)
            // 这样即使后端返回 "2025-12-27T03:14:00"（不带 Z），C# 也会将其识别为 UTC 03:14
            // 随后在 UI 层调用 .ToLocalTime() 就会正确变为东八区的 11:14
            if (DateTimeOffset.TryParse(dateStr, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out DateTimeOffset dto))
            {
                var finalDto = dto.ToUniversalTime(); // 确保内部存储始终是绝对 UTC
                System.Diagnostics.Debug.WriteLine($"[DateConv] 原始: {dateStr} -> 解析(UTC): {finalDto:yyyy-MM-dd HH:mm:ss zzz}");
                return finalDto;
            }

            return DateTimeOffset.MinValue;
        }

        public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options)
        {
            writer.WriteStringValue(value.ToString("O")); // 使用 ISO 8601 往回写
        }
    }
}

