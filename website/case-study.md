---
title: The Glance Nobody Notices
type: case-study
version: 1
date: 2026-07-13
status: content-locked-draft
---

<!--
TITLE OPTIONS (chosen title used below):
  A. "The Glance Nobody Notices"  ← chosen
  B. "A Memory Problem in Disguise"
  C. "We Are All Blind" (current draft's title, retained as alternate)
-->

# The Glance Nobody Notices

Sighted students solve math with the screen as a second brain. They glance up at the original equation, catch a coefficient, and keep writing, and the glance costs under a second. A blind student cannot glance. Every check becomes a full navigation event: stop, arrow up line by line, listen character by character, hold the value, navigate back, resume. We started this project expecting a notation problem. We found a memory problem, and then we built a tool that hands the missing memory back.

Math Recall (repo name SymbolicStateRecall) is a native macOS app that lets a blind or visually impaired user drill into any part of a math expression by keyboard, hear it spoken through VoiceOver, and drop it at the cursor without leaving their place. It began as a research project in HCDE 515, Accessibility and Inclusive Design, at the University of Washington in Winter 2026, taught by Prof. Leah Findlater. I led the research and built the prototype and the shipped product; Jiyae Choi ran synthesis, transcription, and insight coding; Nicolas Rodriguez facilitated the co-design session and developed the haptic ring concept; Penny Yeh handled documentation, competitive analysis, and the AI Scribe concept. The person at the center of the work was Abdallah Altahaineh, a blind computer science student who let us watch him do real calculus and then helped invent the thing we ended up building.

## We expected notation, we found memory

We went in expecting problems with math notation: screen reader mispronunciation, equation formatting, symbols read out of order. We were wrong about the difficulty and wrong about where it lived. Abdallah is strong at math, strong at STEM in general, and comfortable with how his tools speak notation aloud. The barrier is not comprehension. The barrier is working memory.

Sighted students use the screen as persistent external working memory. Mid-problem, you look up, read the term you need, and return, and none of it registers as effort because the glance is nearly free. For Abdallah that glance is a full navigation event. He stops writing, arrows up through the document line by line, listens to content character by character until he reaches what he needs, holds it in his head, navigates back to the insertion point, and resumes. Every intermediate value he wants to recheck triggers the whole cycle, and every cycle spends the concentration the problem itself needs.

> "I keep having to scroll up to reread the original equation and copy it down. Sighted students can glance and keep typing. I have to keep navigating back and forth."
>
> Abdallah, need-finding session

The harder the problem, the worse the tax. More intermediate values to hold means more navigations, and more navigations means more chances to lose the thread of the reasoning. The intrinsic difficulty of the math gets compounded by the extraneous cost of tracking state by hand, and the two are hard to separate from the inside.

## Research: three sessions with Abdallah

Abdallah is a computer science student at UW, from Dubai, with near-total blindness. He perceives large shifts in light and shadow and the silhouettes of buildings, but no detail, and he moves through his coursework almost entirely through a screen reader and his own memory. He runs VoiceOver across a MacBook, iPhone, and iPad, and he has memorized the full keyboard layout down to the special characters. He walks campus without a cane. Asked how he keeps to a straight line, he said, "I hope. That's very much what I can say."

We worked with Abdallah across three in-person sessions at Maple Hall over the quarter: a need-finding interview, a co-design session on February 21, 2026, and a prototype test on March 21, 2026. In the co-design session we brought real calculus, implicit differentiation and related rates, and watched him solve it two ways, first alone and then with a human scribe sitting beside him.

<!-- PHOTO: codesign-session.jpg — co-design session at Maple Hall, Feb 21, 2026. Abdallah solving calculus while the team observes. -->

The scribe changed everything, and the way it changed things told us what to build. Given a person to help, Abdallah never once asked the scribe to solve anything. He asked the scribe to remember. "Can you remind me what the equation was?" "What was the first term?" "Can you read what I have so far?" He did the thinking himself and offloaded only the holding. The scribe was a memory device, not a solver, and that distinction became the spine of the whole project.

He also drew a line we had been blurring, between forgetting and checking. "Memory is when I completely forgot something. Clarifying is when I'm 90% sure but want to check." Two needs, two urgencies, two interaction patterns. And when we asked how he caught his own mistakes without visual scanning, he described replaying the work in his head: "I retraced the steps in my head." Effective, and expensive, and exactly the kind of load a tool could lift.

Underneath all of it sat a claim about what math actually is, which reframed the problem better than any of our notes did.

> "Math is mostly understanding and not memorizing. No one is memorizing when they're solving math. They're solving something."
>
> Abdallah, co-design session

## Co-design: the grammar Abdallah invented

The turning point came during brainstorming in the co-design session, not during observation. I proposed a rough concept: a tool that would parse an equation into a structured tree, index every term, and let you summon any piece back to your cursor with a keyboard shortcut. I expected to iterate on it for a while. Instead Abdallah took it and sharpened it in real time, and the grammar he described on the spot is close to the grammar the product shipped with.

> "It could be a program that looks like a normal document but stores what I write in structured maps. If I type 2x + 3 = 9, the program automatically identifies left and right sides, breaks the left side into terms, stores them as keys and values. Then I could press a shortcut like 'Left 1' to retrieve 2x, 'Left 2' for 3, and 'Right' for 9."
>
> Abdallah, co-design session, elaborating on the proposed concept

He kept going. He wanted nesting: "It should understand nested structures — numerator, denominator, inside parentheses — and store those too." And he made clear this was not an abstract wish. "I could actually code something like this. I'm planning to build an accessible study tool this summer." The person we were designing for had, in one sitting, specified the key/value left-right structure, asked for recursive descent into nested parts, and told us he could build it himself. Our job stopped being invention and became execution: get the grammar exactly right, keep it out of the user's way, and make it never lie.

## Six principles the research fixed

Coding the transcripts and mapping Abdallah's pain points against his real workflow gave us six principles. They held through every design decision that followed.

1. **Don't interrupt context to retrieve.** Recall must not require scrolling, mode-switching, or moving the cursor away from the work.
2. **Don't disrupt flow for recall.** Checking an intermediate value must not reset screen reader focus or change reading modes; cursor position is preserved throughout.
3. **Preserve user agency.** The system offers memory scaffolding, never solving. It does not complete steps or transform expressions on the user's behalf.
4. **Preserve notation integrity.** The system keeps mathematical structure intact and speaks notation the way the domain does, "x squared" rather than a shape, a prime as a prime.
5. **Operate within existing infrastructure.** Integrate with VoiceOver, macOS, and the editors Abdallah already trusts, rather than replacing a workflow that works.
6. **Keep intermediate steps persistently available.** Multi-step work throws off short-lived states; the system stabilizes and indexes them so they can be recalled without mental reconstruction.

## Three concepts, one that fit

We took three concepts into critique with Abdallah and the course instructors, each attacking the memory problem through a different modality.

The first was Symbolic State Recall via hotkeys: a keyboard-driven system that parses an equation into a navigable tree and lets the user summon any term with a compact query grammar, numbers and L/R, no new symbols. The second was a Haptic Syntax Ring: a wearable that translates structural hierarchy into pressure and vibration, encoding nesting depth in the hand, with gestures to save and replay. The third was an AI Voice Scribe: a conversational companion running alongside existing tools, answering spoken questions like "What was the value of x?"

The hotkey concept won, and the reasons were concrete. It was the most direct fit for what Abdallah actually needed, structured random-access recall without leaving the insertion point. It matched, almost line for line, the grammar he had described himself. And it asked nothing extra of him: no new hardware to carry, no AI dependency to trust, no separate app to context-switch into. It lived inside the macOS and VoiceOver world he already knew.

## Prototype and test

The prototype was a Swift program that demonstrated the full loop: parse an equation into an abstract syntax tree, navigate the tree with the recall grammar, and speak the result at every step. The interaction reads like this. Press Option+Space to enter recall mode. Type a path, where `1 L 2` means line 1, left side, item 2. After every token the system speaks what it resolved, "Line 1", then "Left side, 3 items", then "x squared", so the user always knows exactly where they are. Press Space to insert the selected node at the cursor in whatever app they are in. Backspace moves up one level. Esc exits. Fractions, powers, roots, integrals, and the rest expand into child nodes you can drill into, and the grammar scales to any depth without new commands.

<!-- PHOTO: testing-session.jpg — final testing session at Maple Hall, Mar 21, 2026. Abdallah testing the working prototype. -->

In the final session Abdallah tested it on single-line and multi-line equations, and his verdict set the bar we then had to build toward.

> "If a human scribe is a 10, this tool is like a 9 or 9.5."
>
> Abdallah, after testing the prototype

He liked the left/right organization, the term-by-term navigation, and the way a fraction opened cleanly into numerator and denominator. He asked for more: smoother switching between typing and recall, lateral movement between sides without backtracking, and eventually a version that could reach into multi-file coding work. Most telling was a distinction he made about where the difficulty sat. "What's confusing me is not the steps we can track — what's confusing me is what the question itself wants us to do." The recall mechanism was clear. The math was the hard part, which is where the hard part belongs.

## The build: determinism as an accessibility requirement

After the course I rebuilt the prototype into a shipped product, a native macOS app in Swift with zero external dependencies. The interface is a SwiftUI floating dock bar hosted in a borderless panel, always on top, present across every Space. A Carbon global hotkey catches Option+Space from any app. CGEvent taps intercept the query keystrokes. AXUIElement reads the focused text so the app can pull math straight from the field the user is working in. Speech does not go through AVSpeechSynthesizer, despite what an earlier writeup of mine claimed; it posts NSAccessibility announcements, which is the only way to interleave cleanly with VoiceOver's own speech queue instead of talking over it. Under all of that sits a recursive descent parser with fourteen node types covering the calculus scope: equations, fractions, powers, roots, integrals, derivatives, limits, and trig and log functions. Thirty unit tests cover tokenizing, parsing, navigation, and serialization, and they pass.

I designed this system with heavy help from Claude, and there is no AI anywhere inside it. Both facts are deliberate: AI shaped the design, and I kept it out of the product. Claude helped me work out the architecture, the parser logic, the test suite, and, most usefully, the edge cases. But the running program contains no model, no inference, no probabilistic guess about what a user meant. Every input parses the same way every time.

Determinism here is not an engineering preference. It is an accessibility requirement. A sighted user who gets an odd result can glance at the screen and correct course in a second. A blind user navigating an expression by memory has no such fallback; the tool's output is the only ground truth they have. So if `1 L 2` returns the second term on the left today, it has to return exactly that tomorrow, and on every expression shaped the same way, forever. Ambiguity that a sighted user would shrug off becomes, for a user navigating by recall, a reason not to trust the tool at all.

The edges are where the discipline shows. Math notation is full of shapes that could parse two ways. Is `(x+3)/2` a fraction, or a grouped expression divided by 2? In `d/dx`, is the slash division, or part of the derivative operator? Is `sin(x)` the sine function applied to x, or the letters s, i, and n multiplied against a parenthesized x? Claude helped me surface these cases and dozens like them, systematically, faster than I would have found them by hand. But every one of them is resolved by a fixed, human-approved rule written into the parser, not by a model deciding case by case at runtime. AI found the edges. The rules that settle them are fixed.

The same conviction shaped the error handling, and I treated it as a design value rather than a fallback. The core rule is that the tool never ejects the user out of recall mode on the first mistake. A bad index does not dump them back to the start; it keeps the last valid prefix, tells them what went wrong, and speaks the current state so they always know where they stand. "No item at position N" and stay put. "No deeper structure" and hold the current node. "Nothing selected" and wait. For a user who cannot see the recovery happen, the recovery has to be spoken, gentle, and predictable, because the alternative is getting silently lost inside your own equation.

## Ship

Math Recall shipped as v1.0.0 on June 7, 2026, free, MIT licensed, and open source. It installs through Homebrew with `brew install --cask asimsayed/tap/symbolic-state-recall` as a universal binary, and the DMG can be downloaded directly from GitHub Releases. What adoption looks like from here, I do not yet know.

## Reflection

The hardest part of this project was designing for a user I cannot simulate. I can close my eyes, but I cannot un-know the layout of an equation I have already seen, and I cannot feel what it costs to lose my place inside one and rebuild it from memory. Everything useful I learned came from watching Abdallah work and from listening to how precisely he described his own experience, and the single best design decision, the recall grammar, was largely his. My job was to take that seriously enough to build it exactly, and to resist the temptation to make the tool cleverer than it needed to be. The scribe he asked for only ever held state. The tool does the same thing, and refusing to let it do more is most of what made it good.
