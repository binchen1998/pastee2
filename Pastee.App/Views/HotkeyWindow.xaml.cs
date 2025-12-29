using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace Pastee.App.Views
{
    public partial class HotkeyWindow : Window
    {
        public string SelectedHotkey { get; private set; } = "Win + V";
        private bool _isRecording = false;
        private string? _recordedHotkey = null;

        public HotkeyWindow(string currentHotkey)
        {
            InitializeComponent();
            SelectedHotkey = currentHotkey;
            
            this.Loaded += OnLoaded;
            this.PreviewKeyDown += OnPreviewKeyDown;
            this.PreviewKeyUp += OnPreviewKeyUp;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            // 根据当前热键高亮对应按钮
            HighlightCurrentHotkey(SelectedHotkey);
        }

        private void OnRecordClick(object sender, RoutedEventArgs e)
        {
            if (_isRecording)
            {
                StopRecording();
            }
            else
            {
                StartRecording();
            }
        }

        private void StartRecording()
        {
            _isRecording = true;
            _recordedHotkey = null;
            RecordButton.Tag = "Recording";
            RecordButton.Content = "⏹ Stop";
            RecordedHotkeyText.Text = "Press your hotkey combination...";
            RecordedHotkeyText.Foreground = (Brush)FindResource("AccentBrush");
            RecordingBorder.BorderBrush = (Brush)FindResource("AccentBrush");
            
            // 聚焦窗口以接收键盘输入
            this.Focus();
        }

        private void StopRecording()
        {
            _isRecording = false;
            RecordButton.Tag = null;
            RecordButton.Content = "🎤 Record";
            RecordingBorder.BorderBrush = (Brush)FindResource("BorderBrush");
            
            if (string.IsNullOrEmpty(_recordedHotkey))
            {
                RecordedHotkeyText.Text = "Click 'Record' and press keys...";
                RecordedHotkeyText.Foreground = (Brush)FindResource("TextSecondaryBrush");
            }
        }

        private void OnPreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (!_isRecording) return;

            e.Handled = true;

            // 获取实际按键（处理系统键）
            Key key = e.Key == Key.System ? e.SystemKey : e.Key;

            // 忽略单独的修饰键
            if (key == Key.LeftCtrl || key == Key.RightCtrl ||
                key == Key.LeftAlt || key == Key.RightAlt ||
                key == Key.LeftShift || key == Key.RightShift ||
                key == Key.LWin || key == Key.RWin)
            {
                // 显示当前按下的修饰键
                var modifiers = BuildModifierString();
                if (!string.IsNullOrEmpty(modifiers))
                {
                    RecordedHotkeyText.Text = modifiers + " + ...";
                }
                return;
            }

            // 构建热键字符串
            var hotkeyString = BuildHotkeyString(key);
            if (!string.IsNullOrEmpty(hotkeyString))
            {
                _recordedHotkey = hotkeyString;
                RecordedHotkeyText.Text = hotkeyString;
                RecordedHotkeyText.Foreground = (Brush)FindResource("TextPrimaryBrush");
                
                // 自动选择这个热键
                ClearPresetSelection();
                SelectedHotkey = hotkeyString;
                
                // 自动停止录制
                StopRecording();
            }
        }

        private void OnPreviewKeyUp(object sender, KeyEventArgs e)
        {
            // 不需要特殊处理
        }

        private string BuildModifierString()
        {
            var parts = new List<string>();
            
            if (Keyboard.IsKeyDown(Key.LWin) || Keyboard.IsKeyDown(Key.RWin))
                parts.Add("Win");
            if (Keyboard.IsKeyDown(Key.LeftCtrl) || Keyboard.IsKeyDown(Key.RightCtrl))
                parts.Add("Ctrl");
            if (Keyboard.IsKeyDown(Key.LeftAlt) || Keyboard.IsKeyDown(Key.RightAlt))
                parts.Add("Alt");
            if (Keyboard.IsKeyDown(Key.LeftShift) || Keyboard.IsKeyDown(Key.RightShift))
                parts.Add("Shift");
            
            return string.Join(" + ", parts);
        }

        private string? BuildHotkeyString(Key key)
        {
            var parts = new List<string>();
            
            // 检查修饰键
            bool hasWin = Keyboard.IsKeyDown(Key.LWin) || Keyboard.IsKeyDown(Key.RWin);
            bool hasCtrl = Keyboard.IsKeyDown(Key.LeftCtrl) || Keyboard.IsKeyDown(Key.RightCtrl);
            bool hasAlt = Keyboard.IsKeyDown(Key.LeftAlt) || Keyboard.IsKeyDown(Key.RightAlt);
            bool hasShift = Keyboard.IsKeyDown(Key.LeftShift) || Keyboard.IsKeyDown(Key.RightShift);

            // 必须至少有一个修饰键
            if (!hasWin && !hasCtrl && !hasAlt && !hasShift)
            {
                RecordedHotkeyText.Text = "Please include a modifier key (Ctrl, Alt, Shift, Win)";
                return null;
            }

            if (hasWin) parts.Add("Win");
            if (hasCtrl) parts.Add("Ctrl");
            if (hasAlt) parts.Add("Alt");
            if (hasShift) parts.Add("Shift");

            // 转换按键名称
            string keyName = ConvertKeyName(key);
            parts.Add(keyName);

            return string.Join(" + ", parts);
        }

        private string ConvertKeyName(Key key)
        {
            // 字母键 A-Z
            if (key >= Key.A && key <= Key.Z)
                return key.ToString();
            
            // 数字键 0-9
            if (key >= Key.D0 && key <= Key.D9)
                return key.ToString().Substring(1);
            
            // 小键盘数字
            if (key >= Key.NumPad0 && key <= Key.NumPad9)
                return "Num" + key.ToString().Substring(6);
            
            // 功能键 F1-F12
            if (key >= Key.F1 && key <= Key.F12)
                return key.ToString();

            // 特殊键
            return key switch
            {
                Key.Space => "Space",
                Key.Tab => "Tab",
                Key.Enter => "Enter",
                Key.Escape => "Esc",
                Key.Back => "Backspace",
                Key.Delete => "Delete",
                Key.Insert => "Insert",
                Key.Home => "Home",
                Key.End => "End",
                Key.PageUp => "PageUp",
                Key.PageDown => "PageDown",
                Key.Up => "Up",
                Key.Down => "Down",
                Key.Left => "Left",
                Key.Right => "Right",
                Key.OemTilde => "`",
                Key.OemMinus => "-",
                Key.OemPlus => "=",
                Key.OemOpenBrackets => "[",
                Key.OemCloseBrackets => "]",
                Key.OemPipe => "\\",
                Key.OemSemicolon => ";",
                Key.OemQuotes => "'",
                Key.OemComma => ",",
                Key.OemPeriod => ".",
                Key.OemQuestion => "/",
                _ => key.ToString()
            };
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
