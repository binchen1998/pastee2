using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Pastee.App.ViewModels;
using Pastee.App.Models;
using Pastee.App.Infrastructure;
using Pastee.App.Services;

namespace Pastee.App.Views
{
    public partial class ClipboardPopup : Window
    {
        private readonly MainViewModel _viewModel;
        private IntPtr _previousActiveWindow;
        private Point _dragStartPoint;
        private ClipboardEntry? _draggedItem;
        private bool _isDragging;
        private bool _isShowing;

        public ClipboardPopup(MainViewModel viewModel)
        {
            InitializeComponent();
            _viewModel = viewModel;
            DataContext = _viewModel;
            Loaded += OnLoaded;
            
            // Preview mouse events to handle click vs drag
            this.PreviewMouseDown += OnPreviewMouseDown;
            this.PreviewMouseMove += OnPreviewMouseMove;
            this.PreviewMouseUp += OnPreviewMouseUp;

            // Persist window size
            this.SizeChanged += OnSizeChanged;
            LoadSavedSettings();
            
            // 监听分类变化以显示/隐藏清空按钮
            _viewModel.PropertyChanged += OnViewModelPropertyChanged;
            
            // 监听滚动到顶部请求
            _viewModel.ScrollToTopRequested += OnScrollToTopRequested;
        }

        private void OnScrollToTopRequested(object? sender, EventArgs e)
        {
            Dispatcher.BeginInvoke(new Action(() =>
            {
                ItemsScrollViewer.ScrollToTop();
            }));
        }

