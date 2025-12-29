using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using Pastee.App.Infrastructure;
using Pastee.App.Models;
using Pastee.App.Services;
using Pastee.App.ViewModels;

namespace Pastee.App.Views
{
    public partial class SearchWindow : Window
    {
        private readonly MainViewModel _viewModel;
        private readonly ApiService _apiService;
        private CancellationTokenSource? _searchCts;
        private readonly List<ClipboardEntry> _results = new List<ClipboardEntry>();
        private int _currentPage = 1;
        private bool _hasMore = true;
        private bool _isLoading;
        private string _lastSearchText = string.Empty;

        public SearchWindow(MainViewModel viewModel, ApiService apiService)
        {
            InitializeComponent();
            _viewModel = viewModel;
            _apiService = apiService;

            this.Loaded += OnLoaded;
            this.KeyDown += OnKeyDown;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            // 自动聚焦到搜索框
            SearchInput.Focus();
        }

        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Escape)
            {
                this.Close();
            }
        }

        private void OnCloseButtonClick(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void SearchInput_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            var text = SearchInput.Text;

            // 更新 placeholder 可见性
            PlaceholderText.Visibility = string.IsNullOrEmpty(text) ? Visibility.Visible : Visibility.Collapsed;
            ClearButton.Visibility = string.IsNullOrEmpty(text) ? Visibility.Collapsed : Visibility.Visible;

            // 如果清空了输入，重置状态
            if (string.IsNullOrWhiteSpace(text))
            {
                _searchCts?.Cancel();
                _results.Clear();
                ResultsList.ItemsSource = null;
                InitialStateIndicator.Visibility = Visibility.Visible;
                NoResultsIndicator.Visibility = Visibility.Collapsed;
                LoadingIndicator.Visibility = Visibility.Collapsed;
            }
        }

        private void SearchInput_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
            {
                var text = SearchInput.Text;
                if (!string.IsNullOrWhiteSpace(text))
                {
                    _searchCts?.Cancel();
                    _searchCts = new CancellationTokenSource();
                    InitialStateIndicator.Visibility = Visibility.Collapsed;
                    _ = PerformSearchAsync(text, 1);
                }
            }
        }

        private async Task PerformSearchAsync(string searchText, int page)
        {
            if (_isLoading && page > 1) return;

            _isLoading = true;
            
            // 立即更新 UI 状态
            await Dispatcher.InvokeAsync(() =>
            {
                LoadingIndicator.Visibility = Visibility.Visible;
                NoResultsIndicator.Visibility = Visibility.Collapsed;
            });

            var token = _searchCts?.Token ?? CancellationToken.None;

            try
            {
                if (page == 1)
                {
                    _results.Clear();
                    _lastSearchText = searchText;
                    
                    // 立即清空列表
                    await Dispatcher.InvokeAsync(() =>
                    {
                        ResultsList.ItemsSource = null;
                    });
                }

                // 完全在后台线程执行网络请求
                var url = $"/clipboard/items?page={page}&page_size=20&search={Uri.EscapeDataString(searchText)}";
                
                List<ClipboardEntry>? items = null;
                
                await Task.Run(async () =>
                {
                    items = await _apiService.GetAsync<List<ClipboardEntry>>(url, token).ConfigureAwait(false);
                    
                    if (items != null)
                    {
                        // 在后台线程初始化图片状态
                        foreach (var item in items)
                        {
                            if (token.IsCancellationRequested) return;
                            item.InitializeImageState();
                        }
                    }
                }, token).ConfigureAwait(false);

                // 检查是否被取消
                if (token.IsCancellationRequested) return;

                // 回到 UI 线程更新结果
                await Dispatcher.InvokeAsync(() =>
                {
                    if (items != null)
                    {
                        foreach (var item in items)
                        {
                            _results.Add(item);
                        }

                        _currentPage = page;
                        _hasMore = items.Count == 20;
                    }
                    else
                    {
                        _hasMore = false;
                    }

                    // 更新列表
                    ResultsList.ItemsSource = null;
                    ResultsList.ItemsSource = _results;

                    if (_results.Count == 0)
                    {
                        NoResultsIndicator.Visibility = Visibility.Visible;
                    }
                });
            }
            catch (OperationCanceledException)
            {
                // 搜索被取消，忽略
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[SearchWindow] 搜索失败: {ex.Message}");
            }
            finally
            {
                _isLoading = false;
                await Dispatcher.InvokeAsync(() =>
                {
                    LoadingIndicator.Visibility = Visibility.Collapsed;
                });
            }
        }

        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            SearchInput.Text = string.Empty;
            SearchInput.Focus();
        }

        private void ResultItem_Click(object sender, MouseButtonEventArgs e)
        {
            var border = sender as System.Windows.Controls.Border;
            var entry = border?.DataContext as ClipboardEntry;

            if (entry != null)
            {
                CopyToClipboard(entry);
                ShowToast();
            }
        }

        private void CopyToClipboard(ClipboardEntry entry)
        {
            try
            {
                if (entry.ContentType == "text" || entry.ContentType == "url")
                {
                    if (!string.IsNullOrEmpty(entry.Content))
                    {
                        Clipboard.SetText(entry.Content);
                    }
                }
                else if (entry.ContentType == "image")
                {
                    var converter = new ImagePathConverter();
                    var bitmap = converter.Convert(entry.DisplayImageData, typeof(BitmapSource), null, System.Globalization.CultureInfo.CurrentCulture) as BitmapSource;
                    if (bitmap != null)
                    {
                        Clipboard.SetImage(bitmap);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[SearchWindow] 复制失败: {ex.Message}");
            }
        }

        private async void ShowToast()
        {
            ToastBorder.Visibility = Visibility.Visible;
            await Task.Delay(800);
            ToastBorder.Visibility = Visibility.Collapsed;
        }

        private void OnScrollChanged(object sender, System.Windows.Controls.ScrollChangedEventArgs e)
        {
            if (e.VerticalChange == 0 && e.VerticalOffset == 0) return;

            if (sender is System.Windows.Controls.ScrollViewer scrollViewer)
            {
                if (scrollViewer.VerticalOffset + scrollViewer.ViewportHeight >= scrollViewer.ExtentHeight - 50)
                {
                    if (!_isLoading && _hasMore && !string.IsNullOrWhiteSpace(_lastSearchText))
                    {
                        _ = PerformSearchAsync(_lastSearchText, _currentPage + 1);
                    }
                }
            }
        }
    }
}

