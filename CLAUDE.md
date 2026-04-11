# SymbolicStateRecall

## Project Overview

SymbolicStateRecall (SSR) is a macOS accessibility tool that enables blind and visually impaired users to navigate, query, and insert parts of mathematical expressions using a tree-based recall system. It parses plain-text math (calculus scope: equations, fractions, powers, roots, integrals, derivatives, limits, trig/log functions) into an AST, then lets the user drill into it with a numeric/L/R query grammar while receiving VoiceOver speech feedback at each step. The app runs as a borderless floating dock bar (always-on-top, all Spaces) and reads math from the clipboard, focused text element (via Accessibility API), or embedded prose.

## Stack / Tech

- **Language**: Swift (no SwiftUI previews in use; SwiftUI for UI, AppKit/Carbon for system integration)
- **UI framework**: SwiftUI hosted in a borderless `NSPanel` (FloatingPanel)
- **System APIs**: Carbon (global hotkey), CGEvent taps (cross-app key interception), AXUIElement (screen reader / focused text), NSPasteboard (clipboard monitoring + text insertion)
- **Build system**: Xcode 16.2+ / xcodebuild
- **Platform**: macOS 15.2+
- **Testing**: XCTest (unit tests only; UI tests exist but are not used)
- **No external dependencies** — pure Apple frameworks

## Repo Structure

```
symbolic-state-recall/
├── ARCHITECTURE.md                     # Detailed design doc
├── CLAUDE_SESSION_NOTES.md             # Session notes / changelog
├── CLITestHarness.swift                # Interactive CLI for testing (not part of app target)
├── main.swift                          # CLI entry point
├── symbolicStateRecall.xcodeproj/
├── symbolicStateRecall/
│   ├── symbolicStateRecallApp.swift    # @main — delegates to AppCoordinator
│   ├── AppCoordinator.swift            # Central coordinator: engine, speech, hotkey, clipboard, UI state
│   ├── ContentView.swift               # Floating dock bar UI
│   ├── Core/
│   │   ├── Input/                      # ClipboardMonitor, FocusedTextReader, HotkeyManager
│   │   ├── Navigation/                 # NavigationEngine (state machine, query resolution)
│   │   ├── Parser/                     # Token, Tokenizer, Parser, MathNode, MathExtractor
│   │   └── Speech/                     # SpeechController (VoiceOver announcements)
│   ├── UI/
│   │   └── FloatingPanel.swift         # Borderless NSPanel subclass
│   └── Utilities/                      # MathSerializer, AccessibilityPermission
├── symbolicStateRecallTests/           # Unit tests (30 passing)
└── website/                            # Landing page iterations (HTML/JS)
```

## Current Status

### Phase 1: Core — Complete
All core components built and tested (30/30 unit tests passing).

### Phase 2: macOS Integration — Complete
Global hotkey, clipboard monitoring, focused text reading, prose extraction, floating dock bar UI, CGEvent tap, accessibility permission handling.

### Phase 3: Polish — In Progress (branch: `feature/ui-floating-panel`)
Remaining: error handling, stale reference detection, timeout handling, VoiceOver conflict mitigation.

## Build and Run Commands

```bash
# Build
xcodebuild build -scheme symbolicStateRecall -destination 'platform=macOS'

# Run unit tests (MUST use explicit test class specifiers)
xcodebuild test -scheme symbolicStateRecall -destination 'platform=macOS' \
  -only-testing:symbolicStateRecallTests/TokenizerTests \
  -only-testing:symbolicStateRecallTests/ParserTests \
  -only-testing:symbolicStateRecallTests/NavigationTests \
  -only-testing:symbolicStateRecallTests/SerializerTests

# Launch from DerivedData
open $(find ~/Library/Developer/Xcode/DerivedData/symbolicStateRecall-*/Build/Products/Debug/symbolicStateRecall.app 2>/dev/null | head -1)
```

## Non-negotiables

- **Never run `xcodebuild test` without `-only-testing` specifiers.** The full suite (including UI tests) hangs indefinitely.
- **Launch the built app from DerivedData** — do not ask the user to press Cmd+R in Xcode.
- **MathNode uses class semantics** with weak parent references. RecallContext is also a class. Do not convert to structs.
- **Accessibility permission is required** for global hotkey, CGEvent tap, and focused text reading. App must work gracefully without it.
- **CLI files at repo root** (`CLITestHarness.swift`, `main.swift`) are standalone — do not add to the app target.
- **VoiceOver speech uses `NSAccessibility` posting** — do not use NSSpeechSynthesizer or AVSpeechSynthesizer.
- **4pt spacing grid** for UI (spaceXS=4, spaceSM=8, spaceMD=12, spaceLG=16). Dock bar uses `.ultraThinMaterial` with black-tinted backgrounds.
- **API keys**: use `PROVIDER_API_KEY_PROJECT` naming. Store in `~/.secrets/`.
