//
//  ScrollController.swift
//  Scrollie
//

import Foundation
import Observation

/// Observable state for the menu, persisted in UserDefaults, driving the event tap.
@Observable
final class ScrollController {
    static let shared = ScrollController()

    /// Lowest selectable speed. 5 % of a normal wheel tick is already very slow.
    static let factorRange: ClosedRange<Double> = 0.05...1.0
    static let factorStep = 0.05

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            apply()
        }
    }

    /// Multiplier for the main scroll wheel (1.0 = unchanged).
    var verticalFactor: Double {
        didSet {
            defaults.set(verticalFactor, forKey: Keys.vertical)
            apply()
        }
    }

    /// Multiplier for the thumb wheel / horizontal scrolling (1.0 = unchanged).
    var horizontalFactor: Double {
        didSet {
            defaults.set(horizontalFactor, forKey: Keys.horizontal)
            apply()
        }
    }

    private(set) var hasAccessibilityAccess: Bool
    /// True while the event tap is installed and modifying events.
    private(set) var isActive = false

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let tap = ScrollTap()
    @ObservationIgnored private var permissionTimer: Timer?

    private enum Keys {
        static let enabled = "isEnabled"
        static let vertical = "verticalFactor"
        static let horizontal = "horizontalFactor"
    }

    private init() {
        defaults.register(defaults: [
            Keys.enabled: true,
            Keys.vertical: 0.3,
            Keys.horizontal: 1.0,
        ])
        isEnabled = defaults.bool(forKey: Keys.enabled)
        verticalFactor = defaults.double(forKey: Keys.vertical)
        horizontalFactor = defaults.double(forKey: Keys.horizontal)
        hasAccessibilityAccess = AccessibilityPermission.isGranted
    }

    /// Call once at launch: asks for Accessibility access and installs the tap as soon as it is granted.
    func start() {
        if !hasAccessibilityAccess {
            AccessibilityPermission.request()
            watchPermission()
        }
        apply()
    }

    func refreshPermission() {
        let granted = AccessibilityPermission.isGranted
        if granted != hasAccessibilityAccess {
            hasAccessibilityAccess = granted
            apply()
        }
        if !granted {
            watchPermission()
        }
    }

    private func watchPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if AccessibilityPermission.isGranted {
                timer.invalidate()
                self.permissionTimer = nil
                self.hasAccessibilityAccess = true
                self.apply()
            }
        }
    }

    private func apply() {
        tap.verticalFactor = verticalFactor
        tap.horizontalFactor = horizontalFactor

        if isEnabled && hasAccessibilityAccess {
            isActive = tap.start()
        } else {
            tap.stop()
            isActive = false
        }
    }
}
