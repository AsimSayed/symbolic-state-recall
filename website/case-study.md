---
title: "Math Recall: a math navigation tool for blind students, from research to release"
type: case-study
version: 2
date: 2026-07-13
status: content-locked-draft
---

# Math Recall: a math navigation tool for blind students, from research to release

Math Recall is a free, open-source macOS app that lets blind and low-vision users navigate math expressions by structure through VoiceOver. The user presses a hotkey, types a short query like `1 L 2`, hears the matching part of the equation spoken aloud, and can insert it at the cursor in any app. It began as a research project in HCDE 515, Accessibility and Inclusive Design, at the University of Washington in Winter 2026, taught by Prof. Leah Findlater, and shipped as v1.0.0 in June 2026. This case study covers the research with our design partner, the interaction model that came out of it, and the decisions behind the shipped product.

The team: I led the research, facilitated sessions, and built the prototype and the shipped product. Jiyae Choi did synthesis, transcription, and insight coding. Nicolas Rodriguez co-facilitated the co-design session and developed the haptic ring concept. Penny Yeh handled documentation, competitive analysis, and the AI Scribe concept. Our design partner was Abdallah Altahaineh, a blind computer science student at UW.

## The problem

Our need-finding plan targeted notation issues: screen reader mispronunciation, formatting, symbols read out of order. The sessions showed the cost was working memory. Abdallah is strong at math and comfortable with how his tools speak notation. What slows him down is holding the state of a problem in his head while he works on it.

Sighted students use the screen as persistent external working memory. Mid-problem, they look up at the original equation, read a coefficient, and continue. The glance takes under a second. For Abdallah, every such check is a full navigation event: stop writing, arrow up through the document line by line, listen character by character until he finds the value, hold it in memory, navigate back to the insertion point, resume. Each navigation breaks his concentration on the math itself.

> "I keep having to scroll up to reread the original equation and copy it down. Sighted students can glance and keep typing. I have to keep navigating back and forth."
>
> Abdallah, need-finding session

The cost scales with problem difficulty. Harder problems produce more intermediate values, more values require more checks, and each check restarts the navigation cycle.

## Research

Abdallah is a computer science student at UW, from Dubai, with near-total blindness. He perceives large changes in light and building silhouettes, no detail. He uses VoiceOver across a MacBook, iPhone, and iPad and has memorized the full keyboard layout, including special characters. Asked how he walks in a straight line without a cane, he said, "I hope. That's very much what I can say."

We ran three in-person sessions at Maple Hall: a need-finding interview, a co-design session on February 21, 2026, and a prototype test on March 21, 2026. In the co-design session we brought real calculus problems, implicit differentiation and related rates, and watched him solve them first alone and then with a human scribe.

<!-- PHOTO: codesign-session.jpg — co-design session at Maple Hall, Feb 21, 2026. Abdallah solving calculus while the team observes. -->

Three findings shaped the design.

First, the scribe acted as memory, not as a solver. Abdallah never asked the scribe to solve anything. He asked the scribe to recall: "Can you remind me what the equation was?" "What was the first term?" "Can you read what I have so far?" He did all the reasoning himself and offloaded only the state-holding.

Second, he distinguished two retrieval needs. "Memory is when I completely forgot something. Clarifying is when I'm 90% sure but want to check." The two differ in urgency and in how much context the user needs back.

Third, without visual scanning, he catches errors by mentally replaying his steps: "I retraced the steps in my head." This works, but it consumes the same working memory the problem needs.

He also gave us the framing we used for the rest of the project:

> "Math is mostly understanding and not memorizing. No one is memorizing when they're solving math. They're solving something."
>
> Abdallah, co-design session

## Co-design

During brainstorming in the co-design session, I proposed a concept: parse an equation into a structured tree, index every term, and let the user retrieve any piece with a keyboard shortcut. Abdallah refined it on the spot into a key/value grammar organized by equation side:

> "It could be a program that looks like a normal document but stores what I write in structured maps. If I type 2x + 3 = 9, the program automatically identifies left and right sides, breaks the left side into terms, stores them as keys and values. Then I could press a shortcut like 'Left 1' to retrieve 2x, 'Left 2' for 3, and 'Right' for 9."
>
> Abdallah, co-design session, elaborating on the proposed concept

He added two requirements. Nesting: "It should understand nested structures — numerator, denominator, inside parentheses — and store those too." And feasibility, from his own experience as a programmer: "I could actually code something like this. I'm planning to build an accessible study tool this summer." The shipped query grammar is close to what he described in that session.

## Design principles

Six principles came out of coding the session transcripts and mapping them against Abdallah's workflow.

1. **Don't interrupt context to retrieve.** Recall must not require scrolling, mode-switching, or moving the cursor away from the work.
2. **Don't disrupt flow for recall.** Checking a value must not reset screen reader focus or change reading modes; cursor position is preserved.
3. **Preserve user agency.** The system provides memory scaffolding, never solving. It does not complete steps or transform expressions.
4. **Preserve notation integrity.** The system keeps mathematical structure intact and speaks it in domain terms: "x squared," not a shape name.
5. **Operate within existing infrastructure.** Integrate with VoiceOver and macOS rather than replacing tools the user already relies on.
6. **Keep intermediate steps persistently available.** Multi-step work produces short-lived intermediate states; the system indexes them so they can be recalled without mental reconstruction.

