// FloatingPanel.swift
// SymbolicStateRecall
//
// A borderless, always-on-top floating panel — no title bar, no traffic
// lights, pure glass material pill. Styled like the macOS screen
// recording toolbar.

import AppKit
import SwiftUI

class FloatingPanel: NSPanel {

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: flag
        )

        // Panel behavior
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // SwiftUI handles shadows
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow

        // Stay visible across spaces, don't hide on deactivate
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false

        // No title bar at all
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
