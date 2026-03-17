// Parser.swift
// SymbolicStateRecall
//
// Recursive descent parser that converts a token stream into an AST.
// Handles operator precedence, implicit multiplication, and all v1 structures.

import Foundation

// MARK: - Parser Errors

enum ParserError: Error, CustomStringConvertible {
    case unexpectedToken(Token, String)
    case unexpectedEndOfInput(String)
    case invalidExpression(String)

    var description: String {
        switch self {
        case .unexpectedToken(let token, let context):
            return "Unexpected \(token) in \(context)"
        case .unexpectedEndOfInput(let context):
            return "Unexpected end of input in \(context)"
        case .invalidExpression(let msg):
            return "Invalid expression: \(msg)"
        }
    }
}

// MARK: - Parser

/// Recursive descent parser for plain-text math expressions.
///
/// Grammar (simplified):
///   equation    → expression '=' expression
///   expression  → term (('+' | '-') term)*
///   term        → factor (('*' | implicit) factor)*
///   factor      → unary ('^' factor)?           // right-associative
///   unary       → '-' unary | atom
///   atom        → number | variable | group | function | integral | derivative | limit | sqrt | root
///   group       → '(' expression ')'
///
class Parser {

    private var tokens: [Token] = []
    private var pos: Int = 0

    // MARK: - Public API

    /// Parse a math string into an AST.
    /// Returns the root node (either an equation node or a single expression).
    func parse(_ input: String) throws -> MathNode {
        let tokenizer = Tokenizer(input: input)
        self.tokens = try tokenizer.tokenize()
        self.pos = 0

        let node = try parseEquation()
        generateLabels(for: node, originalInput: input)
        node.rebuildReferences()
        return node
    }

    // MARK: - Token Helpers

    private var current: Token {
        guard pos < tokens.count else {
            return Token(type: .eof, text: "", position: -1)
        }
        return tokens[pos]
    }

    private func peek(offset: Int = 0) -> Token {
        let idx = pos + offset
        guard idx < tokens.count else {
            return Token(type: .eof, text: "", position: -1)
        }
        return tokens[idx]
    }

    @discardableResult
    private func advance() -> Token {
        let token = current
        pos += 1
        return token
    }

    private func expect(_ type: TokenType, context: String) throws -> Token {
        if current.type == type {
            return advance()
        }
        throw ParserError.unexpectedToken(current, context)
    }

    private func match(_ type: TokenType) -> Bool {
        if current.type == type {
            advance()
            return true
        }
        return false
    }

    // MARK: - Grammar Rules

    /// equation → expression ('=' expression)?
    private func parseEquation() throws -> MathNode {
        let left = try parseExpression()

        if current.type == .equals {
            advance()
            let right = try parseExpression()

            let leftSide = MathNode(type: .side, value: "L", children: flattenTopLevel(left))
            leftSide.label = "left side"

            let rightSide = MathNode(type: .side, value: "R", children: flattenTopLevel(right))
            rightSide.label = "right side"

            let equation = MathNode(type: .equation, value: "=", children: [leftSide, rightSide])
            equation.label = "equation"
            return equation
        }

        // No equals sign — wrap in a single side
        let side = MathNode(type: .side, value: "L", children: flattenTopLevel(left))
        side.label = "left side"
        return side
    }

    /// Flatten an expression into top-level recallable items.
    /// Splits at additive operators: `a + b - c` → [a, +b, -c]
    private func flattenTopLevel(_ node: MathNode) -> [MathNode] {
        if node.type == .expression {
            return node.children
        }
        return [node]
    }

    /// expression → term (('+' | '-') term)*
    private func parseExpression() throws -> MathNode {
        var left = try parseTerm()

        var terms: [MathNode] = [left]
        while current.type == .plus || current.type == .minus {
            let op = advance()
            let right = try parseTerm()

            // Wrap as a signed term
            let term = MathNode(type: .term, value: op.text, children: [right])
            term.label = "\(op.text == "+" ? "plus" : "minus") \(right.label)"
            terms.append(term)
        }

        if terms.count == 1 {
            return terms[0]
        }

        let expr = MathNode(type: .expression, children: terms)
        expr.label = terms.map { $0.label }.joined(separator: " ")
        return expr
    }

