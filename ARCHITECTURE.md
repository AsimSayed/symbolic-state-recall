# SymbolicStateRecall v1 — Architecture Document

## Overview

SymbolicStateRecall is a macOS accessibility tool that allows blind and visually impaired users to navigate, query, and insert parts of mathematical expressions using a tree-based recall system. It works alongside VoiceOver and existing text editors (Pages, etc.).

## v1 Scope: Calculus

### Supported Structures

| Type | Syntax | Example | Children |
|------|--------|---------|----------|
| Equation | `expr = expr` | `x^2 + 1 = 5` | left side, right side |
| Fraction | `(num)/(den)` or `num/den` | `(x+3)/2` | numerator, denominator |
| Power | `base^exp` | `x^2`, `e^(2t)` | base, exponent |
| Square root | `sqrt(expr)` | `sqrt(x+1)` | radicand |
| Nth root | `root(n,expr)` | `root(3,x)` | index, radicand |
| Definite integral | `int_lo^hi expr dvar` | `int_0^1 x^2 dx` | lower, upper, integrand, variable |
| Indefinite integral | `int expr dvar` | `int x^2 dx` | integrand, variable |
| Derivative | `d/dvar(expr)` | `d/dx(x^2+3x)` | variable, expression |
| Limit | `lim_var->val expr` | `lim_x->0 sin(x)/x` | variable, approach value, expression |
| Functions | `name(arg)` | `sin(x)`, `ln(y^3)` | argument |
| Grouping | `(expr)` | `(x+3)` | flattened terms |

### Deferred to v2

Matrices, piecewise functions, systems of equations, proof chains, logical quantifiers, summation/product notation.

---

## System Architecture

```
┌─────────────┐     ┌─────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ Input Layer  │────▶│ Parser      │────▶│ Navigation       │────▶│ Speech           │
│ (Clipboard)  │     │ (Tokenizer  │     │ Engine           │     │ Controller       │
│              │     │  + Parser)  │     │ (Query, Context, │     │ (VoiceOver       │
│ Future:      │     │             │     │  Selection)      │     │  announcements)  │
│ AX API       │     │ Output: AST │     │                  │     │                  │
└─────────────┘     └─────────────┘     └──────────────────┘     └──────────────────┘
                                               │
                                               ▼
                                        ┌──────────────┐
                                        │ Serializer   │
                                        │ (Node → text │
                                        │  for insert) │
                                        └──────────────┘
```

### Layer Responsibilities

1. **Input Layer** — Gets math text from clipboard (v1) or Accessibility API (v2). Triggers parse on new content.
2. **Parser** — Tokenizes plain text math, builds AST of `MathNode` objects. Handles operator precedence, implicit multiplication, grouping.
3. **Navigation Engine** — Manages recall mode, query resolution, context stack, node selection. Core of the interaction model.
4. **Speech Controller** — Generates spoken labels for nodes and announces state changes via VoiceOver's `NSAccessibility` announcement API.
5. **Serializer** — Converts a selected `MathNode` back to insertable text.

---

## Data Model

### MathNode

```swift
class MathNode {
    let id: String              // unique identifier
    var type: NodeType          // see enum below
    var value: String           // literal text (for leaf nodes)
    var children: [MathNode]    // ordered children
    weak var parent: MathNode?  // back-reference
    var indexInParent: Int      // 1-based position among siblings
    var label: String           // speakable text (e.g., "x squared")
}
```

### NodeType Enum

```swift
enum NodeType {
    case equation       // full equation (has left, right sides)
    case side           // left or right side of equation
    case expression     // ordered list of terms
    case term           // signed value (e.g., +4, -x)
    case value          // number, variable, constant
    case fraction       // numerator + denominator
    case power          // base + exponent
    case root           // radicand (square root)
    case nthRoot        // index + radicand
    case function       // named function + argument
    case integral       // integrand, variable, optional bounds
    case derivative     // variable, expression
    case limit          // variable, approach value, expression
    case group          // parenthesized expression
}
```

### Child Ordering (Deterministic)

| Type | Children (in order) |
|------|-------------------|
| fraction | numerator, denominator |
| power | base, exponent |
| root | radicand |
| nthRoot | index, radicand |
| function | argument |
| integral (definite) | lower bound, upper bound, integrand, variable |
| integral (indefinite) | integrand, variable |
| derivative | variable, expression |
| limit | variable, approach value, expression |
| group / expression | flattened terms in order |

---

## Query Grammar

### Top-level query
```
Line Side Index [Index ...]
```

- **Line**: 1-based line number
- **Side**: `L` or `R` (left or right of `=`)
- **Index**: 1-based position among items at that level
- Additional indexes drill deeper into the tree

### Local query (inside a structure)
```
Index
```
Just a number, selecting among the current context's children.

### Top-level item splitting rule
Equations are split at the top-level additive/subtractive operators. Each resulting chunk is one indexed item.

Example: `x^2 + 3x + 5 = 20`
- `1 L 1` → `x^2`
- `1 L 2` → `+3x`
- `1 L 3` → `+5`
- `1 R 1` → `20`

---

## Interaction State Machine

