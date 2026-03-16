// NavigationEngine.swift
// SymbolicStateRecall
//
// Core navigation engine implementing recall mode, query resolution,
// context stack, and node selection per the design specification.

import Foundation

// MARK: - Interaction State

enum RecallState: Equatable {
    case idle               // Normal editing, recall not active
    case recallActive       // Recall mode entered, waiting for input
    case pathBuilding       // User is typing query tokens
    case nodeResolved       // Query resolved to a valid node
    case error(String)      // Invalid query, with message
}

// MARK: - Recall Context

/// Represents the current navigation context within the tree.
/// Uses a class to allow recursive parent reference.
class RecallContext {
    enum Mode {
        case top    // Line/side level
        case local  // Inside a structure (fraction, integral, etc.)
    }

    let mode: Mode
    let node: MathNode?         // Current parent node (nil at top level)
    let items: [MathNode]       // Available children at this level
    weak var parentContext: RecallContext?  // For back navigation (weak to avoid retain cycles)

    init(mode: Mode, node: MathNode?, items: [MathNode], parentContext: RecallContext?) {
        self.mode = mode
        self.node = node
        self.items = items
        self.parentContext = parentContext
    }
}

// MARK: - Navigation Event

/// Events emitted by the navigation engine for the speech controller.
enum NavigationEvent {
    case recallActivated(itemCount: Int, contextDescription: String)
    case tokenAccepted(description: String)
    case nodeSelected(node: MathNode, label: String)
    case contextOpened(structureSummary: String)
    case inserted(text: String)
    case navigatedBack(contextDescription: String)
    case recallExited
    case error(message: String)
}

// MARK: - Navigation Engine Delegate

protocol NavigationEngineDelegate: AnyObject {
    func navigationEngine(_ engine: NavigationEngine, didEmit event: NavigationEvent)
}

// MARK: - Navigation Engine

/// The core recall navigation controller.
///
/// Manages the full interaction lifecycle:
/// 1. Trigger recall mode
/// 2. Accept query tokens (line, side, indexes)
/// 3. Resolve to nodes
/// 4. Expand into local contexts
/// 5. Insert selected node text
/// 6. Navigate back / exit
class NavigationEngine {

    // MARK: - Properties

    weak var delegate: NavigationEngineDelegate?

    private(set) var state: RecallState = .idle
    private(set) var selectedNode: MathNode?
    private(set) var currentContext: RecallContext?
    private(set) var currentPath: [String] = []  // tokens entered so far

    private var topLevelIndex: TopLevelIndex?
    private var root: MathNode?

    // Partial query state
    private var pendingLine: Int?
    private var pendingSide: String?

    // MARK: - Setup

    /// Load a parsed equation for navigation.
    func load(root: MathNode, index: TopLevelIndex) {
        self.root = root
        self.topLevelIndex = index
        reset()
    }

    /// Load from a string (parses internally).
    func load(equation: String) throws {
        let parser = Parser()
        let (root, index) = try parser.parseAndIndex(equation)
        load(root: root, index: index)
    }

    /// Reset all state.
    func reset() {
        state = .idle
        selectedNode = nil
        currentContext = nil
        currentPath = []
        pendingLine = nil
        pendingSide = nil
    }

    // MARK: - Trigger (Option + Space)

    /// Enter or re-enter recall mode.
    func trigger() {
        guard root != nil, let index = topLevelIndex else {
            emit(.error(message: "No equation loaded"))
            return
        }

        if case .recallActive = state {
            // Already in recall mode — cancel
            exitRecall()
            return
        }

        state = .recallActive
        selectedNode = nil
        currentPath = []
        pendingLine = nil
        pendingSide = nil

        if let ctx = currentContext, ctx.mode == .local {
            // Re-entering recall while in a local context
            let summary = ctx.node?.structureSummary ?? "Local context"
            emit(.recallActivated(
                itemCount: ctx.items.count,
                contextDescription: summary
            ))
        } else {
            // Top-level
            currentContext = nil
            let lines = index.lines
            if lines.count == 1 {
                // Auto-select line 1
                pendingLine = 1
                let sides = index.sides(line: 1)
                let totalItems = sides.reduce(0) { $0 + index.count(line: 1, side: $1) }
                emit(.recallActivated(
                    itemCount: totalItems,
                    contextDescription: "Line 1. \(totalItems) items."
                ))
            } else {
                emit(.recallActivated(
                    itemCount: lines.count,
                    contextDescription: "\(lines.count) lines."
                ))
            }
        }
    }

    // MARK: - Input Handling

