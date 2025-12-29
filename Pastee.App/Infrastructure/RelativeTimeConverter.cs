using System;
using System.Globalization;
using System.Windows.Data;

namespace Pastee.App.Infrastructure
{
    public class RelativeTimeConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is DateTimeOffset dto)
            {
                // 1. 强制校正：如果原始数据是 UTC (Offset 为 0)，确保转换到本地时区
                // 有些原始数据虽然解析为 DateTimeOffset 但如果不显式转 Local，计算 Diff 会出错
                var localTime = dto.ToLocalTime();
                var now = DateTimeOffset.Now;
                var diff = now - localTime;

                // 2. 避免显示负数时间 (由于机器时钟微小差异)
                if (diff.TotalSeconds < 0) return "Just now";

                // 3. 计算相对时间字符串 (全英文)
                if (diff.TotalSeconds < 60) return "Just now";
                if (diff.TotalMinutes < 60) return $"{(int)diff.TotalMinutes} mins ago";
                if (diff.TotalHours < 24) return $"{(int)diff.TotalHours} hours ago";
                if (diff.TotalDays < 7) return $"{(int)diff.TotalDays} days ago";

                // 4. 超过一周显示具体日期
                return localTime.ToString("yyyy/MM/dd HH:mm");
            }
            return value?.ToString() ?? string.Empty;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}