```
┌──────┐  Option+Space  ┌──────────────┐  digit/L/R  ┌───────────────┐
│ idle │───────────────▶│ recall_active │────────────▶│ path_building │
└──────┘                └──────────────┘             └───────┬───────┘
   ▲                          ▲                              │
   │ Esc                      │ Backspace (at root)          │ valid path
   │                          │                              ▼
   │                    ┌─────┴────────┐              ┌──────────────┐
   │                    │ insert_ready │◀─────────────│ node_resolved│
   │                    └──────────────┘              └──────────────┘
   │                          │ Space                        │
   │                          ▼                              │ expandable
   │                    insert at cursor              ┌──────▼───────┐
   │                          │                       │ local_context│
   │                          │                       └──────────────┘
   └──────────────────────────┘
```

### State Descriptions

| State | Description |
|-------|-------------|
| `idle` | Normal editing. Recall not active. |
| `recall_active` | Recall mode entered. Waiting for query input. |
| `path_building` | User typing query tokens. Each token narrows path. |
| `node_resolved` | Query points to a valid node. Spoken to user. |
| `insert_ready` | Node selected, can be inserted with Space. |
| `error` | Invalid path/query. Recovery: keep last valid prefix. |

---

## Key Behaviors

### Incremental Feedback
After each token, the system speaks what it resolved:
- `1` → "Line 1"
- `L` → "Left side"
- `2` → "plus natural log of y cubed"

### Expandable Nodes
When a node is selected and it's expandable (fraction, power, root, function, integral, derivative, limit, group), pressing its index opens a local context showing its children.

### Insert
Space with a selected node → serialize node to text → insert at cursor → exit recall mode.

### Back / Exit
- **Backspace** → move up one context level
- **Esc** → exit recall mode entirely

---

## Error Handling Summary

| Error | Response | Recovery |
|-------|----------|----------|
| Invalid line | "Line not found" | Stay in recall, re-enter |
| Invalid side | "Invalid side" | Ask for L or R |
| Invalid index | "No item at position N" | Keep valid prefix |
| Non-expandable node | "No deeper structure" | Keep current node |
| Empty side | "No items on this side" | Return to side selection |
| Space with no selection | "Nothing selected" | Stay in recall |
| Parse failure | "Equation could not be indexed" | Fall back to plain navigation |

**Core rule:** Never drop the user out of recall mode on first error. Preserve last valid prefix. Always speak current state after recovery.

---

## Input Format Specification (v1)

### Tokenizer Rules

1. Numbers: sequences of digits, optionally with `.`
2. Variables: single letters (a-z, A-Z) except reserved function names
3. Operators: `+`, `-`, `*`, `/`, `^`, `=`
4. Grouping: `(`, `)`
5. Keywords: `int`, `sqrt`, `root`, `lim`, `sin`, `cos`, `tan`, `ln`, `log`, `d`
6. Subscript marker: `_` (used for integral bounds, limit variable)
7. Arrow: `->` (used in limits)
8. Differential: `dx`, `dy`, `dt`, etc. (d followed by single variable)

### Precedence (lowest to highest)

1. `=` (equation separator)
2. `+`, `-` (addition, subtraction)
3. `*`, implicit multiplication (juxtaposition)
4. `/` (division / fraction)
5. `^` (exponentiation)
6. Unary `-`
7. Functions, integrals, derivatives, limits
8. Parentheses

### Implicit Multiplication

`3x` → `3 * x`, `2(x+1)` → `2 * (x+1)`, `xy` → `x * y`

### Ambiguity Resolution

- `-x^2` → `-(x^2)` (unary minus binds looser than power)
- `1/2x` → `(1)/(2x)` (division extends to next full term)
- `sin(x)^2` → `(sin(x))^2`

---

## File Structure

```
MathRecall/
├── ARCHITECTURE.md              ← this file
├── MathRecall/
│   ├── Core/
│   │   ├── Parser/
│   │   │   ├── Token.swift          — token types
│   │   │   ├── Tokenizer.swift      — plain text → tokens
│   │   │   ├── Parser.swift         — tokens → AST
│   │   │   └── MathNode.swift       — AST node model
│   │   ├── Navigation/
│   │   │   ├── NavigationEngine.swift — recall mode controller
│   │   │   ├── QueryResolver.swift    — path → node resolution
│   │   │   └── RecallContext.swift     — context stack model
│   │   └── Speech/
│   │       └── SpeechController.swift — label generation + VO announcements
│   ├── Input/
│   │   ├── ClipboardMonitor.swift    — reads math from clipboard
│   │   └── HotkeyManager.swift      — Option+Space global hotkey
│   └── Utilities/
│       └── MathSerializer.swift     — node → insertable text
├── MathRecallTests/
│   ├── TokenizerTests.swift
│   ├── ParserTests.swift
│   ├── NavigationTests.swift
│   └── SerializerTests.swift
└── README.md
```

---

## Implementation Priority

### Phase 1: Core (prototype)
1. MathNode model
2. Tokenizer
3. Parser (with all v1 structures)
4. Navigation engine + query resolver
5. Serializer
6. Unit tests for all above

### Phase 2: macOS Integration
1. Global hotkey (Option+Space)
2. Clipboard monitoring
3. VoiceOver speech announcements
4. Insert-at-cursor via AX API or pasteboard

### Phase 3: Polish
1. Error handling (full exception table from design doc)
2. Stale reference detection after edits
3. Timeout handling
4. VoiceOver conflict mitigation
