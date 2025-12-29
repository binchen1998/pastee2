using System;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Pastee.App.Infrastructure
{
    /// <summary>
    /// 灵活的字符串转换器：支持将 JSON 中的数字、布尔值等直接读取为 C# 字符串。
    /// </summary>
    public class FlexibleStringConverter : JsonConverter<string>
    {
        public override string Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Number)
            {
                return reader.TryGetInt64(out long l) ? l.ToString() : reader.GetDouble().ToString();
            }
            if (reader.TokenType == JsonTokenType.String)
            {
                return reader.GetString();
            }
            if (reader.TokenType == JsonTokenType.True || reader.TokenType == JsonTokenType.False)
            {
                return reader.GetBoolean().ToString();
            }
            
            using (JsonDocument doc = JsonDocument.ParseValue(ref reader))
            {
                return doc.RootElement.GetRawText();
            }
        }

        public override void Write(Utf8JsonWriter writer, string value, JsonSerializerOptions options)
        {
            writer.WriteStringValue(value);
        }

        public static bool IsBase64Like(string? s)
        {
            if (string.IsNullOrEmpty(s)) return false;
            if (s.StartsWith("data:image", StringComparison.OrdinalIgnoreCase)) return true;
            return s.Length > 100;
        }
    }
}

