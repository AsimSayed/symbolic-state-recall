// AppCoordinator.swift
// SymbolicStateRecall
//
// Central coordinator that owns all runtime components and wires them together.

import SwiftUI
import AppKit
import Carbon

// MARK: - App Coordinator

class AppCoordinator: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Components

    let engine = NavigationEngine()
    let speech = SpeechController()
    let hotkeyManager = HotkeyManager()
    let clipboardMonitor = ClipboardMonitor()
    let focusedTextReader = FocusedTextReader()

    // MARK: - Published State (for ContentView)

    @Published var currentEquationText: String = ""
    @Published var recallState: RecallState = .idle
    @Published var lastSpokenText: String = ""
    @Published var isAccessibilityGranted: Bool = false
    @Published var selectedNodeLabel: String = ""
    @Published var currentPath: [String] = []

    // MARK: - Private

    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    /// PID of the last frontmost app that isn't SSR. Used to read focused text
    /// when the user switches to SSR's window before triggering recall.
    private var lastExternalAppPID: pid_t = 0
    private var workspaceObserver: Any?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.delegate = self
        hotkeyManager.delegate = self
        clipboardMonitor.delegate = self
        focusedTextReader.delegate = self
        speech.useConsoleOutput = false

        // Clipboard doesn't need accessibility — always start
        clipboardMonitor.start()

        // Try hotkey + check accessibility silently (no prompt)
        hotkeyManager.register()
        isAccessibilityGranted = AccessibilityPermission.isTrusted

        // Track frontmost app changes so we can read from the last external app
        startTrackingFrontmostApp()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        recheckAccessibility()
    }

    /// Re-check accessibility permission and update state if newly granted.
    func recheckAccessibility() {
        let trusted = AccessibilityPermission.isTrusted
        if trusted && !isAccessibilityGranted {
            isAccessibilityGranted = true
            hotkeyManager.register()
        } else if !trusted {
            isAccessibilityGranted = false
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanupAllMonitors()
        hotkeyManager.unregister()
        clipboardMonitor.stop()
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    // MARK: - UI Actions

    func loadEquationFromUI(_ text: String) {
        do {
            if text.contains("\n") {
                try engine.loadMultiLine(equations: text)
            } else {
                try engine.load(equation: text)
            }
            currentEquationText = text
        } catch {
            speech.speak("Could not parse: \(error.localizedDescription)")
        }
    }

    func triggerRecallFromUI() {
        if engine.state == .idle {
            // Try reading from the last external app (since SSR is now focused)
            tryReadFromLastExternalApp()
            installKeyMonitors()
        }
        engine.trigger()
        updatePublishedState()
    }

    // MARK: - Key Monitors

    /// Install all available key monitors for recall mode.
    private func installKeyMonitors() {
        // Local monitor: always works when app is focused
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleKeyEvent(event) == true {
                    return nil
                }
                return event
            }
        }

        // Global monitor: works across apps (needs accessibility)
        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
        }

        // Event tap: intercepts and suppresses keys across apps (needs accessibility)
        installEventTap()
    }

    private func cleanupAllMonitors() {
        removeEventTap()
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
    }

    // MARK: - CGEvent Tap

    private func installEventTap() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let coordinator = Unmanaged<AppCoordinator>.fromOpaque(refcon).takeUnretainedValue()
                return coordinator.handleCGKeyEvent(event)
            },
            userInfo: refcon
        ) else {
            #if DEBUG
            print("⚠️ CGEvent tap unavailable — cross-app key suppression disabled")
            #endif
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = eventTapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            eventTapRunLoopSource = nil
        }
    }

    private func handleCGKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passRetained(event)
        guard engine.state != .idle else { return passThrough }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if let token = recallTokenForKeyCode(UInt16(keyCode)) {
            dispatchRecallToken(token)
            return nil // Suppress
        }
        return passThrough
    }

    // MARK: - NSEvent Handler

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard engine.state != .idle else { return false }
        if let token = recallTokenForKeyCode(event.keyCode) {
            dispatchRecallToken(token)
            return true
        }
        return false
    }

    // MARK: - Token Dispatch

    private enum RecallToken {
        case digit(String), side(String), space, backspace, escape
    }

    private func dispatchRecallToken(_ token: RecallToken) {
        switch token {
        case .digit(let d): engine.input(token: d)
        case .side(let s):  engine.input(token: s)
        case .space:        handleInsert()
        case .backspace:    engine.goBack()
        case .escape:       engine.exitRecall()
        }
        updatePublishedState()
    }

    private func recallTokenForKeyCode(_ keyCode: UInt16) -> RecallToken? {
        switch keyCode {
        case 0x12: return .digit("1")
        case 0x13: return .digit("2")
        case 0x14: return .digit("3")
        case 0x15: return .digit("4")
        case 0x17: return .digit("5")
        case 0x16: return .digit("6")
        case 0x1A: return .digit("7")
        case 0x1C: return .digit("8")
        case 0x19: return .digit("9")
        case 0x1D: return .digit("0")
        case 0x25: return .side("L")
        case 0x0F: return .side("R")
        case 0x31: return .space
        case 0x33: return .backspace
        case 0x35: return .escape
        default:   return nil
        }
    }

    // MARK: - Insert

    private func handleInsert() {
        guard let text = engine.insertSelected() else { return }
        clipboardMonitor.insertText(text, restoreClipboard: true)
    }

    // MARK: - State Updates

    private func updatePublishedState() {
        recallState = engine.state
        currentPath = engine.currentPath
        selectedNodeLabel = engine.selectedNode?.label ?? ""
        lastSpokenText = speech.lastSpokenText

        if engine.state == .idle {
            cleanupAllMonitors()
        }
    }
}

