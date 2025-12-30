//
//  HotkeyService.swift
//  Pastee
//
//  全局快捷键服务
//

import Foundation
import Carbon
import AppKit

class HotkeyService {
    static let shared = HotkeyService()
    
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var currentHotkey: String = ""
    
    var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    // MARK: - Register Hotkey
    
    func register(hotkey: String) {
        unregister()
        currentHotkey = hotkey
        
        let (keyCode, modifiers) = parseHotkey(hotkey)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCharCode("PSTE")
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, event, _ in
            NotificationCenter.default.post(name: .globalHotkeyPressed, object: nil)
            return noErr
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        guard status == noErr else {
            print("Failed to install event handler")
            return
        }
        
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if registerStatus == noErr {
            // 监听通知
            NotificationCenter.default.addObserver(
                forName: .globalHotkeyPressed,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onHotkeyPressed?()
            }
        } else {
            print("Failed to register hotkey: \(registerStatus)")
        }
    }
    
    func unregister() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        NotificationCenter.default.removeObserver(self, name: .globalHotkeyPressed, object: nil)
    }
    
    // MARK: - Parse Hotkey String
    
    private func parseHotkey(_ hotkey: String) -> (keyCode: Int, modifiers: UInt32) {
        var modifiers: UInt32 = 0
        var keyCode: Int = 0
        
        let parts = hotkey.lowercased().components(separatedBy: " + ")
        
        for part in parts {
            switch part.trimmingCharacters(in: .whitespaces) {
            case "command", "cmd":
                modifiers |= UInt32(cmdKey)
            case "control", "ctrl":
                modifiers |= UInt32(controlKey)
            case "option", "alt":
                modifiers |= UInt32(optionKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "win":
                // Win键在Mac上映射为Command
                modifiers |= UInt32(cmdKey)
            default:
                // 最后一个部分应该是按键
                keyCode = keyCodeForCharacter(part)
            }
        }
        
        return (keyCode, modifiers)
    }
    
    private func keyCodeForCharacter(_ char: String) -> Int {
        let keyMap: [String: Int] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
            "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
            "y": 16, "z": 6,
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28,
            "9": 25, "0": 29,
            "space": 49, "return": 36, "tab": 48, "delete": 51, "escape": 53,
            "up": 126, "down": 125, "left": 123, "right": 124
        ]
        return keyMap[char.lowercased()] ?? 0
    }
    
    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
    
    // MARK: - Hotkey Presets
    
    static let presets: [String] = [
        "Command + Shift + V",
        "Command + Shift + C",
        "Command + Option + V",
        "Control + Shift + V",
        "Control + Option + V"
    ]
}

