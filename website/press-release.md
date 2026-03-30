---
title: "Math Recall: How One Researcher Used AI to Design Software for People It Can't See"
type: press-release
version: 1
date: 2026-03-29
---

# Math Recall: How One Researcher Used AI to Design Software for People It Can't See

**A macOS tool that lets blind students navigate calculus by feel — and a case study in what happens when you use AI to design with care, not speed.**

---

SEATTLE — March 2026

When a blind student encounters a math expression like `∫₀¹ x² dx` in a lecture, they face a problem most people never think about. Screen readers — the software that reads interfaces aloud — can parse menus, buttons, and paragraphs. But a nested mathematical expression? It becomes a wall of symbols read left to right, with no way to jump to the exponent, isolate the bounds of an integral, or pull out a fraction's denominator to insert it somewhere else.

Math Recall is a free, open-source macOS application that changes this. Built by Asim Sayed, a researcher at the University of Washington's Department of Human Centered Design & Engineering (HCDE), it gives blind and visually impaired users the ability to navigate complex math expressions as a tree — drilling into any part, hearing it spoken aloud, and inserting it into their work with a single keystroke.

But the tool itself isn't the whole story. How it was built is.

## Designing for Edge Cases as the Main Case

Most software treats accessibility as a compliance checkbox — a layer added after the product is "done." Math Recall inverts this. The entire system was designed around the needs of users who will never see the interface.

The result is an interaction model that looks nothing like a visual math editor:

- **Press Option+Space** anywhere on macOS to enter recall mode
- **Navigate by number** — press `1` to select the first term, `L` for the left side of an equation, `2` to drill into the second child
- **Hear every step** — VoiceOver announces "Left side, 3 items" or "x squared, power node" as you move
- **Press Space to insert** — the selected sub-expression is typed into whatever app you're working in

There is no mouse interaction. No drag-and-drop. No visual canvas. Every design decision was made by asking: *can a person who cannot see this screen understand exactly where they are in this expression, and get exactly what they need out of it?*

## AI-Assisted, Human-Directed, Fully Deterministic

Math Recall was built with significant AI assistance — Claude was used throughout development for architecture decisions, parser logic, test generation, and interaction design. But the system itself is entirely deterministic.

This is a deliberate choice.

The parser converts plain-text math into a structured tree using tokenization and recursive descent parsing — the same techniques compilers have used for decades. There is no language model interpreting the math. No probabilistic guessing about what `d/dx` means. Every input produces the same output, every time.

AI was used to *design* the system, not to *be* the system.

This distinction matters for accessibility. A blind student navigating an integral cannot afford ambiguity. If pressing `1, L, 2` today gives them the second term on the left side of line one, it must give them that tomorrow, and on every expression shaped the same way. Determinism isn't a technical constraint here — it's an accessibility requirement.

Where AI proved invaluable was in covering edge cases. Mathematical notation has dozens of ambiguous patterns: Is `(x+3)/2` a fraction or a grouped expression divided by two? What about `d/dx` — is the `/` division or part of the derivative operator? Does `sin(x)` mean `sin` applied to `x`, or `s * i * n * (x)`?

These cases were systematically identified and resolved through AI-assisted design sessions, producing a tolerance system that handles ambiguous input gracefully:

- Digits accepted when only one navigation option exists (skipping unnecessary L/R prompts)
- L/R input switches sides when a side is already selected
- Single-line, single-side expressions auto-collapse navigation layers
- Back navigation works through every level of the tree

Each edge case was resolved with a deterministic rule, not a probabilistic model. AI helped find the edges. The rules are human-approved and fixed.

## What's Under the Hood

Math Recall is a native macOS application written in Swift, using:

- **SwiftUI** for the minimal visual interface
- **Carbon Event Manager** for global hotkey registration (Option+Space works in any app)
- **AVSpeechSynthesizer** as a fallback when VoiceOver is off
- **Accessibility APIs** for reading content from other applications
- **Recursive descent parser** supporting calculus-level expressions: integrals, derivatives, limits, powers, roots, fractions, trig and log functions

The system has 30 unit tests covering tokenization, parsing, navigation, and serialization — all passing. The architecture is documented in a public specification that defines every state transition, error condition, and speech output.

## Why This Matters Beyond One App

There are approximately 2.2 billion people globally with vision impairment. Of those, a meaningful population encounters mathematical notation in education and work. The tools available to them have not kept pace with the tools available to sighted users.

Math Recall is one application, addressing one slice of this problem. But the approach it represents — using AI to systematically design for edge cases, maintaining full determinism in the user-facing system, and centering the needs of disabled users from the first line of code — is applicable to any domain where accessibility is treated as an afterthought.

The entire project is open source under the MIT license. The code, architecture documents, and this design process are public.

## Try It

- **GitHub**: github.com/AsimSayed/symbolic-state-recall
- **Requirements**: macOS 15.2+, Xcode 16.2+
- **License**: MIT (free, forever)

## About the Researcher

Asim Sayed is a researcher at the University of Washington's Department of Human Centered Design & Engineering (HCDE), where his work focuses on the intersection of accessibility, AI-assisted design, and inclusive computing.

---

**Media Contact**: Asim Sayed
**Affiliation**: University of Washington, HCDE
**Project**: github.com/AsimSayed/symbolic-state-recall

---

*Math Recall is not affiliated with Apple, Inc. macOS and VoiceOver are trademarks of Apple Inc. This project is independent research.*
