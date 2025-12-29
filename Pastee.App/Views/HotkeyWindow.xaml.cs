using System;
using System.Windows;
using System.Windows.Controls;

namespace Pastee.App.Views
{
    public partial class HotkeyWindow : Window
    {
        public string SelectedHotkey { get; private set; } = "Win + V";

        public HotkeyWindow(string currentHotkey)
        {
            InitializeComponent();
            SelectedHotkey = currentHotkey;
            
            this.Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            // 根据当前热键高亮对应按钮
            HighlightCurrentHotkey(SelectedHotkey);
        }

        private void HighlightCurrentHotkey(string hotkey)
        {
            ClearPresetSelection();
            
            // 根据热键值找到对应按钮并高亮
            foreach (var child in HotkeyOptions.Children)
            {
                if (child is Button btn && btn.Content.ToString() == hotkey)
                {
                    btn.Tag = "Selected";
                    break;
                }
            }
        }

        private void ClearPresetSelection()
        {
            foreach (var child in HotkeyOptions.Children)
            {
                if (child is Button btn) btn.Tag = null;
            }
        }

        private void Preset_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn)
            {
                string content = btn.Content.ToString()!;
                SelectedHotkey = content;

                ClearPresetSelection();
                btn.Tag = "Selected";
            }
        }

        private void OnSave(object sender, RoutedEventArgs e)
        {
            DialogResult = true;
            Close();
        }

        private void OnCancel(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }
    }
}
