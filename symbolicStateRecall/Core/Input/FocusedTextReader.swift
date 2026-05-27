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

    // MARK: - Private — Element Discovery

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

    // MARK: - Private — Text Extraction

    private func textFromElement(_ element: AXUIElement) -> String? {
        // 1. Prefer selected text (user highlights the math they want)
        if let selected = stringAttribute(element, key: kAXSelectedTextAttribute),
           !selected.isEmpty {
            return selected
        }

        // 2. Try reading the block of lines around the cursor using AX line APIs
        if let block = blockAroundCursor(element: element) {
            return block
        }

        // 3. Fall back to full value
        if let full = stringAttribute(element, key: kAXValueAttribute),
           !full.isEmpty {
            return full
        }

        return nil
    }

    // MARK: - Private — Cursor-Aware Block Extraction

    /// Uses AX parametrized attributes to read lines around the cursor,
    /// expanding outward through contiguous non-empty lines.
    private func blockAroundCursor(element: AXUIElement) -> String? {
        // Get cursor position
        guard let cursorPos = cursorIndex(element: element) else { return nil }

        // Get total line count — needed for bounds checking
        guard let totalChars = intAttribute(element, key: kAXNumberOfCharactersAttribute),
              totalChars > 0 else { return nil }

        // Find which line the cursor is on
        guard let cursorLine = lineForIndex(element: element, index: cursorPos) else { return nil }

        // Read the cursor line text
        guard let cursorLineText = stringForLine(element: element, line: cursorLine) else { return nil }

        // If cursor line is empty, search nearby for a non-empty line
        var anchorLine = cursorLine
        if cursorLineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Search backward first, then forward
            var found = false
            for offset in 1...10 {
                if anchorLine >= offset {
                    if let text = stringForLine(element: element, line: anchorLine - offset),
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        anchorLine = anchorLine - offset
                        found = true
                        break
                    }
                }
                if let text = stringForLine(element: element, line: anchorLine + offset),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    anchorLine = anchorLine + offset
                    found = true
                    break
                }
            }
            if !found { return nil }
        }

        // Expand upward through non-empty lines
        var blockStart = anchorLine
        while blockStart > 0 {
            guard let prevText = stringForLine(element: element, line: blockStart - 1) else { break }
            if prevText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            blockStart -= 1
        }

        // Expand downward through non-empty lines
        var blockEnd = anchorLine
        while true {
            guard let nextText = stringForLine(element: element, line: blockEnd + 1) else { break }
            if nextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            blockEnd += 1
        }

        // Collect all lines in the block
        var lines: [String] = []
        for lineNum in blockStart...blockEnd {
            if let text = stringForLine(element: element, line: lineNum) {
                let trimmed = text.trimmingCharacters(in: .newlines)
                lines.append(trimmed)
            }
        }

        let result = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    // MARK: - Private — AX Helpers

    /// Get the cursor character index from the selected text range.
    private func cursorIndex(element: AXUIElement) -> Int? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )
        guard result == .success else { return nil }

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range.location
    }

    /// Get the line number for a character index (parametrized attribute).
    private func lineForIndex(element: AXUIElement, index: Int) -> Int? {
        var value: AnyObject?
        let cfIndex = index as CFNumber
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXLineForIndexParameterizedAttribute as CFString,
            cfIndex,
            &value
        )
        guard result == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }

    /// Get the character range for a line number (parametrized attribute).
    private func rangeForLine(element: AXUIElement, line: Int) -> CFRange? {
        var value: AnyObject?
        let cfLine = line as CFNumber
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXRangeForLineParameterizedAttribute as CFString,
            cfLine,
            &value
        )
        guard result == .success else { return nil }

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    /// Get the string content for a line number.
    private func stringForLine(element: AXUIElement, line: Int) -> String? {
        guard var range = rangeForLine(element: element, line: line) else { return nil }

        var value: AnyObject?
        let cfRange = AXValueCreate(.cfRange, &range)! as AnyObject
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            cfRange,
            &value
        )
        guard result == .success else { return nil }
        return value as? String
    }

    private func stringAttribute(_ element: AXUIElement, key: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func intAttribute(_ element: AXUIElement, key: String) -> Int? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }
}
