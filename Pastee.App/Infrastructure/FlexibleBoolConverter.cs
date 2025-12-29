using System;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Pastee.App.Infrastructure
{
    /// <summary>
    /// 灵活的布尔转换器：支持将 JSON 中的数字 (0/1) 或字符串 ("true"/"false") 转换为 C# bool。
    /// </summary>
    public class FlexibleBoolConverter : JsonConverter<bool>
    {
        public override bool Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.True) return true;
            if (reader.TokenType == JsonTokenType.False) return false;
            
            if (reader.TokenType == JsonTokenType.Number)
            {
                return reader.TryGetInt64(out long l) ? l != 0 : reader.GetDouble() != 0;
            }
            
            if (reader.TokenType == JsonTokenType.String)
            {
                string s = reader.GetString();
                if (bool.TryParse(s, out bool b)) return b;
                if (s == "1") return true;
                if (s == "0") return false;
            }

            return false;
        }

        public override void Write(Utf8JsonWriter writer, bool value, JsonSerializerOptions options)
        {
            writer.WriteBooleanValue(value);
        }
    }
}

