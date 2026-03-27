// FocusedTextReader.swift
// SymbolicStateRecall
//
// Reads text from the currently focused UI element in the frontmost
// application using macOS Accessibility APIs (AXUIElement).

import ApplicationServices
import Foundation

// MARK: - Error

enum FocusedTextReaderError: Error, CustomStringConvertible {
    case accessibilityNotTrusted
    case noFocusedApplication
    case noFocusedElement
    case noTextContent
    case axError(AXError)

    var description: String {
        switch self {
        case .accessibilityNotTrusted: return "Accessibility permission not granted"
        case .noFocusedApplication: return "No focused application found"
        case .noFocusedElement: return "No focused text element found"
        case .noTextContent: return "Focused element has no text content"
        case .axError(let code): return "Accessibility API error: \(code.rawValue)"
        }
    }
}

// MARK: - Delegate

protocol FocusedTextReaderDelegate: AnyObject {
    func focusedTextReader(_ reader: FocusedTextReader, didReadText text: String)
    func focusedTextReader(_ reader: FocusedTextReader, didFailWithError error: FocusedTextReaderError)
}

// MARK: - Reader

class FocusedTextReader {

    weak var delegate: FocusedTextReaderDelegate?

    /// System-wide accessibility element, created once and reused.
    private let systemWide: AXUIElement = AXUIElementCreateSystemWide()

    // MARK: - Public API

    /// Read text from the currently focused UI element.
    /// Prefers selected text; falls back to full element value.
    /// Calls delegate on completion.
    func readFocusedText() {
        guard AXIsProcessTrusted() else {
            delegate?.focusedTextReader(self, didFailWithError: .accessibilityNotTrusted)
            return
        }

        guard let app = focusedApplication() else {
            delegate?.focusedTextReader(self, didFailWithError: .noFocusedApplication)
            return
        }

        guard let element = focusedElement(in: app) else {
            delegate?.focusedTextReader(self, didFailWithError: .noFocusedElement)
            return
        }

        if let text = textFromElement(element) {
            delegate?.focusedTextReader(self, didReadText: text)
        } else {
            delegate?.focusedTextReader(self, didFailWithError: .noTextContent)
        }
    }

    /// Read text synchronously. Returns nil on any failure.
    func readFocusedTextSync() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let app = focusedApplication() else { return nil }
        guard let element = focusedElement(in: app) else { return nil }
        return textFromElement(element)
    }

    /// Read text from a specific app by PID. Used when the user has switched
    /// to SSR's window but we want to read from the previously-focused app.
    func readTextFromApp(pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        guard let element = focusedElement(in: appElement) else { return nil }
        return textFromElement(element)
    }

    // MARK: - Private

    private func focusedApplication() -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &value
        )
        guard result == .success else { return nil }
        return (value as! AXUIElement)
    }

    private func focusedElement(in app: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            app,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )
        guard result == .success else { return nil }
        return (value as! AXUIElement)
    }

    private func textFromElement(_ element: AXUIElement) -> String? {
        // Prefer selected text (user highlights the math they want)
        if let selected = attribute(element, key: kAXSelectedTextAttribute),
           !selected.isEmpty {
            return selected
        }
        // Fall back to full value
        if let full = attribute(element, key: kAXValueAttribute),
           !full.isEmpty {
            return full
        }
        return nil
    }

    private func attribute(_ element: AXUIElement, key: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }
}