    /// term → division (('*' | implicit_multiply) division)*
    private func parseTerm() throws -> MathNode {
        var left = try parseDivision()

        while true {
            if current.type == .multiply {
                advance()
                let right = try parseDivision()
                // For implicit/explicit multiplication, combine into a single node
                let product = MathNode(type: .term, value: "*", children: [left, right])
                product.label = "\(left.label) times \(right.label)"
                left = product
            } else if isImplicitMultiply() {
                let right = try parseDivision()
                let product = MathNode(type: .term, value: "*", children: [left, right])
                product.label = "\(left.label) \(right.label)"
                left = product
            } else {
                break
            }
        }

        return left
    }

    /// Check if the next token implies multiplication.
    /// e.g., `3x`, `x(`, `)(`, `2sin(x)`
    private func isImplicitMultiply() -> Bool {
        let type = current.type
        switch type {
        case .number, .variable, .leftParen, .sqrtKeyword, .rootKeyword:
            return true
        case .funcName:
            return true
        default:
            return false
        }
    }

    /// division → factor ('/' factor)?
    /// Creates fraction nodes for division operations.
    private func parseDivision() throws -> MathNode {
        let left = try parseFactor()

        if current.type == .divide {
            advance()
            let right = try parseFactor()

            let fraction = MathNode(type: .fraction, children: [left, right])
            fraction.label = "\(left.label) over \(right.label)"
            return fraction
        }

        return left
    }

    /// factor → unary ('^' factor)?
    /// Power is right-associative: x^2^3 = x^(2^3)
    private func parseFactor() throws -> MathNode {
        let base = try parseUnary()

        if current.type == .power {
            advance()
            let exponent = try parseFactor()  // right-associative recursion

            let power = MathNode(type: .power, children: [base, exponent])
            power.label = "\(base.label) to the power \(exponent.label)"
            return power
        }

        return base
    }

    /// unary → '-' unary | atom
    private func parseUnary() throws -> MathNode {
        if current.type == .minus {
            advance()
            let operand = try parseUnary()
            let neg = MathNode(type: .term, value: "-", children: [operand])
            neg.label = "negative \(operand.label)"
            return neg
        }
        return try parseAtom()
    }

    /// atom → number | variable | group | function | integral | derivative | limit | sqrt | root
    private func parseAtom() throws -> MathNode {
        switch current.type {
        case .number:
            return parseNumber()

        case .variable:
            return parseVariable()

        case .leftParen:
            return try parseGroup()

        case .funcName(let name):
            return try parseFunction(name: name)

        case .intKeyword:
            return try parseIntegral()

        case .dKeyword:
            return try parseDerivative()

        case .limKeyword:
            return try parseLimit()

        case .sqrtKeyword:
            return try parseSqrt()

        case .rootKeyword:
            return try parseRoot()

        default:
            throw ParserError.unexpectedToken(current, "expected number, variable, or expression")
        }
    }

    // MARK: - Atom Parsers

    private func parseNumber() -> MathNode {
        let token = advance()
        let node = MathNode(type: .value, value: token.text)
        node.label = token.text
        return node
    }

    private func parseVariable() -> MathNode {
        let token = advance()
        let node = MathNode(type: .value, value: token.text)
        node.label = token.text
        return node
    }

    /// group → '(' expression ')'
    private func parseGroup() throws -> MathNode {
        try expect(.leftParen, context: "group")
        let inner = try parseExpression()
        try expect(.rightParen, context: "closing parenthesis")

        let group = MathNode(type: .group, children: flattenTopLevel(inner))
        group.label = inner.label
        return group
    }

