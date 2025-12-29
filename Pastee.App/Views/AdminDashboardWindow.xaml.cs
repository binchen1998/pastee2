using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Pastee.App.Services;

namespace Pastee.App.Views
{
    public partial class AdminDashboardWindow : Window
    {
        private readonly AdminService _adminService = new AdminService();
        private string _currentTab = "Dashboard";
        private int _currentUserPage = 1;
        private const int PageSize = 20;
        private string _userSearchText = "";

        public AdminDashboardWindow()
        {
            InitializeComponent();
            UpdateTabStyles();
            LoadDashboardData();
        }

        #region Window Controls

        private void OnHeaderMouseDown(object sender, MouseButtonEventArgs e)
        {
            if (e.LeftButton == MouseButtonState.Pressed)
            {
                DragMove();
            }
        }

        private void OnClose(object sender, RoutedEventArgs e)
        {
            Close();
        }

        #endregion

        #region Tab Navigation

        private void OnTabClick(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string tab)
            {
                _currentTab = tab;
                UpdateTabStyles();
                ShowCurrentTab();
            }
        }

        private void UpdateTabStyles()
        {
            // Reset all tabs
            TabDashboard.Background = System.Windows.Media.Brushes.Transparent;
            TabUsers.Background = System.Windows.Media.Brushes.Transparent;
            TabVersions.Background = System.Windows.Media.Brushes.Transparent;

            // Highlight current tab
            var accentBrush = FindResource("AccentBrush") as System.Windows.Media.Brush;
            switch (_currentTab)
            {
                case "Dashboard":
                    TabDashboard.Background = accentBrush;
                    break;
                case "Users":
                    TabUsers.Background = accentBrush;
                    break;
                case "Versions":
                    TabVersions.Background = accentBrush;
                    break;
            }
        }

        private void ShowCurrentTab()
        {
            DashboardContent.Visibility = Visibility.Collapsed;
            UsersContent.Visibility = Visibility.Collapsed;
            VersionsContent.Visibility = Visibility.Collapsed;
            ErrorPanel.Visibility = Visibility.Collapsed;

            switch (_currentTab)
            {
                case "Dashboard":
                    DashboardContent.Visibility = Visibility.Visible;
                    LoadDashboardData();
                    break;
                case "Users":
                    UsersContent.Visibility = Visibility.Visible;
                    LoadUsersData();
                    break;
                case "Versions":
                    VersionsContent.Visibility = Visibility.Visible;
                    LoadVersionsData();
                    break;
            }
        }

        #endregion

        #region Dashboard

