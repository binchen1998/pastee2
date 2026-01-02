using System.Windows;

namespace Pastee.App.Views
{
    public partial class ConfirmWindow : Window
    {
        public ConfirmWindow(string message, bool showCancelButton = true, string confirmText = "Delete", string titleText = "Confirm Action")
        {
            InitializeComponent();
            MessageText.Text = message;
            TitleText.Text = titleText;
            ConfirmButton.Content = confirmText;
            
            if (!showCancelButton)
            {
                CancelButton.Visibility = Visibility.Collapsed;
                // 使用 Accent 颜色作为非危险操作的按钮颜色
                ConfirmButton.Background = (System.Windows.Media.Brush)FindResource("AccentBrush");
            }
            else
            {
                // 删除确认等危险操作使用红色
                ConfirmButton.Background = (System.Windows.Media.Brush)FindResource("DeleteBrush");
            }
        }

        private void OnConfirm(object sender, RoutedEventArgs e)
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

