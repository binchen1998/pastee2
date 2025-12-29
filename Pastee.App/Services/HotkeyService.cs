using System;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;

namespace Pastee.App.Services
{
    public class HotkeyService : IDisposable
    {
        private const int HOTKEY_ID = 9000;
        private IntPtr _windowHandle;
        private bool _isRegistered;
        private HwndSource? _hwndSource;

        public event Action? HotkeyPressed;
        public string? RegisteredHotkey { get; private set; }

        public void Initialize(Window window)
        {
            _windowHandle = new WindowInteropHelper(window).EnsureHandle();
            _hwndSource = HwndSource.FromHwnd(_windowHandle);
            _hwndSource?.AddHook(HwndHook);
        }

        public bool RegisterHotkey(string hotkeyStr)
        {
            UnregisterHotkey();

            if (string.IsNullOrEmpty(hotkeyStr) || hotkeyStr.Equals("Win + V", StringComparison.OrdinalIgnoreCase))
            {
                return false; // Win + V is handled by LowLevelKeyboardHook
            }

            try
            {
                int modifiers = 0;
                int key = 0;

                string[] parts = hotkeyStr.Split(new[] { " + " }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var part in parts)
                {
                    if (part == "Ctrl") modifiers |= NativeMethods.MOD_CONTROL;
                    else if (part == "Shift") modifiers |= NativeMethods.MOD_SHIFT;
                    else if (part == "Alt") modifiers |= NativeMethods.MOD_ALT;
                    else
                    {
                        if (Enum.TryParse(typeof(System.Windows.Input.Key), part, out object? k))
                        {
                            key = KeyInterop.VirtualKeyFromKey((System.Windows.Input.Key)k);
                        }
                    }
                }

                if (key != 0)
                {
                    _isRegistered = NativeMethods.RegisterHotKey(_windowHandle, HOTKEY_ID, modifiers | NativeMethods.MOD_NOREPEAT, key);
                    if (_isRegistered)
                    {
                        RegisteredHotkey = hotkeyStr;
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Hotkey] Registration failed: {ex.Message}");
            }

            return false;
        }

        public void UnregisterHotkey()
        {
            if (_isRegistered)
            {
                NativeMethods.UnregisterHotKey(_windowHandle, HOTKEY_ID);
                _isRegistered = false;
            }
        }

        private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == NativeMethods.WM_HOTKEY && wParam.ToInt32() == HOTKEY_ID)
            {
                HotkeyPressed?.Invoke();
                handled = true;
            }
            return IntPtr.Zero;
        }

        public void Dispose()
        {
            UnregisterHotkey();
            _hwndSource?.RemoveHook(HwndHook);
        }
    }
}

