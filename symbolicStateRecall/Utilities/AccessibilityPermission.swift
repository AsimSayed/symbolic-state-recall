// AccessibilityPermission.swift
// SymbolicStateRecall
//
// Utility for checking and prompting macOS Accessibility API permissions.
// Required for global hotkeys, CGEvent taps, and text insertion.

import ApplicationServices
import AppKit

struct AccessibilityPermission {

    /// Check if the process has Accessibility permission.
    static var isTrusted: Bool {
        return AXIsProcessTrusted()
    }

    /// Check and optionally prompt the user to grant permission.
    /// When called, macOS shows the system dialog pointing user to System Settings.
    /// Returns true if already trusted.
    @discardableResult
    static func checkWithPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to the Accessibility privacy pane.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
