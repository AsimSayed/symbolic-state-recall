// HotkeyManager.swift
// SymbolicStateRecall
//
// Manages global hotkey registration for Option+Space to trigger recall mode.
// Uses Carbon Event Manager for global hotkey support.

import Foundation
import Carbon

// MARK: - Hotkey Manager Delegate

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyManagerDidTrigger(_ manager: HotkeyManager)
}

// MARK: - Hotkey Manager

class HotkeyManager {

    weak var delegate: HotkeyManagerDelegate?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// The hotkey ID used for Carbon events.
    private let hotkeyID = EventHotKeyID(signature: OSType(0x5353_5243), // "SSRC"
                                          id: 1)

    // MARK: - Lifecycle

    deinit {
        unregister()
    }

    // MARK: - Registration

    /// Register Option+Space as the global hotkey.
    /// Returns true if registration succeeded.
    @discardableResult
    func register() -> Bool {
        // Already registered?
        guard hotkeyRef == nil else { return true }

        // Option + Space
        // Virtual key code for Space is 0x31 (49)
        // Option modifier is optionKey (0x0800)
        let keyCode: UInt32 = 0x31  // Space
        let modifiers: UInt32 = UInt32(optionKey)

        // Install event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return false
        }

        // Register the hotkey
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registerStatus == noErr else {
            print("Failed to register hotkey: \(registerStatus)")
            return false
        }

        print("✅ Registered global hotkey: Option+Space")
        return true
    }

    /// Unregister the global hotkey.
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // MARK: - Internal

    fileprivate func handleHotkey() {
        delegate?.hotkeyManagerDidTrigger(self)
    }
}

// MARK: - Carbon Callback

private func hotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {

    guard let userData = userData else { return OSStatus(eventNotHandledErr) }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

    // Verify it's our hotkey
    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    guard status == noErr else { return status }

    // Dispatch to main thread
    DispatchQueue.main.async {
        manager.handleHotkey()
    }

    return noErr
}
