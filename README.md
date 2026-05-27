# Math Recall

A macOS accessibility tool that lets blind and visually impaired users navigate, query, and read parts of mathematical expressions out loud. Runs as a floating dock bar alongside VoiceOver and any text editor.

Internal/repo name: **SymbolicStateRecall (SSR)**. Product name: **Math Recall**.

## Why this exists

Reading math through a screen reader is brutal. A sighted reader can glance back at `int_0^1 x^2 dx` and instantly re-parse the bounds; a VoiceOver user gets a linear blast of speech and has to hold the whole structure in working memory. Math Recall builds a tree from the equation and lets the user drill into any piece on demand: "left side, item 2, exponent." Each step is announced through VoiceOver.

The project is also a case study in designing thoughtfully with AI: deterministic parsing where determinism matters, heuristics where structure breaks down, and careful edge-case coverage for a small but specific audience.

## What it does

1. **Reads math from anywhere** — clipboard, focused text field (Accessibility API), or prose embedded in a paragraph (heuristic extractor, no LLM).
2. **Parses it** into an AST of equations, fractions, powers, roots, integrals, derivatives, limits, and trig/log functions.
3. **Speaks the structure** through VoiceOver: "Line 1: 3 items on left, 1 item on right."
4. **Navigates by query** — `1 L 2` means "Line 1, Left side, item 2." Multi-digit input is supported for equations with 10+ items.
5. **Inserts the selected node's text** at the cursor in any app.

## Supported math (v1: Calculus)

Equations, fractions, powers, square roots, nth roots, definite and indefinite integrals, derivatives, limits, and named functions (`sin`, `cos`, `tan`, `ln`, `log`, etc.).

Deferred to v2: matrices, piecewise functions, systems of equations, summation/product notation, logical quantifiers.

## Status

| Phase | What | State |
|-------|------|-------|
| 1 | Core parser, navigation engine, serializer (30 unit tests) | Complete |
| 2 | Global hotkey, clipboard monitoring, focused text reading, prose extraction, floating dock bar, CGEvent tap, accessibility permissions | Complete |
| 3 | Cursor-aware reading, recall history, multi-digit input, tolerant multi-line parsing, UI polish | In progress (`feature/ui-floating-panel`) |

Phase 2 and 3 work lives on the `feature/ui-floating-panel` branch and has not been merged to main yet.

## Building

**Requirements:** macOS 15.2+, Xcode 16.2+

```bash
# Build
xcodebuild build -scheme symbolicStateRecall -destination 'platform=macOS'

# Run unit tests (must use explicit test class specifiers — the full suite hangs on UI tests)
xcodebuild test -scheme symbolicStateRecall -destination 'platform=macOS' \
  -only-testing:symbolicStateRecallTests/TokenizerTests \
  -only-testing:symbolicStateRecallTests/ParserTests \
  -only-testing:symbolicStateRecallTests/NavigationTests \
  -only-testing:symbolicStateRecallTests/SerializerTests

# Launch the built app
open $(find ~/Library/Developer/Xcode/DerivedData/symbolicStateRecall-*/Build/Products/Debug/symbolicStateRecall.app | head -1)
```

## CLI test harness

For interactive testing without launching the full app:

```bash
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

./cli_harness
```

| Command | Action |
|---------|--------|
| `parse <equation>` | Parse an equation and show the AST |
| `recall` | Enter recall mode (simulates Option+Space) |
| `1`, `2`, ... | Input index token |
| `L` / `R` | Select left/right side |
| `space` | Insert selected node |
| `back` | Go back one level |
| `tree` | Show current AST |
| `state` | Show current engine state |
| `quit` | Exit |

### Example session

```
> parse x^2 + 3x + 5 = 20
Parsed successfully

> recall
VoiceOver: "Recall mode. Line 1: 3 items on left, 1 item on right"

> 1
VoiceOver: "Line 1"

> L
VoiceOver: "Left side, 3 items"

> 1
VoiceOver: "x squared" (power node selected)

> 2
VoiceOver: "exponent: 2"

> space
Inserted text: "2"
```

## Architecture

```
Input Layer  ──▶  Parser  ──▶  Navigation Engine  ──▶  Speech Controller
(clipboard,      (tokenizer    (recall mode,           (VoiceOver
 focused          + parser,     query resolution,       announcements)
 text, prose)     MathExtractor)context stack)
                                     │
                                     ▼
                               Serializer
                               (node → text)
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design spec.

## Repo layout

```
symbolic-state-recall/
├── ARCHITECTURE.md
├── CLAUDE.md                          # Project instructions
├── CLITestHarness.swift               # Standalone CLI (not in app target)
├── main.swift                         # CLI entry
├── symbolicStateRecall.xcodeproj/
├── symbolicStateRecall/
│   ├── symbolicStateRecallApp.swift   # @main
│   ├── AppCoordinator.swift           # Wires engine, speech, hotkey, clipboard, UI
│   ├── ContentView.swift              # Floating dock bar
│   ├── Core/
│   │   ├── Input/                     # ClipboardMonitor, FocusedTextReader, HotkeyManager
│   │   ├── Navigation/                # NavigationEngine
│   │   ├── Parser/                    # Token, Tokenizer, Parser, MathNode, MathExtractor
│   │   └── Speech/                    # SpeechController
│   ├── UI/FloatingPanel.swift         # Borderless NSPanel subclass
│   └── Utilities/                     # MathSerializer, AccessibilityPermission
├── symbolicStateRecallTests/          # Unit tests
└── website/                           # Landing page iterations (Math Recall branding)
```

## Design notes

- **No external dependencies.** Pure Apple frameworks: SwiftUI, AppKit, Carbon (global hotkey), CGEvent taps (cross-app key interception), AXUIElement (screen reader / focused text), NSPasteboard.
- **VoiceOver speech uses `NSAccessibility` posting**, not `NSSpeechSynthesizer` or `AVSpeechSynthesizer`. This is the only way to interleave cleanly with VoiceOver's own speech queue.
- **Accessibility permission is required** for the global hotkey, CGEvent tap, and focused text reading. The app degrades gracefully without it.
- **`MathNode` is a class** with weak parent references, not a struct. The recall context relies on identity and back-pointers.

## License

MIT
