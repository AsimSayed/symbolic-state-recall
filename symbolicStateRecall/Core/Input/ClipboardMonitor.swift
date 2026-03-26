// ClipboardMonitor.swift
// SymbolicStateRecall
//
// Monitors the system clipboard (pasteboard) for mathematical expressions.
// Triggers parsing when new content is detected.

import Foundation
import AppKit

// MARK: - Clipboard Monitor Delegate

protocol ClipboardMonitorDelegate: AnyObject {
    /// Called when new text content is detected on the clipboard.
    func clipboardMonitor(_ monitor: ClipboardMonitor, didDetectText text: String)

    /// Called when clipboard content could not be parsed as math.
    func clipboardMonitor(_ monitor: ClipboardMonitor, didFailWithError error: Error)
}

// MARK: - Clipboard Monitor

class ClipboardMonitor {

    weak var delegate: ClipboardMonitorDelegate?

    /// The system pasteboard.
    private let pasteboard = NSPasteboard.general

    /// Last known change count to detect new content.
    private var lastChangeCount: Int = 0

    /// Timer for polling the clipboard (macOS doesn't have clipboard change notifications).
    private var pollTimer: Timer?

    /// Polling interval in seconds.
    var pollInterval: TimeInterval = 0.5

    /// Whether monitoring is active.
    private(set) var isMonitoring: Bool = false

    /// Suppresses clipboard change detection during text insertion to prevent feedback loops.
    private var isInserting: Bool = false

    // MARK: - Lifecycle

    deinit {
        stop()
    }

    // MARK: - Control

    /// Start monitoring the clipboard for changes.
    func start() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastChangeCount = pasteboard.changeCount

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        print("✅ Clipboard monitoring started")
    }

    /// Stop monitoring the clipboard.
    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        isMonitoring = false
    }

    /// Manually read the current clipboard content.
    /// Returns the text content, or nil if not available.
    func currentText() -> String? {
        return pasteboard.string(forType: .string)
    }

    /// Force a check of the clipboard (useful for manual trigger).
    func forceCheck() {
        if let text = currentText(), !text.isEmpty {
            delegate?.clipboardMonitor(self, didDetectText: text)
        }
    }

    // MARK: - Private

    private func checkClipboard() {
        guard !isInserting else { return }

        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }

        // Notify delegate of new content
        delegate?.clipboardMonitor(self, didDetectText: text)
    }
}

// MARK: - Text Insertion

extension ClipboardMonitor {

    /// Insert text at the current cursor position.
    /// This uses the pasteboard to simulate a paste operation.
    ///
    /// - Parameter text: The text to insert.
    /// - Parameter restoreClipboard: If true, restores the original clipboard content after insertion.
    func insertText(_ text: String, restoreClipboard: Bool = true) {
        isInserting = true

        // Save current clipboard content
        let savedContent = restoreClipboard ? pasteboard.string(forType: .string) : nil

        // Put new text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V paste
        simulatePaste()

        // Restore original clipboard content after a short delay, then re-enable monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            if let saved = savedContent {
                self?.pasteboard.clearContents()
                self?.pasteboard.setString(saved, forType: .string)
            }
            // Update lastChangeCount so we don't re-trigger on the restored content
            if let self = self {
                self.lastChangeCount = self.pasteboard.changeCount
            }
            self?.isInserting = false
        }
    }

    /// Simulate a Cmd+V paste keystroke.
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up: Cmd+V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
