// Token.swift
// MathRecall
//
// Token types produced by the Tokenizer.

import Foundation

// MARK: - Token Type

enum TokenType: Equatable {
    case number         // e.g., "3", "42", "3.14"
    case variable       // e.g., "x", "y", "t"
    case plus           // +
    case minus          // -
    case multiply       // *
    case divide         // /
    case power          // ^
    case equals         // =
    case leftParen      // (
    case rightParen     // )
    case underscore     // _ (subscript marker)
    case arrow          // -> (limit approach)
    case comma          // , (separator in root(n, expr))

    // Keywords
    case intKeyword     // int (integral)
    case sqrtKeyword    // sqrt
    case rootKeyword    // root
    case limKeyword     // lim
    case dKeyword       // d (for d/dx)
    case funcName(String) // sin, cos, tan, ln, log, etc.

    // Differential variable: dx, dy, dt, etc.
    case differential(String) // the variable part (e.g., "x" from "dx")

    case eof            // end of input
}

// MARK: - Token

struct Token: CustomStringConvertible {
    let type: TokenType
    let text: String       // original text
    let position: Int      // character position in input

    var description: String {
        return "Token(\(type), \"\(text)\", pos:\(position))"
    }
}