## Three concepts

We took three concepts into critique with Abdallah and the course instructors. Symbolic State Recall via hotkeys: a keyboard-driven system that parses an equation into a navigable tree and retrieves any term through a compact query grammar of numbers and L/R. Haptic Syntax Ring: a wearable that encodes nesting depth in pressure and vibration patterns, with gestures for save and replay. AI Voice Scribe: a conversational companion answering spoken questions like "What was the value of x?"

We chose the hotkey concept. It addressed the core need most directly: structured random-access recall without leaving the insertion point. It matched the grammar Abdallah had described. And it required no new hardware and no AI dependency; it runs inside the macOS and VoiceOver setup he already uses.

## Prototype and testing

The prototype was a Swift program demonstrating the full loop: parse an equation into an abstract syntax tree, navigate it with the query grammar, speak each step. The interaction: press Option+Space to enter recall mode. Type a path; `1 L 2` means line 1, left side, item 2. The system speaks after every token: "Line 1," then "Left side, 3 items," then "x squared." Space inserts the selected node at the cursor. Backspace moves up one level. Esc exits. Fractions, powers, roots, integrals, derivatives, and limits expand into child nodes, so the same grammar reaches any depth without new commands.

<!-- PHOTO: testing-session.jpg — final testing session at Maple Hall, Mar 21, 2026. Abdallah testing the working prototype. -->

Abdallah tested it on single-line and multi-line equations in the March session.

> "If a human scribe is a 10, this tool is like a 9 or 9.5."
>
> Abdallah, after testing the prototype

He liked the left/right organization, term-by-term navigation, and fractions opening into numerator and denominator nodes. He requested smoother switching between typing and recall, lateral movement between sides without backtracking, and an eventual extension to multi-file coding work. He also separated tool confusion from task confusion: "What's confusing me is not the steps we can track — what's confusing me is what the question itself wants us to do." The recall mechanism was clear; the remaining difficulty was the math.

## Building the product

After the course, I rebuilt the prototype as a shipped macOS app in Swift with zero external dependencies. The interface is a SwiftUI floating dock bar. A Carbon global hotkey catches Option+Space from any app. CGEvent taps intercept query keystrokes. AXUIElement reads the focused text field so the app can pull math from wherever the user is working. Speech goes through NSAccessibility announcement posting, not AVSpeechSynthesizer (an earlier writeup of mine said AVSpeech; that was wrong). NSAccessibility posting is the only method that interleaves cleanly with VoiceOver's own speech queue. The parser is recursive descent with 14 node types covering calculus: equations, fractions, powers, roots, integrals, derivatives, limits, trig and log functions. 30 unit tests cover tokenizing, parsing, navigation, and serialization; all pass.

I used Claude heavily to design the system: architecture, parser logic, test generation, edge-case discovery. There is no AI in the system itself. The running app contains no model and no inference; every input parses the same way every time.

Determinism is an accessibility requirement here, not a stylistic choice. A sighted user who gets an unexpected result can glance at the screen and correct course. A blind user navigating by memory has only the tool's output. If `1 L 2` returns the second term on the left side today, it must return exactly that tomorrow, on every expression with the same shape. Ambiguity a sighted user could shrug off makes the tool untrustworthy for a user who cannot verify visually.

Math notation is full of inputs that could parse two ways. Is `(x+3)/2` a fraction or a grouped expression divided by 2? In `d/dx`, is the slash division or part of the derivative operator? Is `sin(x)` the sine function applied to x, or s times i times n? Claude surfaced these cases faster than I would have found them by hand. Each one is resolved by a fixed rule written into the parser and approved by me, not by a model deciding at runtime.

Error handling follows one rule: never drop the user out of recall mode on the first error. A bad index keeps the last valid prefix, reports the problem ("No item at position N"), and speaks the current state. An attempt to expand a leaf node returns "No deeper structure" and holds the current selection. Pressing Space with nothing selected returns "Nothing selected" and waits. A user who cannot see the recovery has to hear it, and has to be able to predict it.

## Release

Math Recall shipped as v1.0.0 on June 7, 2026. It is free, MIT licensed, and open source. Install via Homebrew with `brew install --cask asimsayed/tap/symbolic-state-recall` (universal binary), or download the DMG from GitHub Releases. Adoption is not yet measured.

## Reflection

The hardest part of this project was designing for a user I cannot simulate. I can close my eyes, but I cannot un-know the layout of an equation I have already seen, and I cannot feel the cost of losing my place in one and rebuilding it from memory. The useful design knowledge came from watching Abdallah work and from how precisely he described his own experience. The best design decision, the recall grammar, was largely his. My contribution was building it exactly as specified and keeping the tool within its role: the scribe he asked for only held state, and the tool only holds state.
