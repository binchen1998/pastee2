using System;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using Pastee.App.Services;

namespace Pastee.App.Views
{
    public partial class UpdateWindow : Window
    {
        private readonly UpdateService _updateService = new UpdateService();
        private readonly VersionCheckResponse _updateInfo;
        private CancellationTokenSource? _downloadCts;
        private bool _isDownloading;

        public UpdateWindow(VersionCheckResponse updateInfo)
        {
            InitializeComponent();
            _updateInfo = updateInfo;
            InitializeUI();
        }

        private void InitializeUI()
        {
            // 版本信息
            CurrentVersionText.Text = UpdateService.GetCurrentVersion();
            LatestVersionText.Text = _updateInfo.LatestVersion ?? "Unknown";

            // 强制更新
            if (_updateInfo.IsMandatory)
            {
                MandatoryWarning.Visibility = Visibility.Visible;
                CloseButton.Visibility = Visibility.Collapsed;
                LaterButton.Visibility = Visibility.Collapsed;
            }

            // 更新说明
            if (!string.IsNullOrWhiteSpace(_updateInfo.ReleaseNotes))
            {
                ReleaseNotesContainer.Visibility = Visibility.Visible;
                ReleaseNotesText.Text = _updateInfo.ReleaseNotes;
            }
        }

        private async void OnUpdateClick(object sender, RoutedEventArgs e)
        {
            if (_isDownloading) return;
            if (string.IsNullOrEmpty(_updateInfo.DownloadUrl))
            {
                ShowError("Download URL is not available.");
                return;
            }

            _isDownloading = true;
            _downloadCts = new CancellationTokenSource();

            // 显示下载进度
            DownloadProgressPanel.Visibility = Visibility.Visible;
            ButtonPanel.Visibility = Visibility.Collapsed;
            ErrorContainer.Visibility = Visibility.Collapsed;
            CloseButton.IsEnabled = false;

            var progress = new Progress<double>(percent =>
            {
                DownloadProgress.Value = percent;
                DownloadPercentText.Text = $"{percent:F0}%";
            });

            try
            {
                DownloadStatusText.Text = "Downloading update...";
                var installerPath = await _updateService.DownloadUpdateAsync(
                    _updateInfo.DownloadUrl, 
                    progress, 
                    _downloadCts.Token);

                if (!string.IsNullOrEmpty(installerPath))
                {
                    DownloadStatusText.Text = "Installing...";
                    await Task.Delay(500); // 短暂延迟让用户看到状态
                    _updateService.InstallUpdate(installerPath);
                }
            }
            catch (OperationCanceledException)
            {
                // 用户取消
                ResetDownloadState();
            }
            catch (Exception ex)
            {
                ShowError($"Download failed: {ex.Message}");
                
                // 2秒后尝试打开浏览器下载
                await Task.Delay(2000);
                _updateService.OpenDownloadInBrowser(_updateInfo.DownloadUrl);
                
                ResetDownloadState();
                
                // 即使是强制更新，失败时也允许关闭
                if (_updateInfo.IsMandatory)
                {
                    CloseButton.Visibility = Visibility.Visible;
                    LaterButton.Visibility = Visibility.Visible;
                }
            }
            finally
            {
                _downloadCts?.Dispose();
                _downloadCts = null;
                _isDownloading = false;
            }
        }

        private void ShowError(string message)
        {
            ErrorContainer.Visibility = Visibility.Visible;
            ErrorText.Text = message;
        }

        private void ResetDownloadState()
        {
            DownloadProgressPanel.Visibility = Visibility.Collapsed;
            ButtonPanel.Visibility = Visibility.Visible;
            CloseButton.IsEnabled = true;
            DownloadProgress.Value = 0;
            DownloadPercentText.Text = "0%";
        }

        private void OnLaterClick(object sender, RoutedEventArgs e)
        {
            if (!_updateInfo.IsMandatory)
            {
                _downloadCts?.Cancel();
                Close();
            }
        }

        private void OnClose(object sender, RoutedEventArgs e)
        {
            if (!_updateInfo.IsMandatory || !_isDownloading)
            {
                _downloadCts?.Cancel();
                Close();
            }
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            // 强制更新且正在下载时不允许关闭
            if (_updateInfo.IsMandatory && _isDownloading)
            {
                e.Cancel = true;
                return;
            }
            
            _downloadCts?.Cancel();
            base.OnClosing(e);
        }
    }
}


