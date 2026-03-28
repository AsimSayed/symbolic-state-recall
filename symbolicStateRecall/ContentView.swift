//
//  ContentView.swift
//  symbolicStateRecall
//
//  Created by Asim Sayed on 16/03/26.
//

import SwiftUI

// MARK: - Spacing System (4pt grid)

private let spaceXS: CGFloat = 4
private let spaceSM: CGFloat = 8
private let spaceMD: CGFloat = 12
private let spaceLG: CGFloat = 16

private let cornerBar: CGFloat = 18
private let cornerStrip: CGFloat = 12
private let cornerButton: CGFloat = 10
private let cornerGroup: CGFloat = 12

// MARK: - Floating Dock Bar

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showSettings = false

    private var isRecalling: Bool {
        coordinator.recallState != .idle
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: spaceSM) {
            // Main bar
            HStack(spacing: spaceSM) {
                BarButton(icon: "xmark", showHoverColor: true) {
                    NSApplication.shared.terminate(nil)
                }

                BarStatusItem(state: coordinator.recallState)

                HStack(spacing: spaceXS) {
                    BarButton(icon: "bolt.fill", isActive: isRecalling) {
                        coordinator.triggerRecallFromUI()
                    }
                    .keyboardShortcut(" ", modifiers: .option)

                    BarButton(
                        icon: "gearshape.fill",
                        isActive: showSettings,
                        badgeDot: !coordinator.isAccessibilityGranted
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showSettings.toggle()
                        }
                    }
                }
                .padding(spaceXS)
                .background {
                    RoundedRectangle(cornerRadius: cornerGroup, style: .continuous)
                        .fill(.white.opacity(0.06))
                }
            }
            .padding(spaceSM)
            .background { barBackground }
            .clipShape(RoundedRectangle(cornerRadius: cornerBar, style: .continuous))

            if isRecalling {
                recallStrip
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )
            }

            if showSettings {
                settingsStrip
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        )
                    )

                if !coordinator.recentEquations.isEmpty {
                    recentStrip
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            )
                        )
                }
            }
        }
        .padding(spaceLG)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isRecalling)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showSettings)
        .fixedSize()
    }

    // MARK: - Bar Background

    private var barBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerBar, style: .continuous)
                .fill(.black.opacity(0.5))
            RoundedRectangle(cornerRadius: cornerBar, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerBar, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 20, y: 6)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    // MARK: - Recall Strip

    private var recallStrip: some View {
        VStack(alignment: .leading, spacing: spaceSM) {
            if !coordinator.selectedNodeLabel.isEmpty {
                HStack(spacing: spaceSM) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(coordinator.selectedNodeLabel)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .contentTransition(.numericText())
                }
            }

            if !coordinator.lastSpokenText.isEmpty {
                HStack(spacing: spaceSM) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(coordinator.lastSpokenText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if !coordinator.currentPath.isEmpty {
                HStack(spacing: spaceSM) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(coordinator.currentPath.joined(separator: " > "))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(spaceMD)
        .frame(maxWidth: 320)
        .background { stripBackground }
        .clipShape(RoundedRectangle(cornerRadius: cornerStrip, style: .continuous))
    }

    // MARK: - Settings Strip

    private var settingsStrip: some View {
        HStack(spacing: spaceSM) {
            HStack(spacing: spaceSM) {
                Circle()
                    .fill(coordinator.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(coordinator.isAccessibilityGranted ? "Accessibility granted" : "Accessibility needed")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if coordinator.isAccessibilityGranted {
                Button("Manage") {
                    AccessibilityPermission.openSystemSettings()
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.4))
            } else {
                Button(action: {
                    AccessibilityPermission.checkWithPrompt()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        coordinator.recheckAccessibility()
                    }
                }) {
                    Text("Grant")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, spaceXS)
                        .background {
                            Capsule().fill(.white.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(spaceMD)
        .frame(minWidth: 220)
        .background { stripBackground }
        .clipShape(RoundedRectangle(cornerRadius: cornerStrip, style: .continuous))
    }

    // MARK: - Recent Strip

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, spaceMD)
                .padding(.top, spaceSM)
                .padding(.bottom, spaceXS)

            ForEach(coordinator.recentEquations, id: \.self) { equation in
                Button(action: {
                    coordinator.loadRecentEquation(equation)
                }) {
                    Text(equation)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, spaceMD)
                        .padding(.vertical, spaceXS + 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    RecentRowBackground()
                }
            }
        }
        .padding(.bottom, spaceSM)
        .frame(minWidth: 220, maxWidth: 280)
        .background { stripBackground }
        .clipShape(RoundedRectangle(cornerRadius: cornerStrip, style: .continuous))
    }

    private var stripBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerStrip, style: .continuous)
                .fill(.black.opacity(0.4))
            RoundedRectangle(cornerRadius: cornerStrip, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerStrip, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
    }
}

// MARK: - Bar Button

struct BarButton: View {
    let icon: String
    var showHoverColor: Bool = false
    var isActive: Bool = false
    var badgeDot: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        showHoverColor && isHovered
                            ? Color.red
                            : .white.opacity(isActive ? 1.0 : isHovered ? 0.9 : 0.55)
                    )
                    .shadow(color: isActive ? .white.opacity(0.5) : .clear, radius: 4)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: cornerButton, style: .continuous)
                            .fill(isActive ? .white.opacity(0.12) : isHovered ? .white.opacity(0.08) : .clear)
                    }
                    .scaleEffect(isPressed ? 0.88 : isHovered ? 1.06 : 1.0)

                if badgeDot {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                        .offset(x: 1, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Bar Status Item

struct BarStatusItem: View {
    let state: RecallState
    @State private var isPulsing = false

    private var statusText: String {
        switch state {
        case .idle: return "Idle"
        case .recallActive: return "Active"
        case .pathBuilding: return "Building"
        case .nodeResolved: return "Selected"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle: return .gray
        case .recallActive, .pathBuilding: return .green
        case .nodeResolved: return .green
        case .error: return .red
        }
    }

    private var isActive: Bool { state != .idle }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 18, height: 18)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.6)
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: isActive ? statusColor.opacity(0.6) : .clear, radius: 5)
            }

            Text(statusText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .contentTransition(.numericText())
        }
        .frame(width: 48, height: 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(statusText)
        .onChange(of: state) { _, newState in
            if newState != .idle {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    isPulsing = false
                }
            }
        }
    }
}

// MARK: - Recent Row Background

struct RecentRowBackground: View {
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isHovered ? .white.opacity(0.06) : .clear)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