    /// function → funcName '(' expression ')'
    private func parseFunction(name: String) throws -> MathNode {
        advance() // consume function name
        try expect(.leftParen, context: "function \(name) argument")
        let arg = try parseExpression()
        try expect(.rightParen, context: "function \(name) closing paren")

        let func_ = MathNode(type: .function, value: name, children: [arg])
        func_.label = "\(name) of \(arg.label)"
        return func_
    }

    /// integral → 'int' ('_' lower '^' upper)? expression differential
    private func parseIntegral() throws -> MathNode {
        advance() // consume 'int'

        var lower: MathNode?
        var upper: MathNode?

        // Check for bounds: _lower^upper
        if current.type == .underscore {
            advance()
            lower = try parseAtom()
            try expect(.power, context: "integral upper bound (expected ^)")
            upper = try parseAtom()
        }

        // Parse integrand
        let integrand = try parseExpression()

        // Expect differential: dx, dy, etc.
        var diffVar = "x" // default
        if case .differential(let v) = current.type {
            diffVar = v
            advance()
        }

        let varNode = MathNode(type: .value, value: diffVar)
        varNode.label = diffVar

        var children: [MathNode]
        if let lo = lower, let hi = upper {
            children = [lo, hi, integrand, varNode]
            let node = MathNode(type: .integral, children: children)
            node.label = "integral from \(lo.label) to \(hi.label) of \(integrand.label) d\(diffVar)"
            return node
        } else {
            children = [integrand, varNode]
            let node = MathNode(type: .integral, children: children)
            node.label = "integral of \(integrand.label) d\(diffVar)"
            return node
        }
    }

    /// derivative → 'd' '/' 'd' variable '(' expression ')'
    private func parseDerivative() throws -> MathNode {
        advance() // consume 'd'
        try expect(.divide, context: "derivative (expected /)")

        // Expect 'd' then variable: d/dx or d/dy
        // The tokenizer may produce "d" as dKeyword and then the variable separately,
        // or "dx" as a differential. We handle both.
        var diffVar: String
        if case .differential(let v) = current.type {
            diffVar = v
            advance()
        } else if current.type == .dKeyword {
            advance()
            if current.type == .variable {
                diffVar = advance().text
            } else {
                throw ParserError.unexpectedToken(current, "derivative variable")
            }
        } else {
            throw ParserError.unexpectedToken(current, "derivative (expected d<var>)")
        }

        // Parse the expression being differentiated
        try expect(.leftParen, context: "derivative expression")
        let expr = try parseExpression()
        try expect(.rightParen, context: "derivative closing paren")

        let varNode = MathNode(type: .value, value: diffVar)
        varNode.label = diffVar

        let node = MathNode(type: .derivative, children: [varNode, expr])
        node.label = "derivative with respect to \(diffVar) of \(expr.label)"
        return node
    }

    /// limit → 'lim' '_' variable '->' value expression
    private func parseLimit() throws -> MathNode {
        advance() // consume 'lim'
        try expect(.underscore, context: "limit (expected _)")

        let limVar = try parseAtom()
        try expect(.arrow, context: "limit (expected ->)")
        let approachVal = try parseAtom()

        let expr = try parseExpression()

        let node = MathNode(type: .limit, children: [limVar, approachVal, expr])
        node.label = "limit as \(limVar.label) approaches \(approachVal.label) of \(expr.label)"
        return node
    }

    /// sqrt → 'sqrt' '(' expression ')'
    private func parseSqrt() throws -> MathNode {
        advance() // consume 'sqrt'
        try expect(.leftParen, context: "sqrt argument")
        let inner = try parseExpression()
        try expect(.rightParen, context: "sqrt closing paren")

        let node = MathNode(type: .root, children: [inner])
        node.label = "square root of \(inner.label)"
        return node
    }

