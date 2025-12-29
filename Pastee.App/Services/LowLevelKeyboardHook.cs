using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Pastee.App.Services
{
    public class LowLevelKeyboardHook : IDisposable
    {
        private IntPtr _hookId = IntPtr.Zero;
        private readonly NativeMethods.LowLevelKeyboardProc _proc;
        private string _targetHotkey = "Win + V";
        private int _targetVk;
        private bool _targetCtrl;
        private bool _targetShift;
        private bool _targetAlt;
        private bool _targetWin;

        public event Action? HotkeyPressed;

        public LowLevelKeyboardHook()
        {
            _proc = HookCallback;
        }

        public void Install(string hotkeyStr)
        {
            Uninstall();
            _targetHotkey = hotkeyStr;
            ParseHotkey(hotkeyStr);

            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule curModule = curProcess.MainModule!)
            {
                _hookId = NativeMethods.SetWindowsHookEx(NativeMethods.WH_KEYBOARD_LL, _proc, 
                    NativeMethods.GetModuleHandle(curModule.ModuleName!), 0);
                Debug.WriteLine($"Keyboard hook installed for {_targetHotkey}: {_hookId != IntPtr.Zero}");
            }
        }

        private void ParseHotkey(string hotkeyStr)
        {
            _targetCtrl = hotkeyStr.Contains("Ctrl");
            _targetShift = hotkeyStr.Contains("Shift");
            _targetAlt = hotkeyStr.Contains("Alt");
            _targetWin = hotkeyStr.Contains("Win");

            string[] parts = hotkeyStr.Split(new[] { " + " }, StringSplitOptions.RemoveEmptyEntries);
            string keyName = parts[parts.Length - 1];

            if (Enum.TryParse(typeof(System.Windows.Input.Key), keyName, out object? k))
            {
                _targetVk = System.Windows.Input.KeyInterop.VirtualKeyFromKey((System.Windows.Input.Key)k);
            }
        }

        public void Uninstall()
        {
            if (_hookId != IntPtr.Zero)
            {
                NativeMethods.UnhookWindowsHookEx(_hookId);
                _hookId = IntPtr.Zero;
            }
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                int msg = wParam.ToInt32();
                if (msg == NativeMethods.WM_KEYDOWN || msg == NativeMethods.WM_SYSKEYDOWN)
                {
                    var hookStruct = Marshal.PtrToStructure<NativeMethods.KBDLLHOOKSTRUCT>(lParam);

                    if (hookStruct.vkCode == _targetVk)
                    {
                        bool ctrlPressed = (NativeMethods.GetAsyncKeyState(NativeMethods.VK_CONTROL) & 0x8000) != 0;
                        // Shift, Alt, Win codes
                        bool shiftPressed = (NativeMethods.GetAsyncKeyState(0x10) & 0x8000) != 0;
                        bool altPressed = (NativeMethods.GetAsyncKeyState(0x12) & 0x8000) != 0;
                        bool winPressed = (NativeMethods.GetAsyncKeyState(NativeMethods.VK_LWIN) & 0x8000) != 0 ||
                                          (NativeMethods.GetAsyncKeyState(NativeMethods.VK_RWIN) & 0x8000) != 0;

                        if (ctrlPressed == _targetCtrl && shiftPressed == _targetShift && 
                            altPressed == _targetAlt && winPressed == _targetWin)
                        {
                            Debug.WriteLine($"{_targetHotkey} intercepted!");
                            System.Windows.Application.Current?.Dispatcher.BeginInvoke(new Action(() =>
                            {
                                HotkeyPressed?.Invoke();
                            }));
                            return (IntPtr)1; // Block the key
                        }
                    }
                }
            }
            return NativeMethods.CallNextHookEx(_hookId, nCode, wParam, lParam);
        }

        public void Dispose()
        {
            Uninstall();
        }
    }
}

