using System.Windows;

namespace Pastee.App.Views
{
    public partial class EditTextWindow : Window
    {
        public string EditedText { get; private set; }

        public EditTextWindow(string initialText, string label = "Content:", int maxLength = 0, bool multiLine = true)
        {
            InitializeComponent();
            EditedText = initialText;
            TextInputBox.Text = initialText;
            LabelText.Text = label;
            
            if (maxLength > 0)
            {
                TextInputBox.MaxLength = maxLength;
            }

            if (!multiLine)
            {
                TextInputBox.AcceptsReturn = false;
                TextInputBox.TextWrapping = TextWrapping.NoWrap;
            }
            else
            {
                TextInputBox.Height = 200; // 为编辑内容提供更多空间
            }

            Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            TextInputBox.Focus();
            TextInputBox.CaretIndex = TextInputBox.Text.Length;
        }

        private void OnSave(object sender, RoutedEventArgs e)
        {
            EditedText = TextInputBox.Text;
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

