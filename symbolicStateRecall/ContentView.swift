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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Equation input
            HStack {
                TextField("Type equation, e.g. x^2 + 3x = 5", text: $equationInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { loadEquation() }
                Button("Load") { loadEquation() }
                    .disabled(equationInput.isEmpty)
            }

            // Status indicator
            StatusRow(state: coordinator.recallState)

            // Loaded equation
            if !coordinator.currentEquationText.isEmpty {
                EquationRow(equation: coordinator.currentEquationText)

                // Trigger recall from UI
                if coordinator.recallState == .idle {
                    Button("Trigger Recall (Option+Space)") {
                        coordinator.triggerRecallFromUI()
                    }
                    .keyboardShortcut(" ", modifiers: .option)
                }
            }

            // Accessibility permission
            HStack(spacing: 8) {
                Image(systemName: coordinator.isAccessibilityGranted
                      ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(coordinator.isAccessibilityGranted ? .green : .orange)
                    .imageScale(.medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility")
                        .font(.caption.weight(.semibold))
                    Text(coordinator.isAccessibilityGranted
                         ? "Permission granted — screen reading & global hotkey enabled"
                         : "Required for screen reading & global hotkey")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if coordinator.isAccessibilityGranted {
                    Button("Manage") {
                        AccessibilityPermission.openSystemSettings()
                    }
                    .font(.caption)
                    .controlSize(.small)
                } else {
                    Button("Grant Access") {
                        AccessibilityPermission.checkWithPrompt()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            coordinator.recheckAccessibility()
                        }
                    }
                    .font(.caption)
                    .controlSize(.small)
                    .tint(.accentColor)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(coordinator.isAccessibilityGranted
                          ? Color.green.opacity(0.08)
                          : Color.orange.opacity(0.08))
            )

            // Navigation state (visible during recall)
            if coordinator.recallState != .idle {
                NavigationStateView(
                    path: coordinator.currentPath,
                    selectedLabel: coordinator.selectedNodeLabel,
                    lastSpoken: coordinator.lastSpokenText
                )
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func loadEquation() {
        guard !equationInput.isEmpty else { return }
        coordinator.loadEquationFromUI(equationInput)
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let state: RecallState

    private var statusText: String {
        switch state {
        case .idle: return "Idle"
        case .recallActive: return "Recall Active"
        case .pathBuilding: return "Path Building"
        case .nodeResolved: return "Node Selected"
        case .error(let msg): return "Error: \(msg)"
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

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status")
        .accessibilityValue(statusText)
    }
}

// MARK: - Equation Row

struct EquationRow: View {
    let equation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Loaded Equation")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(equation)
                .font(.system(.body, design: .monospaced))
                .lineLimit(3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loaded equation")
        .accessibilityValue(equation)
    }
}

// MARK: - Navigation State

struct NavigationStateView: View {
    let path: [String]
    let selectedLabel: String
    let lastSpoken: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            if !path.isEmpty {
                HStack(spacing: 4) {
                    Text("Path:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(path.joined(separator: " > "))
                        .font(.system(.body, design: .monospaced))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Navigation path")
                .accessibilityValue(path.joined(separator: ", "))
            }

            if !selectedLabel.isEmpty {
                HStack(spacing: 4) {
                    Text("Selected:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedLabel)
                        .font(.body)
                        .bold()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Selected node")
                .accessibilityValue(selectedLabel)
            }

            if !lastSpoken.isEmpty {
                HStack(spacing: 4) {
                    Text("Last:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastSpoken)
                        .font(.body)
                        .italic()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last announcement")
                .accessibilityValue(lastSpoken)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
