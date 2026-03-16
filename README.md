# SymbolicStateRecall

A macOS accessibility tool that allows blind and visually impaired users to navigate, query, and insert parts of mathematical expressions using a tree-based recall system. Works alongside VoiceOver and existing text editors.

## Current Status

**Phase 1 (Core) — Complete**

| Component | Status | Tests |
|-----------|--------|-------|
| MathNode model | ✅ | - |
| Tokenizer | ✅ | 5/5 |
| Parser | ✅ | 15/15 |
| Navigation Engine | ✅ | 6/6 |
| Serializer | ✅ | 4/4 |

**Total: 30/30 tests passing**

## Supported Math Structures (v1: Calculus)

- Equations: `x^2 + 1 = 5`
- Fractions: `(x+3)/2`
- Powers: `x^2`, `e^(2t)`
- Square roots: `sqrt(x+1)`
- Nth roots: `root(3, x)`
- Definite integrals: `int_0^1 x^2 dx`
- Indefinite integrals: `int x^2 dx`
- Derivatives: `d/dx(x^2+3x)`
- Limits: `lim_x->0 sin(x)/x`
- Functions: `sin(x)`, `ln(y^3)`, `cos(x)`, `tan(x)`, `log(x)`

## Building

### Requirements
- macOS 15.2+
- Xcode 16.2+

### Build the App
```bash
xcodebuild build -scheme symbolicStateRecall -destination 'platform=macOS'
```

### Run Tests
```bash
xcodebuild test -scheme symbolicStateRecall -destination 'platform=macOS' \
  -only-testing:symbolicStateRecallTests/TokenizerTests \
  -only-testing:symbolicStateRecallTests/ParserTests \
  -only-testing:symbolicStateRecallTests/NavigationTests \
  -only-testing:symbolicStateRecallTests/SerializerTests
```

> **Note**: Run with explicit test class specifiers to avoid UI test hangs.

## CLI Test Harness

For interactive testing without the full app:

```bash
# Compile the CLI
swiftc -o cli_harness \
  symbolicStateRecall/Core/Parser/Token.swift \
  symbolicStateRecall/Core/Parser/Tokenizer.swift \
  symbolicStateRecall/Core/Parser/MathNode.swift \
  symbolicStateRecall/Core/Parser/Parser.swift \
  symbolicStateRecall/Core/Navigation/NavigationEngine.swift \
  symbolicStateRecall/Core/Speech/SpeechController.swift \
  symbolicStateRecall/Utilities/MathSerializer.swift \
  CLITestHarness.swift \
  main.swift

# Run it
./cli_harness
```

### CLI Commands

| Command | Action |
|---------|--------|
| `parse <equation>` | Parse an equation and show the AST |
| `recall` | Enter recall mode (simulates Option+Space) |
| `1`, `2`, etc. | Input index token |
| `L` / `R` | Select left/right side |
| `space` | Insert selected node |
| `back` | Go back one level |
| `exit` | Exit recall mode |
| `tree` | Show current AST |
| `index` | Show top-level index |
| `state` | Show current engine state |
| `quit` | Exit program |

### Example Session

```
> parse x^2 + 3x + 5 = 20
✅ Parsed successfully!

> recall
🔊 "Recall mode. Line 1: 3 items on left, 1 item on right"

> 1
🔊 "Line 1"

> L
🔊 "Left side, 3 items"

> 1
🔊 "x squared" (power node selected)

> 2
🔊 "exponent: 2"

> space
📋 Inserted text: "2"
```

## Project Structure

```
symbolic-state-recall/
├── symbolicStateRecall/
│   ├── Core/
│   │   ├── Input/
│   │   │   ├── ClipboardMonitor.swift   # Clipboard monitoring + text insertion
│   │   │   └── HotkeyManager.swift      # Global Option+Space hotkey (Carbon)
│   │   ├── Navigation/
│   │   │   └── NavigationEngine.swift   # Recall mode controller + query resolution
│   │   ├── Parser/
│   │   │   ├── MathNode.swift           # AST node model
│   │   │   ├── Parser.swift             # Tokens → AST
│   │   │   ├── Token.swift              # Token types
│   │   │   └── Tokenizer.swift          # Plain text → tokens
│   │   └── Speech/
│   │       └── SpeechController.swift   # VoiceOver announcements
│   ├── Utilities/
│   │   └── MathSerializer.swift         # Node → insertable text
│   ├── ContentView.swift
│   └── symbolicStateRecallApp.swift
├── symbolicStateRecallTests/
│   └── symbolicStateRecallTests.swift   # All unit tests
├── CLITestHarness.swift                 # Interactive CLI for testing
├── main.swift                           # CLI entry point
└── ARCHITECTURE.md                      # Detailed design document
```

## How It Works

1. **Parse**: User copies a math equation, the parser tokenizes it and builds an AST
2. **Recall**: User presses Option+Space to enter recall mode
3. **Query**: User types a path like `1 L 2` (Line 1, Left side, item 2)
4. **Navigate**: Each token provides spoken feedback; expandable nodes can be drilled into
5. **Insert**: Space inserts the selected node's text at cursor; Escape exits recall mode

See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete design specification.

---

## Next Steps (TODO)

### Phase 2: macOS Integration (In Progress)

- [ ] **Integrate Core with SwiftUI ContentView**
  - Connect NavigationEngine to UI
  - Display current equation and selection state
  - Handle keyboard input in the app

- [ ] **Test VoiceOver integration**
  - Verify SpeechController announcements work with VoiceOver
  - Test with screen reader enabled
  - Ensure proper accessibility labels

- [ ] **Add accessibility permissions handling**
  - Request Accessibility API permissions on first launch
  - Handle permission denied gracefully
  - Guide user through System Preferences if needed

- [ ] **Wire up HotkeyManager**
  - Register Option+Space globally when app launches
  - Handle hotkey conflicts with other apps

- [ ] **Wire up ClipboardMonitor**
  - Monitor clipboard for math text changes
  - Auto-parse when new math content detected

### Phase 3: Polish

- [ ] Comprehensive error handling (see ARCHITECTURE.md error table)
- [ ] Stale reference detection after edits
- [ ] Timeout handling for unresponsive states
- [ ] VoiceOver conflict mitigation
- [ ] Menu bar app mode (optional)

### Future (v2)

- Matrices and systems of equations
- Piecewise functions
- Summation/product notation
- Logical quantifiers
- Direct Accessibility API integration (read from any app)

---

## License

MIT
