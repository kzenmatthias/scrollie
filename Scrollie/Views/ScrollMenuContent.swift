//
//  ScrollMenuContent.swift
//  Scrollie
//

import AppKit
import ServiceManagement
import SwiftUI

struct ScrollMenuContent: View {
    @State private var controller = ScrollController.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scrollie")
                    .font(.headline)
                Spacer()
                StatusBadge(isActive: controller.isActive)
            }

            if !controller.hasAccessibilityAccess {
                PermissionNotice {
                    AccessibilityPermission.openSystemSettings()
                }
            }

            Toggle("Slow down scrolling", isOn: $controller.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            SpeedSlider(title: "Scroll wheel", value: $controller.verticalFactor)
            SpeedSlider(title: "Thumb wheel", value: $controller.horizontalFactor)

            Divider()

            Toggle("Open at Login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            HStack {
                Spacer()
                Button("Quit Scrollie") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            controller.refreshPermission()
        }
    }
}

private struct StatusBadge: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PermissionNotice: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scrollie needs Accessibility access to adjust scroll events.")
                .font(.caption)
            Button("Open System Settings…", action: openSettings)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct SpeedSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(
                value: $value,
                in: ScrollController.factorRange,
                step: ScrollController.factorStep
            )
            .controlSize(.small)
        }
    }
}
