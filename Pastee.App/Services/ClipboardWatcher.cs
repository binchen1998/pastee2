using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace Pastee.App.Services
{
    /// <summary>
    /// 封装 Windows 的剪贴板监听。
    /// </summary>
    public sealed class ClipboardWatcher : IDisposable
    {
        private const int WM_CLIPBOARDUPDATE = 0x031D;
        private IntPtr _windowHandle;
        private HwndSource? _hwndSource;
        private bool _isListening;

        public event EventHandler? ClipboardUpdated;

        public void Start(Window window)
        {
            if (_isListening) return;

            var helper = new WindowInteropHelper(window);
            _windowHandle = helper.EnsureHandle();
            _hwndSource = HwndSource.FromHwnd(_windowHandle);
            if (_hwndSource != null)
            {
                _hwndSource.AddHook(WndProc);
            }

            if (!NativeMethods.AddClipboardFormatListener(_windowHandle))
            {
                throw new InvalidOperationException("无法注册剪贴板监听。");
            }

            _isListening = true;
        }

        public void Stop()
        {
            if (!_isListening) return;
            NativeMethods.RemoveClipboardFormatListener(_windowHandle);
            if (_hwndSource != null)
            {
                _hwndSource.RemoveHook(WndProc);
                _hwndSource = null;
            }

            _isListening = false;
        }

        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_CLIPBOARDUPDATE)
            {
                var handler = ClipboardUpdated;
                if (handler != null)
                {
                    handler(this, EventArgs.Empty);
                }
            }

            return IntPtr.Zero;
        }

        public void Dispose()
        {
            Stop();
        }

        private static class NativeMethods
        {
            [DllImport("user32.dll", SetLastError = true)]
            internal static extern bool AddClipboardFormatListener(IntPtr hwnd);

            [DllImport("user32.dll", SetLastError = true)]
            internal static extern bool RemoveClipboardFormatListener(IntPtr hwnd);
        }
    }
}