        private async void LoadDashboardData()
        {
            try
            {
                LoadingPanel.Visibility = Visibility.Visible;
                
                var data = await _adminService.GetDashboardDataAsync();
                
                LoadingPanel.Visibility = Visibility.Collapsed;

                if (data == null)
                {
                    ShowError("Failed to load dashboard data. Please check your permissions.");
                    return;
                }

                // Update stats from summary
                var summary = data.Summary;
                var today = data.Today;
                var yesterday = data.Yesterday;
                var growthRates = data.GrowthRates;

                if (summary != null)
                {
                    TotalUsersText.Text = summary.TotalUsers.ToString("N0");
                    TodayNewText.Text = summary.TodayRegistrations.ToString();
                    TodayActiveText.Text = summary.TodayActive.ToString();
                    WeeklyAvgText.Text = summary.WeekAvgRegistrations.ToString("F1");
                }
                else if (today != null)
                {
                    TotalUsersText.Text = today.TotalUsers.ToString("N0");
                    TodayNewText.Text = today.NewRegistrations.ToString();
                    TodayActiveText.Text = today.ActiveUsers.ToString();
                }

                // Calculate changes (using growth rates or day comparison)
                if (growthRates != null)
                {
                    TodayNewChangeText.Text = FormatGrowthRate(growthRates.Registrations);
                    TodayNewChangeText.Foreground = growthRates.Registrations >= 0 
                        ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(76, 175, 80))
                        : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(244, 67, 54));

                    TodayActiveChangeText.Text = FormatGrowthRate(growthRates.ActiveUsers);
                    TodayActiveChangeText.Foreground = growthRates.ActiveUsers >= 0 
                        ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(76, 175, 80))
                        : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(244, 67, 54));
                }
                else if (today != null && yesterday != null)
                {
                    var newChange = today.NewRegistrations - yesterday.NewRegistrations;
                    var activeChange = today.ActiveUsers - yesterday.ActiveUsers;

                    TodayNewChangeText.Text = FormatChange(newChange);
                    TodayNewChangeText.Foreground = newChange >= 0 
                        ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(76, 175, 80))
                        : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(244, 67, 54));

                    TodayActiveChangeText.Text = FormatChange(activeChange);
                    TodayActiveChangeText.Foreground = activeChange >= 0 
                        ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(76, 175, 80))
                        : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(244, 67, 54));
                }

                // Update trend table
                if (data.RecentWeek != null)
                {
                    TrendDataGrid.ItemsSource = data.RecentWeek;
                }
            }
            catch (TaskCanceledException)
            {
                LoadingPanel.Visibility = Visibility.Collapsed;
                ShowError("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                LoadingPanel.Visibility = Visibility.Collapsed;
                ShowError($"Error loading dashboard: {ex.Message}");
            }
        }

        private string FormatGrowthRate(double rate)
        {
            if (rate > 0) return $"+{rate:F1}%";
            if (rate < 0) return $"{rate:F1}%";
            return "0%";
        }

        private string FormatChange(int change)
        {
            if (change > 0) return $"+{change} vs yesterday";
            if (change < 0) return $"{change} vs yesterday";
            return "same as yesterday";
        }

        #endregion

        #region Users Management

        private async void LoadUsersData()
        {
            try
            {
                var result = await _adminService.GetUsersAsync(_currentUserPage, PageSize, _userSearchText);
                
                if (result == null)
                {
                    ShowError("Failed to load users. Please check your permissions.");
                    return;
                }

                UsersDataGrid.ItemsSource = result.Users;
                
                var totalPages = (int)Math.Ceiling((double)result.Total / PageSize);
                PageInfoText.Text = $"Page {_currentUserPage} of {totalPages} ({result.Total} users)";
                
                PrevPageBtn.IsEnabled = _currentUserPage > 1;
                NextPageBtn.IsEnabled = _currentUserPage < totalPages;
            }
            catch (TaskCanceledException)
            {
                ShowError("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                ShowError($"Error loading users: {ex.Message}");
            }
        }

        private void OnUserSearchKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
            {
                OnUserSearchClick(sender, e);
            }
        }

        private void OnUserSearchClick(object sender, RoutedEventArgs e)
        {
            _userSearchText = UserSearchBox.Text;
            _currentUserPage = 1;
            LoadUsersData();
        }

        private void OnPrevPageClick(object sender, RoutedEventArgs e)
        {
            if (_currentUserPage > 1)
            {
                _currentUserPage--;
                LoadUsersData();
            }
        }

        private void OnNextPageClick(object sender, RoutedEventArgs e)
        {
            _currentUserPage++;
            LoadUsersData();
        }

        #endregion

        #region Versions Management

        private async void LoadVersionsData()
        {
            try
            {
                var versions = await _adminService.GetVersionsAsync();
                
                if (versions == null)
                {
                    ShowError("Failed to load versions. Please check your permissions.");
                    return;
                }

                VersionsDataGrid.ItemsSource = versions;
            }
            catch (TaskCanceledException)
            {
                ShowError("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                ShowError($"Error loading versions: {ex.Message}");
            }
        }

        private async void OnPublishVersionClick(object sender, RoutedEventArgs e)
        {
            var version = NewVersionText.Text.Trim();
            var downloadUrl = DownloadUrlText.Text.Trim();
            var releaseNotes = ReleaseNotesText.Text.Trim();
            var isMandatory = IsMandatoryCheck.IsChecked == true;

            if (string.IsNullOrEmpty(version) || string.IsNullOrEmpty(downloadUrl))
            {
                ShowError("Version and Download URL are required.");
                return;
            }

            try
            {
                var success = await _adminService.PublishVersionAsync(version, releaseNotes, downloadUrl, isMandatory);
                
                if (success)
                {
                    // Clear form
                    NewVersionText.Text = "";
                    DownloadUrlText.Text = "";
                    ReleaseNotesText.Text = "";
                    IsMandatoryCheck.IsChecked = false;
                    
                    // Reload list
                    LoadVersionsData();
                    
                    MessageBox.Show("Version published successfully!", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                else
                {
                    ShowError("Failed to publish version. Please try again.");
                }
            }
            catch (TaskCanceledException)
            {
                ShowError("Request timed out. Please check your network connection.");
            }
            catch (Exception ex)
            {
                ShowError($"Error publishing version: {ex.Message}");
            }
        }

        private async void OnDeleteVersionClick(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn && btn.Tag is VersionInfo versionInfo)
            {
                var result = MessageBox.Show(
                    $"Are you sure you want to delete version {versionInfo.Version}?",
                    "Confirm Delete",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Warning);

                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        var success = await _adminService.DeleteVersionAsync(versionInfo.Id);
                        
                        if (success)
                        {
                            LoadVersionsData();
                            MessageBox.Show("Version deleted successfully!", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                        }
                        else
                        {
                            ShowError("Failed to delete version. Please try again.");
                        }
                    }
                    catch (TaskCanceledException)
                    {
                        ShowError("Request timed out. Please check your network connection.");
                    }
                    catch (Exception ex)
                    {
                        ShowError($"Error deleting version: {ex.Message}");
                    }
                }
            }
        }

        #endregion

        #region Helpers

        private void ShowError(string message)
        {
            ErrorText.Text = message;
            ErrorPanel.Visibility = Visibility.Visible;
        }

        #endregion
    }
}