        private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(_viewModel.SelectedCategory) || e.PropertyName == nameof(_viewModel.DraftCount))
            {
                UpdateClearDraftsButtonVisibility();
            }
        }

        private void UpdateClearDraftsButtonVisibility()
        {
            ClearDraftsButton.Visibility = (_viewModel.SelectedCategory == "drafts" && _viewModel.DraftCount > 0) 
                ? Visibility.Visible 
                : Visibility.Collapsed;
        }

        private void OnClearDraftsClick(object sender, RoutedEventArgs e)
        {
            var dialog = new ConfirmWindow("Are you sure you want to clear all drafts? This action cannot be undone.")
            {
                Owner = this
            };

            if (dialog.ShowDialog() == true)
            {
                _viewModel.ClearAllDraftsCommand.Execute(null);
            }
        }

        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            // 打开独立的搜索窗口
            var authService = new AuthService();
            var token = await authService.GetSavedTokenAsync();
            
            var apiService = new ApiService();
            if (!string.IsNullOrEmpty(token))
            {
                apiService.SetToken(token);
            }
            
            var searchWindow = new SearchWindow(_viewModel, apiService);
            searchWindow.Owner = this;
            searchWindow.WindowStartupLocation = WindowStartupLocation.CenterOwner;
            searchWindow.Show();
        }

        private async void LoadSavedSettings()
        {
            var dataStore = new LocalDataStore();
            var settings = await dataStore.LoadWindowSettingsAsync();
            if (settings != null)
            {
                this.Width = settings.Width;
                this.Height = settings.Height;
                _viewModel.CurrentHotkey = settings.Hotkey;
            }
        }

        private void OnSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (this.Visibility == Visibility.Visible)
            {
                var dataStore = new LocalDataStore();
                _ = dataStore.SaveWindowSettingsAsync(this.Width, this.Height, _viewModel.CurrentHotkey);
            }
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            int exStyle = NativeMethods.GetWindowLong(hwnd, NativeMethods.GWL_EXSTYLE);
            // 重新引入 WS_EX_NOACTIVATE，确保显示时不抢占焦点
            NativeMethods.SetWindowLong(hwnd, NativeMethods.GWL_EXSTYLE, 
                exStyle | NativeMethods.WS_EX_NOACTIVATE | NativeMethods.WS_EX_TOOLWINDOW);
        }

        public void ShowPopup()
        {
            if (_isShowing) return;
            
            try
            {
                _isShowing = true;
                _previousActiveWindow = NativeMethods.GetForegroundWindow();

                PositionNearCursor();

                var hwnd = new WindowInteropHelper(this).EnsureHandle();
                // 使用 SW_SHOWNOACTIVATE 显示，完全不干扰原窗口
                NativeMethods.ShowWindow(hwnd, NativeMethods.SW_SHOWNOACTIVATE);
                this.Visibility = Visibility.Visible;
                this.Topmost = true;

                // Briefly prevent immediate re-triggering
                Dispatcher.BeginInvoke(new Action(() => { _isShowing = false; }), 
                    System.Windows.Threading.DispatcherPriority.Background);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ShowPopup error: {ex.Message}");
                _isShowing = false;
            }
        }

        private void PositionNearCursor()
        {
            try
            {
                NativeMethods.GetCursorPos(out var cursorPos);
                var screenWidth = SystemParameters.PrimaryScreenWidth;
                var screenHeight = SystemParameters.PrimaryScreenHeight;

                double x = cursorPos.X;
                double y = cursorPos.Y;

                var source = PresentationSource.FromVisual(this);
                if (source?.CompositionTarget != null)
                {
                    var dpiX = source.CompositionTarget.TransformFromDevice.M11;
                    var dpiY = source.CompositionTarget.TransformFromDevice.M22;
                    x *= dpiX;
                    y *= dpiY;
                }

                if (x + Width > screenWidth) x = screenWidth - Width - 20;
                if (y + Height > screenHeight) y = screenHeight - Height - 50;
                if (x < 0) x = 20;
                if (y < 0) y = 20;

                Left = x;
                Top = y;
            }
            catch
            {
                WindowStartupLocation = WindowStartupLocation.CenterScreen;
            }
        }

        private void OnPreviewMouseDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            _dragStartPoint = e.GetPosition(this);
            _draggedItem = null;

            var element = e.OriginalSource as FrameworkElement;
            bool clickedOnButton = false;

            // 向上追溯，检查是否点击了按钮或其子元素
            var temp = element;
            while (temp != null)
            {
                if (temp is System.Windows.Controls.Button)
                {
                    clickedOnButton = true;
                    break;
                }
                if (temp.Name == "ItemBorder") break; // 到达卡片边界，停止向上找按钮
                temp = VisualTreeHelper.GetParent(temp) as FrameworkElement;
            }

            if (clickedOnButton) return;

            // 重新寻找 DataContext
            element = e.OriginalSource as FrameworkElement;
            while (element != null)
            {
                if (element.DataContext is ClipboardEntry item)
                {
                    _draggedItem = item;
                    return;
                }
                element = VisualTreeHelper.GetParent(element) as FrameworkElement;
            }
        }

        private void OnPreviewMouseMove(object sender, System.Windows.Input.MouseEventArgs e)
        {
            if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed && _draggedItem != null && !_isDragging)
            {
                Point currentPos = e.GetPosition(this);
                Vector diff = _dragStartPoint - currentPos;

                if (Math.Abs(diff.X) > SystemParameters.MinimumHorizontalDragDistance ||
                    Math.Abs(diff.Y) > SystemParameters.MinimumVerticalDragDistance)
                {
                    _isDragging = true;
                    DragDrop.DoDragDrop(this, _draggedItem, DragDropEffects.Move);
                    _isDragging = false;
                    _draggedItem = null;
                }
            }
        }

        private void OnPreviewMouseUp(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (_draggedItem != null && !_isDragging)
            {
                SelectItem(_draggedItem);
            }
            _draggedItem = null;
            _isDragging = false;
        }

        private void SelectItem(ClipboardEntry item)
        {
            if (_viewModel.HideAfterPaste)
            {
                this.Hide();
            }
            Dispatcher.BeginInvoke(new Action(() =>
            {
                SetClipboardAndPaste(item);
            }), System.Windows.Threading.DispatcherPriority.Background);
        }

        private void SetClipboardAndPaste(ClipboardEntry item)
        {
            try
            {
                // Set clipboard based on content type
                if (item.ContentType == "text" || item.ContentType == "url")
                {
                    if (!string.IsNullOrEmpty(item.Content))
                        Clipboard.SetText(item.Content);
                }
                else if (item.ContentType == "image")
                {
                    var converter = new ImagePathConverter();
                    var bitmap = converter.Convert(item.DisplayImageData, typeof(BitmapSource), null, System.Globalization.CultureInfo.CurrentCulture) as BitmapSource;
                    if (bitmap != null)
                        Clipboard.SetImage(bitmap);
                }

                // Simulate Ctrl+V to paste
                Task.Delay(100).ContinueWith(_ =>
                {
                    Application.Current.Dispatcher.Invoke(() =>
                    {
                        SimulateCtrlV();
                    });
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Paste error: {ex.Message}");
            }
        }

        private void SimulateCtrlV()
        {
            var inputs = new NativeMethods.INPUT[4];
            
            // Ctrl down
            inputs[0].type = NativeMethods.INPUT_KEYBOARD;
            inputs[0].u.ki.wVk = (ushort)NativeMethods.VK_CONTROL;
            
            // V down
            inputs[1].type = NativeMethods.INPUT_KEYBOARD;
            inputs[1].u.ki.wVk = (ushort)NativeMethods.VK_V;
            
            // V up
            inputs[2].type = NativeMethods.INPUT_KEYBOARD;
            inputs[2].u.ki.wVk = (ushort)NativeMethods.VK_V;
            inputs[2].u.ki.dwFlags = NativeMethods.KEYEVENTF_KEYUP;
            
            // Ctrl up
            inputs[3].type = NativeMethods.INPUT_KEYBOARD;
            inputs[3].u.ki.wVk = (ushort)NativeMethods.VK_CONTROL;
            inputs[3].u.ki.dwFlags = NativeMethods.KEYEVENTF_KEYUP;

            NativeMethods.SendInput(4, inputs, Marshal.SizeOf(typeof(NativeMethods.INPUT)));
        }

        public async void ShowToast()
        {
            ToastBorder.Visibility = Visibility.Visible;
            await Task.Delay(1000);
            ToastBorder.Visibility = Visibility.Collapsed;
        }

        private void OnSettingsButtonClick(object sender, RoutedEventArgs e)
        {
            var settingsWindow = new SettingsWindow(_viewModel)
            {
                Owner = this,
                Title = "Settings",
                WindowStartupLocation = WindowStartupLocation.CenterOwner
            };

            if (settingsWindow.ShowDialog() == true && settingsWindow.RequestedLogout)
            {
                RequestLogout?.Invoke(this, EventArgs.Empty);
            }
        }

        public event EventHandler? RequestLogout;

        private void ItemCard_PreviewMouseLeftButtonDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            _dragStartPoint = e.GetPosition(null);
        }

        private void ItemCard_MouseMove(object sender, System.Windows.Input.MouseEventArgs e)
        {
            if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed)
            {
                Point mousePos = e.GetPosition(null);
                Vector diff = _dragStartPoint - mousePos;

                if (Math.Abs(diff.X) > SystemParameters.MinimumHorizontalDragDistance ||
                    Math.Abs(diff.Y) > SystemParameters.MinimumVerticalDragDistance)
                {
                    var frameworkElement = sender as FrameworkElement;
                    var item = frameworkElement?.DataContext as ClipboardEntry;
                    if (item != null)
                    {
                        DragDrop.DoDragDrop(frameworkElement!, item, DragDropEffects.Move);
                    }
                }
            }
        }

        private void ItemCard_MouseEnter(object sender, System.Windows.Input.MouseEventArgs e)
        {
            // 刷新时间显示，使相对时间重新计算
            if (sender is Border border)
            {
                var timeText = FindChild<TextBlock>(border, "TimeText");
                if (timeText != null)
                {
                    var binding = BindingOperations.GetBindingExpression(timeText, TextBlock.TextProperty);
                    binding?.UpdateTarget();
                }
            }
        }

        private T? FindChild<T>(DependencyObject parent, string childName) where T : DependencyObject
        {
            if (parent == null) return null;

            int childrenCount = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < childrenCount; i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                
                if (child is T typedChild && child is FrameworkElement fe && fe.Name == childName)
                {
                    return typedChild;
                }

                var result = FindChild<T>(child, childName);
                if (result != null) return result;
            }
            return null;
        }

        private void CategoryButton_DragOver(object sender, DragEventArgs e)
        {
            if (!e.Data.GetDataPresent(typeof(ClipboardEntry)))
            {
                e.Effects = DragDropEffects.None;
            }
            else
            {
                e.Effects = DragDropEffects.Move;
            }
            e.Handled = true;
        }

        private void CategoryButton_Drop(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(typeof(ClipboardEntry)))
            {
                var item = e.Data.GetData(typeof(ClipboardEntry)) as ClipboardEntry;
                var button = sender as System.Windows.Controls.Button;
                var category = button?.DataContext as Category;

                if (item != null && category != null)
                {
                    _viewModel.AddToCategoryCommand.Execute(new object[] { item, category });
                }
            }
        }

        private void OnHeaderMouseDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (e.LeftButton == System.Windows.Input.MouseButtonState.Pressed)
            {
                this.DragMove();
            }
        }

        private void OnCloseButtonClick(object sender, RoutedEventArgs e)
        {
            this.Hide();
        }

        private void OnScrollChanged(object sender, System.Windows.Controls.ScrollChangedEventArgs e)
        {
            if (e.VerticalChange == 0 && e.VerticalOffset == 0) return;
            if (sender is System.Windows.Controls.ScrollViewer scrollViewer)
            {
                if (scrollViewer.VerticalOffset + scrollViewer.ViewportHeight >= scrollViewer.ExtentHeight - 50)
                {
                    if (_viewModel.LoadMoreCommand.CanExecute(null))
                    {
                        _viewModel.LoadMoreCommand.Execute(null);
                    }
                }
            }
        }
    }
}