// MARK: - NavigationEngineDelegate

extension AppCoordinator: NavigationEngineDelegate {
    func navigationEngine(_ engine: NavigationEngine, didEmit event: NavigationEvent) {
        speech.handleEvent(event)
        updatePublishedState()
    }
}

// MARK: - HotkeyManagerDelegate

extension AppCoordinator: HotkeyManagerDelegate {
    func hotkeyManagerDidTrigger(_ manager: HotkeyManager) {
        // If already in recall, toggle off
        if engine.state != .idle {
            engine.trigger()
            updatePublishedState()
            return
        }

        // Try to read from focused text element before triggering.
        // First try the currently focused app (works when hotkey fires cross-app).
        // Fall back to last external app PID (works when SSR is focused).
        if let text = focusedTextReader.readFocusedTextSync(), !text.isEmpty {
            loadFocusedText(text)
        } else {
            tryReadFromLastExternalApp()
        }

        installKeyMonitors()
        engine.trigger()
        updatePublishedState()
    }
}

// MARK: - Frontmost App Tracking

private extension AppCoordinator {
    func startTrackingFrontmostApp() {
        // Seed with the current frontmost app (if it's not us)
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalAppPID = frontmost.processIdentifier
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // Only track apps that aren't SSR
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self?.lastExternalAppPID = app.processIdentifier
            }
        }
    }

    func tryReadFromLastExternalApp() {
        guard lastExternalAppPID != 0 else { return }
        if let text = focusedTextReader.readTextFromApp(pid: lastExternalAppPID), !text.isEmpty {
            loadFocusedText(text)
        }
    }
}

// MARK: - Focused Text Loading

private extension AppCoordinator {
    func loadFocusedText(_ text: String) {
        do {
            if text.contains("\n") {
                try engine.loadMultiLine(equations: text)
            } else {
                try engine.load(equation: text)
            }
            currentEquationText = text
            speech.speak("Equation loaded from screen")
        } catch {
            // Keep previously loaded equation
            if currentEquationText.isEmpty {
                speech.speak("Focused text not recognized as math")
            }
            #if DEBUG
            print("🔍 Focused text not parseable: \(error)")
            #endif
        }
    }
}

// MARK: - FocusedTextReaderDelegate

extension AppCoordinator: FocusedTextReaderDelegate {
    func focusedTextReader(_ reader: FocusedTextReader, didReadText text: String) {
        loadFocusedText(text)
    }

    func focusedTextReader(_ reader: FocusedTextReader, didFailWithError error: FocusedTextReaderError) {
        #if DEBUG
        print("🔍 Focused text reader: \(error)")
        #endif
    }
}

// MARK: - ClipboardMonitorDelegate

extension AppCoordinator: ClipboardMonitorDelegate {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didDetectText text: String) {
        do {
            if text.contains("\n") {
                try engine.loadMultiLine(equations: text)
            } else {
                try engine.load(equation: text)
            }
            currentEquationText = text
            speech.speak("Equation loaded")
        } catch {
            // Keep previously loaded equation — don't clear it
            speech.speak("Clipboard content not recognized as math")
            #if DEBUG
            print("📋 Clipboard text not parseable as math: \(error)")
            #endif
        }
    }

    func clipboardMonitor(_ monitor: ClipboardMonitor, didFailWithError error: Error) {
        #if DEBUG
        print("📋 Clipboard error: \(error)")
        #endif
    }
}
