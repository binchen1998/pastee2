using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using Pastee.App.Infrastructure;
using Pastee.App.Services;

namespace Pastee.App.ViewModels
{
    /// <summary>
    /// 当前视图状态
    /// </summary>
    public enum AuthViewState
    {
        Login,
        Register,
        VerifyEmail
    }

    public class LoginViewModel : INotifyPropertyChanged
    {
        private readonly AuthService _authService = new AuthService();
        private string _email = string.Empty;
        private string _password = string.Empty;
        private string _verificationCode = string.Empty;
        private bool _isBusy;
        private bool _isWaitingForOAuth;
        private string _errorMessage = string.Empty;
        private string _successMessage = string.Empty;
        private AuthViewState _currentView = AuthViewState.Login;

        public event PropertyChangedEventHandler? PropertyChanged;
        public event EventHandler? LoginSuccess;

        #region Properties

        public string Email
        {
            get => _email;
            set 
            { 
                _email = value; 
                OnPropertyChanged(); 
                RaiseAllCommandsCanExecuteChanged();
            }
        }

        public string Password
        {
            get => _password;
            set 
            { 
                _password = value; 
                OnPropertyChanged(); 
                RaiseAllCommandsCanExecuteChanged();
            }
        }

        public string VerificationCode
        {
            get => _verificationCode;
            set 
            { 
                _verificationCode = value; 
                OnPropertyChanged(); 
                VerifyEmailCommand.RaiseCanExecuteChanged();
            }
        }

        public bool IsBusy
        {
            get => _isBusy;
            set 
            { 
                _isBusy = value; 
                OnPropertyChanged(); 
                RaiseAllCommandsCanExecuteChanged();
            }
        }

        public bool IsWaitingForOAuth
        {
            get => _isWaitingForOAuth;
            set 
            { 
                _isWaitingForOAuth = value; 
                OnPropertyChanged(); 
            }
        }

        public string ErrorMessage
        {
            get => _errorMessage;
            set { _errorMessage = value; OnPropertyChanged(); }
        }

        public string SuccessMessage
        {
            get => _successMessage;
            set { _successMessage = value; OnPropertyChanged(); }
        }

        public AuthViewState CurrentView
        {
            get => _currentView;
            set 
            { 
                _currentView = value; 
                OnPropertyChanged(); 
                OnPropertyChanged(nameof(IsLoginView));
                OnPropertyChanged(nameof(IsRegisterView));
                OnPropertyChanged(nameof(IsVerifyEmailView));
            }
        }

        public bool IsLoginView => CurrentView == AuthViewState.Login;
        public bool IsRegisterView => CurrentView == AuthViewState.Register;
        public bool IsVerifyEmailView => CurrentView == AuthViewState.VerifyEmail;

        #endregion

        #region Commands

        public RelayCommand LoginCommand { get; }
        public RelayCommand RegisterCommand { get; }
        public RelayCommand VerifyEmailCommand { get; }
        public RelayCommand ResendCodeCommand { get; }
        public RelayCommand SwitchToLoginCommand { get; }
        public RelayCommand SwitchToRegisterCommand { get; }
        public RelayCommand BackToLoginCommand { get; }
        public RelayCommand GoogleLoginCommand { get; }

        #endregion

        public LoginViewModel()
        {
            LoginCommand = new RelayCommand(
                async _ => await LoginAsync(), 
                _ => CanLogin());
            
            RegisterCommand = new RelayCommand(
                async _ => await RegisterAsync(), 
                _ => CanRegister());
            
            VerifyEmailCommand = new RelayCommand(
                async _ => await VerifyEmailAsync(), 
                _ => !string.IsNullOrWhiteSpace(VerificationCode) && !IsBusy);
            
            ResendCodeCommand = new RelayCommand(
                async _ => await ResendCodeAsync(), 
                _ => !IsBusy);
            
            SwitchToLoginCommand = new RelayCommand(
                _ => SwitchToLogin(), 
                _ => !IsBusy);
            
            SwitchToRegisterCommand = new RelayCommand(
                _ => SwitchToRegister(), 
                _ => !IsBusy);
            
            BackToLoginCommand = new RelayCommand(
                _ => SwitchToLogin(), 
                _ => !IsBusy);

            GoogleLoginCommand = new RelayCommand(
                _ => StartGoogleLogin(), 
                _ => !IsBusy && !IsWaitingForOAuth);

            // 订阅 OAuth 回调事件
            App.OAuthTokenReceived += OnOAuthTokenReceived;
        }

        ~LoginViewModel()
        {
            // 取消订阅
            App.OAuthTokenReceived -= OnOAuthTokenReceived;
        }

        #region Validation

