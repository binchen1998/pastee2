using System.Windows;

namespace Pastee.App.Views
{
    public partial class ConfirmWindow : Window
    {
        public ConfirmWindow(string message, string confirmText = "Delete")
        {
            InitializeComponent();
            MessageText.Text = message;
            // The Confirm button is named by its content in XAML, but we can change it if needed
            // However, based on the user's request, keeping it simple is better
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

