// MathExtractor.swift
// SymbolicStateRecall
//
// Extracts math expressions from prose text. Splits text into candidate
// fragments, scores them for math likelihood, and tries parsing the best
// candidates. Used when reading full paragraphs from focused text elements.

import Foundation

struct MathExtractor {

    private static let mathKeywords: Set<String> = [
        "int", "sqrt", "root", "lim", "sin", "cos", "tan", "log", "ln",
        "exp", "abs", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh",
        "cot", "sec", "csc"
    ]

    /// Prose words that are definitely not math — used to detect natural language.
    private static let proseWords: Set<String> = [
        "the", "is", "are", "was", "were", "a", "an", "and", "or", "but",
        "for", "in", "on", "at", "to", "of", "it", "this", "that", "with",
        "from", "by", "as", "be", "has", "have", "had", "do", "does", "did",
        "will", "would", "could", "should", "can", "may", "might", "shall",
        "not", "no", "if", "then", "else", "when", "where", "which", "who",
        "what", "how", "so", "because", "since", "while", "also", "just",
        "very", "all", "each", "every", "some", "any", "more", "most",
        "other", "into", "over", "such", "than", "too", "only", "about",
        "up", "out", "its", "our", "your", "their", "we", "you", "they",
        "he", "she", "his", "her", "my", "me", "us", "them", "here",
        "there", "now", "find", "solve", "given", "let", "consider",
        "determine", "calculate", "evaluate", "simplify", "prove", "show"
    ]

    // MARK: - Public API

    /// Returns true if the text looks like prose rather than a standalone equation.
    static func isProse(_ text: String) -> Bool {
        let words = text.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard words.count > 3 else { return false }

        let proseCount = words.filter { proseWords.contains($0) }.count
        return Double(proseCount) / Double(words.count) > 0.3
    }

    /// Extract math expressions from prose text.
    /// Returns an array of parsed math strings, best candidates first.
    static func extractMath(from text: String) -> [String] {
        let candidates = generateCandidates(from: text)
        let scored = candidates
            .map { (candidate: $0, score: mathScore($0)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }

        var results: [String] = []
        let parser = Parser()

        for item in scored {
            let cleaned = item.candidate.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { continue }
            guard isMeaningfulMath(cleaned) else { continue }
            if (try? parser.parse(cleaned)) != nil {
                results.append(cleaned)
            }
        }

        return results
    }

    // MARK: - Candidate Generation

    /// Split text into candidate substrings that might contain math.
    private static func generateCandidates(from text: String) -> [String] {
        var candidates: [String] = []

        // Strategy 1: Split on sentence-like boundaries
        let sentenceSplitters = CharacterSet(charactersIn: ".;:")
        let sentences = text.components(separatedBy: sentenceSplitters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        candidates.append(contentsOf: sentences)

        // Strategy 2: Split on commas (but rejoin if both sides look mathy)
        for sentence in sentences {
            let commaParts = sentence.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if commaParts.count > 1 {
                candidates.append(contentsOf: commaParts)
            }
        }

        // Strategy 3: Extract substrings around = signs
        candidates.append(contentsOf: extractAroundEquals(text))

        // Strategy 4: Strip leading/trailing prose words from each candidate
        let stripped = candidates.compactMap { stripProse($0) }
        candidates.append(contentsOf: stripped)

        // Deduplicate while preserving order
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    /// Find substrings centered on = signs, expanding outward to capture
    /// the full expression on both sides.
    private static func extractAroundEquals(_ text: String) -> [String] {
        let chars = Array(text)
        var results: [String] = []

        for (i, ch) in chars.enumerated() where ch == "=" {
            // Expand left
            var left = i - 1
            while left >= 0 && isMathChar(chars[left]) {
                left -= 1
            }
            left += 1

            // Expand right
            var right = i + 1
            while right < chars.count && isMathChar(chars[right]) {
                right += 1
            }
            right -= 1

            if left < i && right > i {
                let substring = String(chars[left...right])
                    .trimmingCharacters(in: .whitespaces)
                if !substring.isEmpty {
                    results.append(substring)
                }
            }
        }

        return results
    }

    /// Check if a character could be part of a math expression.
    private static func isMathChar(_ ch: Character) -> Bool {
        if ch.isLetter || ch.isNumber { return true }
        if ch.isWhitespace { return true }
        let mathSymbols: Set<Character> = [
            "+", "-", "*", "/", "^", "=", "(", ")", "_", ",", ".", " "
        ]
        return mathSymbols.contains(ch)
    }

    /// Strip leading and trailing prose words from a candidate.
    private static func stripProse(_ text: String) -> String? {
        let words = text.components(separatedBy: .whitespaces)
        guard words.count > 1 else { return nil }

        // Find first non-prose word
        var start = 0
        while start < words.count && proseWords.contains(words[start].lowercased()) {
            start += 1
        }

        // Find last non-prose word
        var end = words.count - 1
        while end > start && proseWords.contains(words[end].lowercased()
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)) {
            end -= 1
        }

        guard start <= end else { return nil }
        let stripped = words[start...end].joined(separator: " ")
        return stripped != text ? stripped : nil
    }

    // MARK: - Validation

    /// A candidate must be meaningful math — not just a single word or letter
    /// that happens to parse as a variable. Requires at least one operator,
    /// equals sign, or math keyword.
    static func isMeaningfulMath(_ text: String) -> Bool {
        let mathOperators: Set<Character> = ["+", "-", "*", "/", "^", "="]
        let hasMathOperator = text.contains(where: { mathOperators.contains($0) })
        if hasMathOperator { return true }

        // Check for math keywords (sqrt, int, lim, sin, etc.)
        let lower = text.lowercased()
        for keyword in mathKeywords {
            if lower.contains(keyword) { return true }
        }

        // Check for parenthesized expression like f(x)
        if text.contains("(") && text.contains(")") { return true }

        // A bare number or single variable is not meaningful enough
        return false
    }

    // MARK: - Scoring

    /// Score how likely a string is to be a math expression.
    /// Higher score = more likely math.
    private static func mathScore(_ text: String) -> Int {
        var score = 0
        let lower = text.lowercased()
        let chars = Array(text)

        // Equals sign is a strong signal
        if text.contains("=") { score += 5 }

        // Math operators
        if text.contains("^") { score += 3 }
        if text.contains("/") { score += 1 }

        // Parenthesized groups
        let parenCount = chars.filter { $0 == "(" }.count
        score += parenCount * 2

        // Math keywords
        let words = lower.components(separatedBy: .whitespaces)
        for word in words {
            if mathKeywords.contains(word) { score += 3 }
        }

        // Digit-letter adjacency (like "3x", "x2")
        for i in 0..<(chars.count - 1) {
            if (chars[i].isNumber && chars[i+1].isLetter) ||
               (chars[i].isLetter && chars[i+1].isNumber) {
                score += 2
            }
        }

        // Single-letter tokens (common in math: x, y, a, b)
        let singleLetterVars = words.filter { $0.count == 1 && $0.first?.isLetter == true }
        score += singleLetterVars.count

        // Penalize prose words
        let proseCount = words.filter { proseWords.contains($0) }.count
        score -= proseCount * 2

        // Penalize very long text (likely a paragraph, not an equation)
        if text.count > 200 { score -= 5 }

        return score
    }
}
