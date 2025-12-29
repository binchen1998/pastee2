using System;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using Pastee.App.Infrastructure;
using Pastee.App.Models;

namespace Pastee.App.Views
{
    public partial class ImageViewWindow : Window
    {
        private readonly ClipboardEntry _entry;
        private BitmapSource? _bitmap;

        public ImageViewWindow(ClipboardEntry entry)
        {
            InitializeComponent();
            _entry = entry;
            
            this.KeyDown += OnKeyDown;
            this.Loaded += OnLoaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            LoadImage();
        }

        private void LoadImage()
        {
            try
            {
                var converter = new ImagePathConverter();
                _bitmap = converter.Convert(_entry.DisplayImageData, typeof(BitmapSource), null, System.Globalization.CultureInfo.CurrentCulture) as BitmapSource;
                
                if (_bitmap != null)
                {
                    ImageViewer.Source = _bitmap;
                    TitleText.Text = $"Image Viewer";
                    ImageInfoText.Text = $"{_bitmap.PixelWidth} × {_bitmap.PixelHeight}";
                }
                else
                {
                    TitleText.Text = "Image Viewer - Failed to load";
                    ImageInfoText.Text = "";
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ImageViewWindow] 加载图片失败: {ex.Message}");
                TitleText.Text = "Image Viewer - Error";
                ImageInfoText.Text = "";
            }
        }

        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Escape)
            {
                this.Close();
            }
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void MaximizeButton_Click(object sender, RoutedEventArgs e)
        {
            if (this.WindowState == WindowState.Maximized)
            {
                this.WindowState = WindowState.Normal;
                MaximizeButton.Content = "🗖";
                MaximizeButton.ToolTip = "Maximize";
            }
            else
            {
                this.WindowState = WindowState.Maximized;
                MaximizeButton.Content = "🗗";
                MaximizeButton.ToolTip = "Restore";
            }
        }

        private void CopyButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_bitmap != null)
                {
                    Clipboard.SetImage(_bitmap);
                    // 简单的视觉反馈
                    TitleText.Text = "Copied!";
                    var timer = new System.Windows.Threading.DispatcherTimer
                    {
                        Interval = TimeSpan.FromSeconds(1)
                    };
                    timer.Tick += (s, args) =>
                    {
                        TitleText.Text = "Image Viewer";
                        timer.Stop();
                    };
                    timer.Start();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ImageViewWindow] 复制失败: {ex.Message}");
            }
        }
    }
}