    /// Process a single input token from the user.
    ///
    /// Tokens are: digits (line number or index), "L", "R" (side).
    func input(token: String) {
        guard state != .idle else { return }

        let normalized = token.uppercased().trimmingCharacters(in: .whitespaces)
        currentPath.append(normalized)

        // If in local context, token must be a number (index)
        if let ctx = currentContext, ctx.mode == .local {
            resolveLocalQuery(token: normalized, context: ctx)
            return
        }

        // Top-level query building
        if pendingLine == nil {
            // Expecting line number
            if let line = Int(normalized) {
                resolveLineToken(line)
            } else {
                emitError("Invalid line number: \(normalized)")
            }
        } else if pendingSide == nil {
            // Expecting side: L or R
            if normalized == "L" || normalized == "R" {
                resolveSideToken(normalized)
            } else {
                emitError("Invalid side. Enter L or R.")
            }
        } else {
            // Expecting index
            if let idx = Int(normalized) {
                resolveTopLevelIndex(idx)
            } else {
                emitError("Invalid index: \(normalized)")
            }
        }
    }

    // MARK: - Space (Insert)

    /// Insert the currently selected node's text at the cursor.
    /// Returns the serialized text, or nil if nothing is selected.
    func insertSelected() -> String? {
        guard let node = selectedNode else {
            emit(.error(message: "Nothing selected"))
            return nil
        }

        let text = MathSerializer.serialize(node)
        emit(.inserted(text: text))
        exitRecall()
        return text
    }

    // MARK: - Back (Backspace)

    /// Navigate up one context level.
    func goBack() {
        if let ctx = currentContext {
            if let parentCtx = ctx.parentContext {
                currentContext = parentCtx
                selectedNode = parentCtx.node
                let desc = parentCtx.node?.structureSummary ?? "Top level"
                emit(.navigatedBack(contextDescription: desc))
                state = .recallActive
            } else {
                // At top level already
                currentContext = nil
                selectedNode = nil
                pendingLine = nil
                pendingSide = nil
                currentPath = []
                emit(.navigatedBack(contextDescription: "Top level"))
                state = .recallActive
            }
        } else {
            // Already at top
            emit(.error(message: "At top level"))
        }
    }

    // MARK: - Exit (Escape)

    /// Exit recall mode entirely.
    func exitRecall() {
        reset()
        emit(.recallExited)
    }

    // MARK: - Private: Query Resolution

    private func resolveLineToken(_ line: Int) {
        guard let index = topLevelIndex, index.lines.contains(line) else {
            emitError("Line \(line) not found")
            return
        }

        pendingLine = line
        emit(.tokenAccepted(description: "Line \(line)"))
        state = .pathBuilding

        // If equation has no = sign, auto-select left side
        let sides = index.sides(line: line)
        if sides == ["L"] {
            pendingSide = "L"
            let count = index.count(line: line, side: "L")
            emit(.tokenAccepted(description: "Left side. \(count) items."))
        }
    }

    private func resolveSideToken(_ side: String) {
        guard let line = pendingLine, let index = topLevelIndex else { return }

        let items = index.items(line: line, side: side)
        if items.isEmpty {
            emitError("No items on \(side == "L" ? "left" : "right") side")
            return
        }

        pendingSide = side
        let sideName = side == "L" ? "Left side" : "Right side"
        emit(.tokenAccepted(description: "\(sideName). \(items.count) items."))
        state = .pathBuilding
    }

    private func resolveTopLevelIndex(_ position: Int) {
        guard let line = pendingLine,
              let side = pendingSide,
              let index = topLevelIndex else { return }

        guard let node = index.resolve(line: line, side: side, position: position) else {
            let count = index.count(line: line, side: side)
            if count == 0 {
                emitError("No items on this side")
            } else {
                emitError("No item at position \(position). \(count) items available.")
            }
            return
        }

        selectNode(node)
    }

    private func resolveLocalQuery(token: String, context: RecallContext) {
        guard let idx = Int(token) else {
            emitError("Invalid index: \(token)")
            return
        }

        guard idx >= 1 && idx <= context.items.count else {
            emitError("No child at position \(idx). \(context.items.count) items available.")
            return
        }

        let node = context.items[idx - 1]
        selectNode(node)
    }

    private func selectNode(_ node: MathNode) {
        selectedNode = node
        state = .nodeResolved

        emit(.nodeSelected(node: node, label: node.label))

        // If expandable, automatically open local context
        if node.isExpandable && node.children.count > 0 {
            let newContext = RecallContext(
                mode: .local,
                node: node,
                items: node.children,
                parentContext: currentContext
            )
            currentContext = newContext
            emit(.contextOpened(structureSummary: node.structureSummary))
        }
    }

    // MARK: - Event Emission

    private func emit(_ event: NavigationEvent) {
        delegate?.navigationEngine(self, didEmit: event)
    }

    private func emitError(_ message: String) {
        state = .error(message)
        // Recover: stay in recall, keep last valid path prefix
        currentPath.removeLast()
        emit(.error(message: message))
        state = .recallActive
    }
}
