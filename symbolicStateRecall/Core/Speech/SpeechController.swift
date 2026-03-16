// SpeechController.swift
// SymbolicStateRecall
//
// Handles speech output for the navigation engine.
// In v1 prototype, prints to console. In production, posts
// VoiceOver announcements via NSAccessibility.

import Foundation
// import AppKit  // Uncomment when building in Xcode

// MARK: - Speech Controller

class SpeechController: NavigationEngineDelegate {

    /// When true, output goes to console (for CLI testing).
    /// When false, posts VoiceOver announcements.
    var useConsoleOutput: Bool = true

    // MARK: - NavigationEngineDelegate

    func navigationEngine(_ engine: NavigationEngine, didEmit event: NavigationEvent) {
        switch event {
        case .recallActivated(let count, let description):
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
            speak("Error. \(message)")
        }
    }

    // MARK: - Speech Output

    func speak(_ text: String) {
        if useConsoleOutput {
            print("🔊 \(text)")
        } else {
            postVoiceOverAnnouncement(text)
        }
    }

    /// Post an announcement through VoiceOver.
    /// Requires the app to be accessibility-aware.
    private func postVoiceOverAnnouncement(_ text: String) {
        // Uncomment when building in Xcode with AppKit:
        //
        // NSAccessibility.post(
        //     element: NSApp.mainWindow as Any,
        //     notification: .announcementRequested,
        //     userInfo: [
        //         .announcement: text,
        //         .priority: NSAccessibilityPriorityLevel.high.rawValue
        //     ]
        // )
        //
        // For now, fall back to console:
        print("🔊 [VO] \(text)")
    }
}
