// MathNode.swift
// MathRecall
//
// Core AST node model for mathematical expressions.

import Foundation

// MARK: - Node Type

/// All supported mathematical structure types for v1 (calculus scope).
enum NodeType: String, CaseIterable {
    case equation       // full equation: left = right
    case side           // left or right side of equation
    case expression     // ordered list of terms (e.g., x^2 + 3x)
    case term           // signed value/unit (e.g., +4, -x)
    case value          // leaf: number, variable, or constant
    case fraction       // numerator / denominator
    case power          // base ^ exponent
    case root           // sqrt(expr)
    case nthRoot        // root(n, expr)
    case function       // sin(x), ln(x), etc.
    case integral       // int expr dx or int_a^b expr dx
    case derivative     // d/dx(expr)
    case limit          // lim_x->a expr
    case group          // parenthesized expression
}

// MARK: - MathNode

/// A node in the mathematical expression AST.
///
/// Every parsed expression becomes a tree of `MathNode` objects.
/// Each node knows its type, children, parent, and how to describe itself for speech.
class MathNode {
    /// Unique identifier for this node.
    let id: String

    /// The structural type of this node.
    let type: NodeType

    /// The literal text value (for leaf nodes like numbers, variables).
    /// For structural nodes, this may be empty or hold the operator/function name.
    var value: String

    /// Ordered children. Order is deterministic per type (see `childLabels`).
    var children: [MathNode]

    /// Back-reference to parent. Weak to avoid retain cycles.
    weak var parent: MathNode?

    /// 1-based position among siblings. Set during tree construction.
    var indexInParent: Int

    /// Human-readable speakable label (e.g., "x squared", "fraction").
    var label: String

    // MARK: - Init

    init(
        type: NodeType,
        value: String = "",
        children: [MathNode] = [],
        label: String = ""
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.value = value
        self.children = children
        self.parent = nil
        self.indexInParent = 0
        self.label = label

        // Set parent references and indexes
        for (i, child) in children.enumerated() {
            child.parent = self
            child.indexInParent = i + 1  // 1-based
        }
    }

    // MARK: - Computed Properties

    /// Whether this node can be expanded to show children in recall mode.
    var isExpandable: Bool {
        switch type {
        case .fraction, .power, .root, .nthRoot, .function,
             .integral, .derivative, .limit, .group, .expression:
            return children.count > 0
        case .equation, .side, .term, .value:
            return false
        }
    }

    /// Descriptive labels for each child position, based on node type.
    /// Used for speech feedback when entering a local context.
    var childLabels: [String] {
        switch type {
        case .fraction:
            return ["numerator", "denominator"]
        case .power:
            return ["base", "exponent"]
        case .root:
            return ["radicand"]
        case .nthRoot:
            return ["index", "radicand"]
        case .function:
            return ["argument"]
        case .integral:
            if children.count == 4 {
                return ["lower bound", "upper bound", "integrand", "variable"]
            } else {
                return ["integrand", "variable"]
            }
        case .derivative:
            return ["variable", "expression"]
        case .limit:
            return ["variable", "approach value", "expression"]
        case .group, .expression:
            return children.enumerated().map { "item \($0.offset + 1)" }
        default:
            return []
        }
    }

    /// A short structural summary for speech (e.g., "Fraction. 2 items.").
    var structureSummary: String {
        let typeName: String
        switch type {
        case .fraction: typeName = "Fraction"
        case .power: typeName = "Power"
        case .root: typeName = "Square root"
        case .nthRoot: typeName = "Nth root"
        case .function: typeName = "Function \(value)"
        case .integral:
            typeName = children.count == 4 ? "Definite integral" : "Indefinite integral"
        case .derivative: typeName = "Derivative"
        case .limit: typeName = "Limit"
        case .group: typeName = "Group"
        case .expression: typeName = "Expression"
        default: return label
        }
        return "\(typeName). \(children.count) \(children.count == 1 ? "item" : "items")."
    }
}

// MARK: - Debug / Description

extension MathNode: CustomStringConvertible {
    var description: String {
        return describeTree(indent: 0)
    }

    private func describeTree(indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = "\(prefix)[\(type.rawValue)] \(value) (label: \"\(label)\")\n"
        for child in children {
            result += child.describeTree(indent: indent + 1)
        }
        return result
    }
}

// MARK: - Tree Utilities

extension MathNode {
    /// Find a node by ID in this subtree.
    func find(byId targetId: String) -> MathNode? {
        if id == targetId { return self }
        for child in children {
            if let found = child.find(byId: targetId) {
                return found
            }
        }
        return nil
    }

    /// Returns the path from root to this node as an array of 1-based indexes.
    func pathFromRoot() -> [Int] {
        var path: [Int] = []
        var current: MathNode? = self
        while let node = current, node.parent != nil {
            path.append(node.indexInParent)
            current = node.parent
        }
        return path.reversed()
    }

    /// Rebuild parent references and indexes (call after manual tree edits).
    func rebuildReferences() {
        for (i, child) in children.enumerated() {
            child.parent = self
            child.indexInParent = i + 1
            child.rebuildReferences()
        }
    }
}
