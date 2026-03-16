// Tokenizer.swift
// SymbolicStateRecall
//
// Converts plain text mathematical expressions into a stream of tokens.
// Handles keywords (int, sqrt, lim, etc.), differentials (dx, dy),
// and standard math operators.

import Foundation

// MARK: - Tokenizer Errors

enum TokenizerError: Error, CustomStringConvertible {
    case unexpectedCharacter(Character, Int)
    case invalidInput(String)

    var description: String {
        switch self {
        case .unexpectedCharacter(let ch, let pos):
            return "Unexpected character '\(ch)' at position \(pos)"
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        }
    }
}

// MARK: - Tokenizer

class Tokenizer {

    /// Known function names.
    static let functionNames: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc",
        "arcsin", "arccos", "arctan",
        "sinh", "cosh", "tanh",
        "ln", "log", "exp", "abs"
    ]

    /// Keywords that are NOT function names.
    static let keywords: Set<String> = ["int", "sqrt", "root", "lim"]

    private let input: [Character]
    private var position: Int = 0

    init(input: String) {
        self.input = Array(input)
    }

    // MARK: - Public

    /// Tokenize the entire input string.
    func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        position = 0

        while position < input.count {
            skipWhitespace()
            guard position < input.count else { break }

            let ch = input[position]
            let startPos = position

            switch ch {
            case "+":
                tokens.append(Token(type: .plus, text: "+", position: startPos))
                position += 1

            case "-":
                // Check for -> (arrow)
                if position + 1 < input.count && input[position + 1] == ">" {
                    tokens.append(Token(type: .arrow, text: "->", position: startPos))
                    position += 2
                } else {
                    tokens.append(Token(type: .minus, text: "-", position: startPos))
                    position += 1
                }

            case "*":
                tokens.append(Token(type: .multiply, text: "*", position: startPos))
                position += 1

            case "/":
                tokens.append(Token(type: .divide, text: "/", position: startPos))
                position += 1

            case "^":
                tokens.append(Token(type: .power, text: "^", position: startPos))
                position += 1

            case "=":
                tokens.append(Token(type: .equals, text: "=", position: startPos))
                position += 1

            case "(":
                tokens.append(Token(type: .leftParen, text: "(", position: startPos))
                position += 1

            case ")":
                tokens.append(Token(type: .rightParen, text: ")", position: startPos))
                position += 1

            case "_":
                tokens.append(Token(type: .underscore, text: "_", position: startPos))
                position += 1

            case ",":
                tokens.append(Token(type: .comma, text: ",", position: startPos))
                position += 1

            default:
                if ch.isNumber || ch == "." {
                    tokens.append(readNumber(startPos: startPos))
                } else if ch.isLetter {
                    let wordToken = try readWord(startPos: startPos, previousTokens: tokens)
                    if let wt = wordToken {
                        // readWord may return multiple tokens (e.g., differential)
                        tokens.append(wt)
                    }
                } else {
                    throw TokenizerError.unexpectedCharacter(ch, startPos)
                }
            }
        }

        tokens.append(Token(type: .eof, text: "", position: position))
        return tokens
    }

    // MARK: - Private Helpers

    private func skipWhitespace() {
        while position < input.count && input[position].isWhitespace {
            position += 1
        }
    }

    private func readNumber(startPos: Int) -> Token {
        var numStr = ""
        var hasDot = false

        while position < input.count {
            let ch = input[position]
            if ch.isNumber {
                numStr.append(ch)
                position += 1
            } else if ch == "." && !hasDot {
                hasDot = true
                numStr.append(ch)
                position += 1
            } else {
                break
            }
        }

        return Token(type: .number, text: numStr, position: startPos)
    }

    /// Read a word (letters) and classify it as keyword, function, differential, or variable.
    private func readWord(startPos: Int, previousTokens: [Token]) throws -> Token? {
        var word = ""
        let wordStart = position

        while position < input.count && input[position].isLetter {
            word.append(input[position])
            position += 1
        }

        // Check for differential: "dx", "dy", "dt" etc.
        // A differential is "d" followed by a single letter, BUT only when:
        // - it appears after an expression (not at the start)
        // - and it's not "d/" which starts a derivative
        if word.count == 2 && word.hasPrefix("d") {
            let varPart = String(word.dropFirst())
            // Heuristic: if previous token is a variable, number, right paren,
            // this is likely a differential
            if let prev = previousTokens.last {
                switch prev.type {
                case .number, .variable, .rightParen:
                    return Token(type: .differential(varPart), text: word, position: startPos)
                default:
                    break
                }
            }
        }

        // Check keywords
        switch word {
        case "int":
            return Token(type: .intKeyword, text: word, position: startPos)
        case "sqrt":
            return Token(type: .sqrtKeyword, text: word, position: startPos)
        case "root":
            return Token(type: .rootKeyword, text: word, position: startPos)
        case "lim":
            return Token(type: .limKeyword, text: word, position: startPos)
        case "d":
            // Standalone "d" — likely start of d/dx
            return Token(type: .dKeyword, text: word, position: startPos)
        default:
            break
        }

        // Check function names
        if Tokenizer.functionNames.contains(word) {
            return Token(type: .funcName(word), text: word, position: startPos)
        }

        // Multi-character non-keyword: split into individual variables
        // e.g., "xy" → variable "x", then rewind to handle "y" next
        if word.count > 1 {
            // Special case: "d" followed by letters should be dKeyword
            // This handles "dx" in "d/dx" being split correctly
            if word.first == "d" {
                position = wordStart + 1
                return Token(type: .dKeyword, text: "d", position: startPos)
            }
            // Return first character as variable, rewind rest
            position = wordStart + 1
            return Token(type: .variable, text: String(word.first!), position: startPos)
        }

        // Single letter variable
        return Token(type: .variable, text: word, position: startPos)
    }
}
