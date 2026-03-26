// SpeechController.swift
// SymbolicStateRecall
//
// Handles speech output for the navigation engine.
// Posts VoiceOver announcements via NSAccessibility in production,
// falls back to console output for CLI testing.

import Foundation
import AppKit
import AVFoundation

// MARK: - Speech Controller

class SpeechController: NavigationEngineDelegate {

    /// When true, output goes to console (for CLI testing).
    /// When false, uses VoiceOver announcements or speech synthesis.
    var useConsoleOutput: Bool = true

    /// The last text that was spoken, for UI display.
    private(set) var lastSpokenText: String = ""

    /// Speech synthesizer for when VoiceOver is not running.
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - NavigationEngineDelegate

    func navigationEngine(_ engine: NavigationEngine, didEmit event: NavigationEvent) {
        handleEvent(event)
    }

    /// Process a navigation event and speak the appropriate text.
    /// Can be called directly by the AppCoordinator after forwarding.
    func handleEvent(_ event: NavigationEvent) {
        switch event {
        case .recallActivated(_, let description):
            speak("Recall mode. \(description)")

        case .tokenAccepted(let description):
            speak(description)

        case .nodeSelected(_, let label):
            speak(label)

        case .contextOpened(let summary):
            speak(summary)

        case .inserted(let text):
            speak("Inserted: \(text)")

        case .navigatedBack(let description):
            speak(description)

        case .recallExited:
            speak("Recall mode exited.")

        case .error(let message):
            speak(message)
        }
    }

    // MARK: - Speech Output

    func speak(_ text: String) {
        lastSpokenText = text

        if useConsoleOutput {
            print("🔊 \(text)")
            return
        }

        if isVoiceOverRunning {
            postVoiceOverAnnouncement(text)
        } else {
            speakWithSynthesizer(text)
        }
    }

    // MARK: - VoiceOver Detection

    private var isVoiceOverRunning: Bool {
        if #available(macOS 13.0, *) {
            return NSWorkspace.shared.isVoiceOverEnabled
        }
        // Fallback: check if VoiceOver process is running
        return !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.VoiceOver.VoiceOver"
        ).isEmpty
    }

    // MARK: - Speech Synthesis (fallback when VoiceOver is off)

    private func speakWithSynthesizer(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.15
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)

        #if DEBUG
        print("🔊 [Synth] \(text)")
        #endif
    }

    // MARK: - VoiceOver Announcements

    private func postVoiceOverAnnouncement(_ text: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )

        #if DEBUG
        print("🔊 [VO] \(text)")
        #endif
    }
}