    /// root → 'root' '(' index ',' expression ')'
    private func parseRoot() throws -> MathNode {
        advance() // consume 'root'
        try expect(.leftParen, context: "root arguments")
        let index = try parseExpression()
        try expect(.comma, context: "root (expected comma between index and radicand)")
        let radicand = try parseExpression()
        try expect(.rightParen, context: "root closing paren")

        let node = MathNode(type: .nthRoot, children: [index, radicand])
        node.label = "\(index.label)th root of \(radicand.label)"
        return node
    }

    // MARK: - Label Generation

    /// Generate human-readable spoken labels for all nodes.
    /// Called after parsing is complete to refine labels.
    private func generateLabels(for node: MathNode, originalInput: String) {
        // Labels are set during parsing. This method can be extended
        // for more sophisticated speech generation.
        for child in node.children {
            generateLabels(for: child, originalInput: originalInput)
        }

        // Refine power labels
        if node.type == .power && node.children.count == 2 {
            let base = node.children[0]
            let exp = node.children[1]

            if exp.value == "2" {
                node.label = "\(base.label) squared"
            } else if exp.value == "3" {
                node.label = "\(base.label) cubed"
            } else {
                node.label = "\(base.label) to the power \(exp.label)"
            }
        }
    }
}

// MARK: - Convenience

extension Parser {
    /// Parse and return both the AST and the top-level index.
    func parseAndIndex(_ input: String) throws -> (root: MathNode, index: TopLevelIndex) {
        let root = try parse(input)
        let index = TopLevelIndex(root: root)
        return (root, index)
    }

    /// Parse multiple lines of equations.
    /// Each non-empty line becomes a separate equation indexed by line number.
    func parseMultiLine(_ input: String) throws -> (roots: [MathNode], index: TopLevelIndex) {
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var roots: [MathNode] = []
        for line in lines {
            let root = try parse(line)
            roots.append(root)
        }

        let index = TopLevelIndex(roots: roots)
        return (roots, index)
    }
}

// MARK: - Top-Level Index

/// Maps [line][side][position] → MathNode for quick recall access.
struct TopLevelIndex {
    /// Storage: lineIndex → ("L" or "R") → [MathNode]
    private var index: [Int: [String: [MathNode]]] = [:]

    /// Initialize with a single root (single-line mode).
    init(root: MathNode) {
        buildIndex(root: root, line: 1)
    }

    /// Initialize with multiple roots (multi-line mode).
    /// Each root is assigned a line number starting from 1.
    init(roots: [MathNode]) {
        for (i, root) in roots.enumerated() {
            buildIndex(root: root, line: i + 1)
        }
    }

    private mutating func buildIndex(root: MathNode, line: Int) {
        switch root.type {
        case .equation:
            // Has left and right sides
            for child in root.children {
                if child.type == .side {
                    let sideKey = child.value  // "L" or "R"
                    index[line, default: [:]][sideKey] = child.children
                }
            }
        case .side:
            // Single side (no equals sign)
            index[line, default: [:]][root.value] = root.children
        default:
            // Wrap in left side
            index[line, default: [:]][ "L"] = [root]
        }
    }

    /// Look up a node by line, side, and 1-based position.
    func resolve(line: Int, side: String, position: Int) -> MathNode? {
        guard let sides = index[line],
              let items = sides[side],
              position >= 1 && position <= items.count else {
            return nil
        }
        return items[position - 1]
    }

    /// Get all items on a given line and side.
    func items(line: Int, side: String) -> [MathNode] {
        return index[line]?[side] ?? []
    }

    /// Number of items on a given line and side.
    func count(line: Int, side: String) -> Int {
        return items(line: line, side: side).count
    }

    /// Available lines.
    var lines: [Int] {
        return index.keys.sorted()
    }

    /// Available sides for a line.
    func sides(line: Int) -> [String] {
        return (index[line]?.keys.sorted()) ?? []
    }

    /// Get the total number of lines.
    var lineCount: Int {
        return index.count
    }
}