        private bool IsValidEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email)) return false;
            return Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");
        }

        private bool CanLogin()
        {
            return !string.IsNullOrWhiteSpace(Email) 
                && !string.IsNullOrWhiteSpace(Password) 
                && !IsBusy;
        }

        private bool CanRegister()
        {
            return !string.IsNullOrWhiteSpace(Email) 
                && !string.IsNullOrWhiteSpace(Password) 
                && Password.Length >= 6
                && !IsBusy;
        }

        private string? ValidateInput(bool isRegister = false)
        {
            if (string.IsNullOrWhiteSpace(Email))
                return "Please enter your email address.";
            
            if (!IsValidEmail(Email))
                return "Please enter a valid email address.";
            
            if (string.IsNullOrWhiteSpace(Password))
                return "Please enter your password.";
            
            if (isRegister && Password.Length < 6)
                return "Password must be at least 6 characters.";
            
            return null;
        }

        #endregion

        #region Actions

        private async Task LoginAsync()
        {
            var validationError = ValidateInput(isRegister: false);
            if (validationError != null)
            {
                ErrorMessage = validationError;
                return;
            }

            IsBusy = true;
            ErrorMessage = string.Empty;
            SuccessMessage = string.Empty;

            try
            {
                var result = await _authService.LoginAsync(Email, Password);
                if (result.Success)
                {
                    LoginSuccess?.Invoke(this, EventArgs.Empty);
                }
                else
                {
                    ErrorMessage = result.ErrorMessage ?? "Login failed. Please try again.";
                }
            }
            finally
            {
                IsBusy = false;
            }
        }

        private async Task RegisterAsync()
        {
            var validationError = ValidateInput(isRegister: true);
            if (validationError != null)
            {
                ErrorMessage = validationError;
                return;
            }

            IsBusy = true;
            ErrorMessage = string.Empty;
            SuccessMessage = string.Empty;

            try
            {
                var result = await _authService.RegisterAsync(Email, Password);
                if (result.Success)
                {
                    // 注册成功，切换到验证码输入界面
                    SuccessMessage = "Verification code sent! Please check your email.";
                    CurrentView = AuthViewState.VerifyEmail;
                }
                else
                {
                    ErrorMessage = result.ErrorMessage ?? "Registration failed. Please try again.";
                }
            }
            finally
            {
                IsBusy = false;
            }
        }

        private async Task VerifyEmailAsync()
        {
            if (string.IsNullOrWhiteSpace(VerificationCode))
            {
                ErrorMessage = "Please enter the verification code.";
                return;
            }

            IsBusy = true;
            ErrorMessage = string.Empty;
            SuccessMessage = string.Empty;

            try
            {
                var result = await _authService.VerifyEmailAsync(Email, VerificationCode);
                if (result.Success)
                {
                    SuccessMessage = "Email verified successfully! Please login.";
                    // 清空验证码
                    VerificationCode = string.Empty;
                    // 切换回登录界面
                    CurrentView = AuthViewState.Login;
                }
                else
                {
                    ErrorMessage = result.ErrorMessage ?? "Verification failed. Please try again.";
                }
            }
            finally
            {
                IsBusy = false;
            }
        }

        private async Task ResendCodeAsync()
        {
            if (string.IsNullOrWhiteSpace(Email))
            {
                ErrorMessage = "Email address is required.";
                return;
            }

            IsBusy = true;
            ErrorMessage = string.Empty;
            SuccessMessage = string.Empty;

            try
            {
                var result = await _authService.ResendVerificationAsync(Email);
                if (result.Success)
                {
                    SuccessMessage = "Verification code resent! Please check your email.";
                }
                else
                {
                    ErrorMessage = result.ErrorMessage ?? "Failed to resend code. Please try again.";
                }
            }
            finally
            {
                IsBusy = false;
            }
        }

        private void SwitchToLogin()
        {
            CurrentView = AuthViewState.Login;
            ErrorMessage = string.Empty;
            // 保留 SuccessMessage 以显示验证成功提示
        }

        private void SwitchToRegister()
        {
            CurrentView = AuthViewState.Register;
            ErrorMessage = string.Empty;
            SuccessMessage = string.Empty;
        }

        private void RaiseAllCommandsCanExecuteChanged()
        {
            LoginCommand.RaiseCanExecuteChanged();
            RegisterCommand.RaiseCanExecuteChanged();
            VerifyEmailCommand.RaiseCanExecuteChanged();
            ResendCodeCommand.RaiseCanExecuteChanged();
            SwitchToLoginCommand.RaiseCanExecuteChanged();
            SwitchToRegisterCommand.RaiseCanExecuteChanged();
            BackToLoginCommand.RaiseCanExecuteChanged();
            GoogleLoginCommand.RaiseCanExecuteChanged();
        }

        private void StartGoogleLogin()
        {
            ErrorMessage = string.Empty;
            SuccessMessage = string.Empty;
            IsWaitingForOAuth = true;
            SuccessMessage = "Opening browser for Google login...";

            // 获取 Google OAuth URL 并在浏览器中打开
            var authUrl = _authService.GetGoogleAuthUrl();
            OAuthHelper.OpenInBrowser(authUrl);

            System.Diagnostics.Debug.WriteLine($"[LoginViewModel] Opened Google OAuth URL: {authUrl}");
        }

        private async void OnOAuthTokenReceived(string token)
        {
            System.Diagnostics.Debug.WriteLine("[LoginViewModel] OAuth token received, completing login...");

            IsWaitingForOAuth = false;
            IsBusy = true;
            ErrorMessage = string.Empty;
            SuccessMessage = "Completing login...";

            try
            {
                var result = await _authService.CompleteOAuthLoginAsync(token);
                if (result.Success)
                {
                    SuccessMessage = string.Empty;
                    LoginSuccess?.Invoke(this, EventArgs.Empty);
                }
                else
                {
                    SuccessMessage = string.Empty;
                    ErrorMessage = result.ErrorMessage ?? "Google login failed. Please try again.";
                }
            }
            finally
            {
                IsBusy = false;
            }
        }

        /// <summary>
        /// 取消等待 OAuth 回调
        /// </summary>
        public void CancelOAuthWait()
        {
            if (IsWaitingForOAuth)
            {
                IsWaitingForOAuth = false;
                SuccessMessage = string.Empty;
                GoogleLoginCommand.RaiseCanExecuteChanged();
            }
        }

        #endregion

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

