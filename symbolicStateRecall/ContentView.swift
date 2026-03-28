//
//  ContentView.swift
//  symbolicStateRecall
//
//  Created by Asim Sayed on 16/03/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var equationInput: String = ""
    @State private var isLoadHovered = false
    @State private var showEquation = false

    var body: some View {
        VStack(spacing: 0) {
            // Equation input bar
            HStack(spacing: 10) {
                Image(systemName: "function")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Type equation, e.g. x^2 + 3x = 5", text: $equationInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { loadEquation() }

                Button(action: loadEquation) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .scaleEffect(isLoadHovered ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(equationInput.isEmpty)
                .opacity(equationInput.isEmpty ? 0.3 : 1.0)
                .onHover { isLoadHovered = $0 }
                .animation(.spring(response: 0.3), value: isLoadHovered)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Status pill
            StatusPill(state: coordinator.recallState)
                .padding(.top, 14)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: coordinator.recallState)

            // Loaded equation card
            if !coordinator.currentEquationText.isEmpty {
                EquationCard(
                    equation: coordinator.currentEquationText,
                    isRecallIdle: coordinator.recallState == .idle,
                    onTrigger: { coordinator.triggerRecallFromUI() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding(.top, 12)
            }

            // Navigation state (visible during recall)
            if coordinator.recallState != .idle {
                NavigationStateCard(
                    path: coordinator.currentPath,
                    selectedLabel: coordinator.selectedNodeLabel,
                    lastSpoken: coordinator.lastSpokenText
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.top, 12)
            }

            Spacer()

            // Accessibility permission bar — anchored to bottom
            AccessibilityBar(
                isGranted: coordinator.isAccessibilityGranted,
                onGrant: {
                    AccessibilityPermission.checkWithPrompt()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        coordinator.recheckAccessibility()
                    }
                },
                onManage: {
                    AccessibilityPermission.openSystemSettings()
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(minWidth: 420, minHeight: 320)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: coordinator.currentEquationText.isEmpty)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: coordinator.recallState != .idle)
    }

    private func loadEquation() {
        guard !equationInput.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            coordinator.loadEquationFromUI(equationInput)
        }
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let state: RecallState

    @State private var isPulsing = false

    private var statusText: String {
        switch state {
        case .idle: return "Idle"
        case .recallActive: return "Recall Active"
        case .pathBuilding: return "Path Building"
        case .nodeResolved: return "Node Selected"
        case .error(let msg): return msg
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle: return .secondary
        case .recallActive, .pathBuilding: return .blue
        case .nodeResolved: return .green
        case .error: return .red
        }
    }

    private var statusIcon: String {
        switch state {
        case .idle: return "circle.fill"
        case .recallActive: return "antenna.radiowaves.left.and.right"
        case .pathBuilding: return "arrow.triangle.branch"
        case .nodeResolved: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var isActive: Bool {
        state != .idle
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColor)
                .scaleEffect(isPulsing && isActive ? 1.2 : 1.0)

            Text(statusText)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(statusColor.opacity(isActive ? 0.12 : 0.06))
                .overlay(
                    Capsule()
                        .strokeBorder(statusColor.opacity(isActive ? 0.25 : 0.1), lineWidth: 0.5)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(statusText)
        .onChange(of: state) { _, newState in
            if newState != .idle {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
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

// MARK: - Equation Card

struct EquationCard: View {
    let equation: String
    let isRecallIdle: Bool
    let onTrigger: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Loaded Equation", systemImage: "textformat.abc")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(equation)
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRecallIdle {
                Button(action: onTrigger) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Trigger Recall")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        Text("(Option+Space)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(" ", modifiers: .option)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.18 : 0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: isHovered ? 12 : 6, y: 2)
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.25), value: isHovered)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loaded equation")
        .accessibilityValue(equation)
    }
}

// MARK: - Navigation State Card

struct NavigationStateCard: View {
    let path: [String]
    let selectedLabel: String
    let lastSpoken: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !path.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text(path.joined(separator: "  >  "))
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Navigation path")
                .accessibilityValue(path.joined(separator: ", "))
            }

            if !selectedLabel.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                    Text(selectedLabel)
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Selected node")
                .accessibilityValue(selectedLabel)
            }

            if !lastSpoken.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple)
                    Text(lastSpoken)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .italic()
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last announcement")
                .accessibilityValue(lastSpoken)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.blue.opacity(0.15), lineWidth: 0.5)
                )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Accessibility Bar

struct AccessibilityBar: View {
    let isGranted: Bool
    let onGrant: () -> Void
    let onManage: () -> Void

    @State private var checkmarkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: isGranted
                      ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isGranted ? .green : .orange)
                    .scaleEffect(checkmarkScale)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Text(isGranted
                     ? "Screen reading & global hotkey enabled"
                     : "Required for screen reading & global hotkey")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isGranted {
                Button("Manage") { onManage() }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .controlSize(.small)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onGrant) {
                    Text("Grant Access")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.orange.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isGranted
                      ? Color.green.opacity(0.04)
                      : Color.orange.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            (isGranted ? Color.green : Color.orange).opacity(0.12),
                            lineWidth: 0.5
                        )
                )
        }
        .onChange(of: isGranted) { _, granted in
            if granted {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    checkmarkScale = 1.3
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) {
                    checkmarkScale = 1.0
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
