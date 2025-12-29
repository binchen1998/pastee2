using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;

namespace Pastee.App.Models
{
    public class Category : INotifyPropertyChanged
    {
        [JsonPropertyName("id")]
        [System.Text.Json.Serialization.JsonConverter(typeof(Pastee.App.Infrastructure.FlexibleStringConverter))]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("item_count")]
        public int ItemCount { get; set; }

        [JsonPropertyName("is_shared")]
        public bool IsShared { get; set; }

        [JsonPropertyName("allow_member_edit")]
        public bool AllowMemberEdit { get; set; }

        [JsonPropertyName("is_joined")]
        public bool IsJoined { get; set; }

        [JsonPropertyName("is_creator")]
        public bool IsCreator { get; set; }

        private bool _isSelected;
        [JsonIgnore]
        public bool IsSelected
        {
            get => _isSelected;
            set { _isSelected = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

