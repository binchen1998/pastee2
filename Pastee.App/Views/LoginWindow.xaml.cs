using System.Windows;
using System.Windows.Controls;
using Pastee.App.ViewModels;

namespace Pastee.App.Views
{
    public partial class LoginWindow : Window
    {
        private readonly LoginViewModel _viewModel;

        public LoginWindow()
        {
            InitializeComponent();
            _viewModel = new LoginViewModel();
            DataContext = _viewModel;

            _viewModel.LoginSuccess += OnLoginSuccess;
            _viewModel.PropertyChanged += OnViewModelPropertyChanged;
        }

        private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            // 当视图切换时，同步密码框状态
            if (e.PropertyName == nameof(_viewModel.CurrentView))
            {
                // 根据当前视图更新密码占位符可见性
                UpdatePasswordPlaceholders();
            }
            
            // 当等待 OAuth 回调时，取消窗口置顶，让浏览器可以显示在前面
            if (e.PropertyName == nameof(_viewModel.IsWaitingForOAuth))
            {
                if (_viewModel.IsWaitingForOAuth)
                {
                    // 取消置顶，让浏览器显示在前面
                    this.Topmost = false;
                    // 最小化窗口
                    this.WindowState = WindowState.Minimized;
                }
                else
                {
                    // OAuth 完成后恢复窗口
                    this.WindowState = WindowState.Normal;
                    this.Topmost = true;
                    this.Activate();
                }
            }
        }

        private void UpdatePasswordPlaceholders()
        {
            // 重置登录密码框占位符
            if (LoginPasswordInput != null && LoginPasswordPlaceholder != null)
            {
                LoginPasswordPlaceholder.Visibility = string.IsNullOrEmpty(LoginPasswordInput.Password) 
                    ? Visibility.Visible 
                    : Visibility.Collapsed;
            }
            
            // 重置注册密码框占位符
            if (RegisterPasswordInput != null && RegisterPasswordPlaceholder != null)
            {
                RegisterPasswordPlaceholder.Visibility = string.IsNullOrEmpty(RegisterPasswordInput.Password) 
                    ? Visibility.Visible 
                    : Visibility.Collapsed;
            }
        }

        private async void OnLoginSuccess(object? sender, System.EventArgs e)
        {
            try
            {
                // 尝试作为对话框返回
                DialogResult = true;
            }
            catch (System.InvalidOperationException)
            {
                // 如果不是作为对话框打开的（例如 Logout 之后），则手动打开主窗口
                var authService = new Pastee.App.Services.AuthService();
                var token = await authService.GetSavedTokenAsync();
                var mainWindow = new MainWindow(token ?? string.Empty);
                mainWindow.Show();
            }
            Close();
        }

        private void PasswordInput_PasswordChanged(object sender, RoutedEventArgs e)
        {
            if (sender is PasswordBox passwordBox)
            {
                _viewModel.Password = passwordBox.Password;
                
                // 根据发送者更新对应的占位符
                if (passwordBox == LoginPasswordInput && LoginPasswordPlaceholder != null)
                {
                    LoginPasswordPlaceholder.Visibility = string.IsNullOrEmpty(passwordBox.Password) 
                        ? Visibility.Visible 
                        : Visibility.Collapsed;
                }
                else if (passwordBox == RegisterPasswordInput && RegisterPasswordPlaceholder != null)
                {
                    RegisterPasswordPlaceholder.Visibility = string.IsNullOrEmpty(passwordBox.Password) 
                        ? Visibility.Visible 
                        : Visibility.Collapsed;
                }
            }
        }

        private void OnClose(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}

