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
    var parentContext: RecallContext?  // For back navigation (no retain cycle: parent doesn't reference child)

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
    private var roots: [MathNode] = []

    // Partial query state
    private var pendingLine: Int?
    private var pendingSide: String?

    // MARK: - Setup

    /// Load a parsed equation for navigation (single-line).
    func load(root: MathNode, index: TopLevelIndex) {
        self.roots = [root]
        self.topLevelIndex = index
        reset()
    }

    /// Load multiple parsed equations for navigation (multi-line).
    func load(roots: [MathNode], index: TopLevelIndex) {
        self.roots = roots
        self.topLevelIndex = index
        reset()
    }

    /// Load from a string (parses internally, single-line).
    func load(equation: String) throws {
        let parser = Parser()
        let (root, index) = try parser.parseAndIndex(equation)
        load(root: root, index: index)
    }

    /// Load from a multi-line string (parses each line as separate equation).
    func loadMultiLine(equations: String) throws {
        let parser = Parser()
        let (roots, index) = try parser.parseMultiLine(equations)
        load(roots: roots, index: index)
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
        guard !roots.isEmpty, let index = topLevelIndex else {
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
                // Single line — auto-select it
                pendingLine = 1
                let sides = index.sides(line: 1)

                if sides.count == 1 {
                    // Single side too — skip straight to item selection
                    let side = sides[0]
                    pendingSide = side
                    selectedNode = sideNode(line: 1, side: side)
                    let items = index.items(line: 1, side: side)
                    emit(.recallActivated(
                        itemCount: items.count,
                        contextDescription: itemSummary(items)
                    ))
                } else {
                    // Multiple parts — prompt for part number
                    let totalItems = sides.reduce(0) { $0 + index.count(line: 1, side: $1) }
                    emit(.recallActivated(
                        itemCount: totalItems,
                        contextDescription: "\(sides.count) parts."
                    ))
                }
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
            // Expecting part number (or L/R aliases for parts 1/2)
            let partKey: String?
            if normalized == "L" { partKey = "1" }
            else if normalized == "R" { partKey = "2" }
            else if Int(normalized) != nil { partKey = normalized }
            else { partKey = nil }

            if let key = partKey {
                resolveSideToken(key)
            } else {
                emitError("Enter a part number.")
            }
        } else {
            // Part selected, expecting item index
            if let idx = Int(normalized) {
                resolveTopLevelIndex(idx)
            } else if normalized == "L" || normalized == "R" {
                // Allow switching parts via L/R aliases
                resolveSideToken(normalized == "L" ? "1" : "2")
            } else {
                emitError("Enter a number to select an item.")
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
                // Go to parent context
                currentContext = parentCtx
                selectedNode = parentCtx.node
                let desc = parentCtx.node?.structureSummary ?? itemSummary(parentCtx.items)
                emit(.navigatedBack(contextDescription: desc))
                state = .recallActive
            } else {
                // At topmost context (side level), go back to side or line selection
                currentContext = nil
                selectedNode = nil
                currentPath = []
                goBackToSideOrLineLevel()
                state = .recallActive
            }
        } else {
            // No context — back out of side or line selection
            goBackToSideOrLineLevel()
        }
    }

    /// Shared logic for backing up to side selection or line selection.
    private func goBackToSideOrLineLevel() {
        if pendingSide != nil, let line = pendingLine, let index = topLevelIndex {
            let sides = index.sides(line: line)
            if sides.count > 1 {
                // Go back to part selection — line is still the implicit selection
                pendingSide = nil
                selectedNode = (line >= 1 && line <= roots.count) ? roots[line - 1] : nil
                currentPath = []
                emit(.navigatedBack(contextDescription: "Line \(line). \(sides.count) parts."))
            } else if roots.count > 1 {
                // Single side — go back to line listing
                pendingLine = nil
                pendingSide = nil
                selectedNode = nil
                currentPath = []
                emit(.navigatedBack(contextDescription: "\(roots.count) lines."))
            } else {
                emit(.navigatedBack(contextDescription: "At top level. Press Escape to exit."))
            }
        } else if pendingLine != nil && roots.count > 1 {
            // At line level — go back to line listing
            pendingLine = nil
            pendingSide = nil
            selectedNode = nil
            currentPath = []
            emit(.navigatedBack(contextDescription: "\(roots.count) lines."))
        } else {
            emit(.navigatedBack(contextDescription: "At top level. Press Escape to exit."))
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
        // Select the line's root so Space inserts the whole line
        if line >= 1 && line <= roots.count {
            selectedNode = roots[line - 1]
        }
        emit(.tokenAccepted(description: "Line \(line)"))
        state = .pathBuilding

        // If only one part, auto-select it
        let sides = index.sides(line: line)
        if sides.count == 1 {
            let side = sides[0]
            pendingSide = side
            selectedNode = sideNode(line: line, side: side)
            let items = index.items(line: line, side: side)
            emit(.tokenAccepted(description: itemSummary(items)))
        }
    }

    private func resolveSideToken(_ side: String) {
        guard let line = pendingLine, let index = topLevelIndex else { return }

        let items = index.items(line: line, side: side)
        if items.isEmpty {
            let available = index.sides(line: line)
            emitError("No part \(side). \(available.count) parts available.")
            return
        }

        pendingSide = side
        currentContext = nil
        // Select the part node so Space inserts the whole part
        selectedNode = sideNode(line: line, side: side)
        emit(.tokenAccepted(description: "Part \(side). \(itemSummary(items))"))
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

        // Create a side-level context so "back" can return to item selection
        if currentContext == nil {
            let sideItems = index.items(line: line, side: side)
            currentContext = RecallContext(
                mode: .top,
                node: nil,
                items: sideItems,
                parentContext: nil
            )
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
            // Read structure type and child labels
            let childDescs = node.children.enumerated().map { (i, child) in
                let role = i < node.childLabels.count ? node.childLabels[i] : "item \(i + 1)"
                return "\(i + 1) \(role): \(child.label)"
            }
            let summary = "\(node.structureSummary) \(childDescs.joined(separator: ", "))"
            emit(.contextOpened(structureSummary: summary))
        }
    }

    // MARK: - Node Lookup

    /// Find the side node for a given line and side key.
    private func sideNode(line: Int, side: String) -> MathNode? {
        guard line >= 1 && line <= roots.count else { return nil }
        let root = roots[line - 1]
        if root.type == .equation {
            return root.children.first { $0.value == side }
        }
        // Single side — root is the side node itself
        return root
    }

    // MARK: - Item Summary

    /// Build a spoken summary of items at a level, e.g. "3 items: x squared, plus 3 x, plus 5"
    private func itemSummary(_ items: [MathNode]) -> String {
        let count = "\(items.count) \(items.count == 1 ? "item" : "items")"
        if items.isEmpty { return count }
        let labels = items.prefix(6).map { $0.label }
        let listing = labels.joined(separator: ", ")
        if items.count > 6 {
            return "\(count): \(listing), and more"
        }
        return "\(count): \(listing)"
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
