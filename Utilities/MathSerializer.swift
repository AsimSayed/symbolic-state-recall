// MathSerializer.swift
// MathRecall
//
// Converts MathNode AST nodes back into plain text math notation
// for insertion at the cursor.

import Foundation

class MathSerializer {

    /// Serialize a node back to its plain text representation.
    static func serialize(_ node: MathNode) -> String {
        switch node.type {
        case .value:
            return node.value

        case .term:
            if node.children.count == 1 {
                // Unary: -x or +x
                let child = serialize(node.children[0])
                return "\(node.value)\(child)"
            } else if node.children.count == 2 {
                // Binary: multiplication
                let left = serialize(node.children[0])
                let right = serialize(node.children[1])
                if node.value == "*" {
                    // Use implicit multiplication where possible
                    return "\(left)\(right)"
                }
                return "\(left) \(node.value) \(right)"
            }
            return node.value

        case .expression:
            return node.children.map { serialize($0) }.joined(separator: " ")

        case .fraction:
            let num = serialize(node.children[0])
            let den = serialize(node.children[1])
            let numStr = needsParens(node.children[0]) ? "(\(num))" : num
            let denStr = needsParens(node.children[1]) ? "(\(den))" : den
            return "\(numStr)/\(denStr)"

        case .power:
            let base = serialize(node.children[0])
            let exp = serialize(node.children[1])
            let baseStr = needsParens(node.children[0]) ? "(\(base))" : base
            let expStr = needsParensForExponent(node.children[1]) ? "(\(exp))" : exp
            return "\(baseStr)^\(expStr)"

        case .root:
            let radicand = serialize(node.children[0])
            return "sqrt(\(radicand))"

        case .nthRoot:
            let index = serialize(node.children[0])
            let radicand = serialize(node.children[1])
            return "root(\(index), \(radicand))"

        case .function:
            let arg = serialize(node.children[0])
            return "\(node.value)(\(arg))"

        case .integral:
            if node.children.count == 4 {
                // Definite: int_lo^hi integrand dvar
                let lo = serialize(node.children[0])
                let hi = serialize(node.children[1])
                let integrand = serialize(node.children[2])
                let variable = node.children[3].value
                return "int_\(lo)^\(hi) \(integrand) d\(variable)"
            } else {
                // Indefinite: int integrand dvar
                let integrand = serialize(node.children[0])
                let variable = node.children[1].value
                return "int \(integrand) d\(variable)"
            }

        case .derivative:
            let variable = node.children[0].value
            let expr = serialize(node.children[1])
            return "d/d\(variable)(\(expr))"

        case .limit:
            let variable = serialize(node.children[0])
            let approach = serialize(node.children[1])
            let expr = serialize(node.children[2])
            return "lim_\(variable)->\(approach) \(expr)"

        case .group:
            let inner = node.children.map { serialize($0) }.joined(separator: " ")
            return "(\(inner))"

        case .equation:
            let sides = node.children.map { serialize($0) }
            return sides.joined(separator: " = ")

        case .side:
            return node.children.map { serialize($0) }.joined(separator: " ")
        }
    }

    // MARK: - Parenthesization Helpers

    /// Whether a node needs parentheses when used as a fraction numerator/denominator.
    private static func needsParens(_ node: MathNode) -> Bool {
        switch node.type {
        case .expression, .term:
            return node.children.count > 1
        default:
            return false
        }
    }

    /// Whether a node needs parentheses when used as an exponent.
    private static func needsParensForExponent(_ node: MathNode) -> Bool {
        switch node.type {
        case .expression, .term, .fraction:
            return true
        case .value:
            return node.value.count > 1 && !CharacterSet.decimalDigits.isSuperset(
                of: CharacterSet(charactersIn: node.value)
            )
        default:
            return false
        }
    }
}
