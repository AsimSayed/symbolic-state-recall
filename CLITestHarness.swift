// main.swift
// SymbolicStateRecall CLI Test Harness
//
// Run this to interactively test the parser and navigation engine.
// Type equations to parse them, then use recall commands to navigate.
//
// Commands:
//   parse <equation>     — Parse an equation and show the AST
//   recall               — Enter recall mode (simulates Option+Space)
//   <number>             — Input a line/index token
//   L or R               — Input a side token
//   space                — Insert selected node
//   back                 — Go back one level (simulates Backspace)
//   exit                 — Exit recall mode (simulates Escape)
//   tree                 — Show current AST
//   index                — Show top-level index
//   help                 — Show commands
//   quit                 — Exit program

import Foundation

// MARK: - Test Harness

class TestHarness: NavigationEngineDelegate {
    let engine = NavigationEngine()
    let speech = SpeechController()
    var currentRoot: MathNode?
    var currentIndex: TopLevelIndex?

    init() {
        engine.delegate = self
    }

    func navigationEngine(_ engine: NavigationEngine, didEmit event: NavigationEvent) {
        // Forward to speech controller
        speech.navigationEngine(engine, didEmit: event)
    }

    func run() {
        print("╔══════════════════════════════════════════╗")
        print("║   SymbolicStateRecall v1 — CLI Harness   ║")
        print("╠══════════════════════════════════════════╣")
        print("║ Type 'help' for commands                 ║")
        print("║ Type 'parse <equation>' to start         ║")
        print("╚══════════════════════════════════════════╝")
        print()

        // Demo: auto-parse the example from the design doc
        demoEquation()

        // Interactive loop
        while true {
            print("\n> ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
                break
            }

            if input.isEmpty { continue }

            processCommand(input)
        }
    }

    func demoEquation() {
        let demo = "int_0^1 (x^2 + 3x)/sqrt(x+1) dx + ln(y^3) = e^t"
        print("Demo equation: \(demo)")
        parseEquation(demo)
    }

    func processCommand(_ input: String) {
        let parts = input.components(separatedBy: " ")
        let command = parts[0].lowercased()

        switch command {
        case "parse":
            let equation = parts.dropFirst().joined(separator: " ")
            if equation.isEmpty {
                print("Usage: parse <equation>")
                print("Example: parse int_0^1 x^2 dx + ln(y^3) = e^t")
            } else {
                parseEquation(equation)
            }

        case "parsemulti", "pm":
            print("Enter equations (one per line). Type 'end' or empty line when done:")
            parseMultiLine()

        case "recall", "trigger":
            engine.trigger()

        case "l", "r":
            engine.input(token: command.uppercased())

        case "space", "insert":
            if let text = engine.insertSelected() {
                print("📋 Inserted text: \"\(text)\"")
            }

        case "back", "backspace":
            engine.goBack()

        case "exit", "esc":
            engine.exitRecall()

        case "tree":
            showTree()

        case "index":
            showIndex()

        case "state":
            showState()

        case "help":
            showHelp()

        case "quit", "q":
            print("Goodbye!")
            exit(0)

        default:
            // Try as a number (index token)
            if let _ = Int(command) {
                engine.input(token: command)
            } else {
                print("Unknown command: '\(command)'. Type 'help' for commands.")
            }
        }
    }

    func parseEquation(_ equation: String) {
        do {
            let parser = Parser()
            let (root, index) = try parser.parseAndIndex(equation)
            currentRoot = root
            currentIndex = index
            engine.load(root: root, index: index)

            print("\n✅ Parsed successfully!")
            print("\n--- AST ---")
            print(root)
            print("--- Top-Level Index ---")
            printIndex(index)
            print("\nType 'recall' to enter recall mode.")

        } catch {
            print("❌ Parse error: \(error)")
        }
    }

    func parseMultiLine() {
        var lines: [String] = []
        var lineNum = 1

        while true {
            print("  \(lineNum): ", terminator: "")
            guard let line = readLine() else { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.lowercased() == "end" {
                break
            }

            lines.append(trimmed)
            lineNum += 1
        }

        if lines.isEmpty {
            print("No equations entered.")
            return
        }

        do {
            let parser = Parser()
            let multiInput = lines.joined(separator: "\n")
            let (roots, index) = try parser.parseMultiLine(multiInput)

            currentRoot = roots.first
            currentIndex = index
            engine.load(roots: roots, index: index)

            print("\n✅ Parsed \(roots.count) equations successfully!")
            print("\n--- Top-Level Index ---")
            printIndex(index)
            print("\nType 'recall' to enter recall mode.")
            print("Query format: <line> <L/R> <index>")
            print("Example: 2 L 1 → Line 2, Left side, Item 1")

        } catch {
            print("❌ Parse error: \(error)")
        }
    }

    func showTree() {
        if let root = currentRoot {
            print("\n--- AST ---")
            print(root)
        } else {
            print("No equation loaded. Use 'parse <equation>' first.")
        }
    }

    func showIndex() {
        if let index = currentIndex {
            printIndex(index)
        } else {
            print("No equation loaded.")
        }
    }

    func showState() {
        print("State: \(engine.state)")
        if let node = engine.selectedNode {
            print("Selected: \(node.label) (\(node.type.rawValue))")
        }
        print("Path: \(engine.currentPath)")
    }

    func showHelp() {
        print("""

        ┌─ SymbolicStateRecall CLI Commands ─────────────────┐
        │                                                      │
        │  parse <eq>    Parse a single equation               │
        │  parsemulti    Parse multiple equations (multi-line) │
        │  recall        Enter recall mode (Option+Space)      │
        │  <number>      Input line or index token             │
        │  L / R         Select side                           │
        │  space         Insert selected node                  │
        │  back          Go back one level                     │
        │  exit          Exit recall mode                      │
        │  tree          Show current AST                      │
        │  index         Show top-level index                  │
        │  state         Show current engine state             │
        │  help          Show this help                        │
        │  quit          Exit program                          │
        │                                                      │
        │  Single-line example:                                │
        │  > parse x^2 + 3x + 5 = 20                          │
        │  > recall                                            │
        │  > 1 L 1       (Line 1, Left, Item 1)               │
        │                                                      │
        │  Multi-line example:                                 │
        │  > parsemulti                                        │
        │    1: x^2 + y^2 = r^2                               │
        │    2: a^2 + b^2 = c^2                               │
        │    3: end                                            │
        │  > recall                                            │
        │  > 2 L 1       (Line 2, Left, Item 1 → a^2)         │
        └──────────────────────────────────────────────────────┘
        """)
    }

    func printIndex(_ index: TopLevelIndex) {
        for line in index.lines {
            for side in index.sides(line: line) {
                let items = index.items(line: line, side: side)
                for (i, item) in items.enumerated() {
                    let sideName = side == "L" ? "Left" : "Right"
                    print("  \(line) \(side) \(i+1) → \(item.label) [\(item.type.rawValue)]")
                }
            }
        }
    }
}

// MARK: - Entry Point (for CLI testing)
//
// To run as CLI: Create a separate command-line target in Xcode
// and add this to its main.swift:
//
//   let harness = TestHarness()
//   harness.run()
//
