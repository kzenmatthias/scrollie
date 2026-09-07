//
//  ScrollTap.swift
//  Scrollie
//

import CoreGraphics
import Foundation

/// Intercepts scroll wheel events system-wide and scales their distance.
///
/// How it works: mouse wheels deliver "line" based events (`scrollWheelEventIsContinuous == 0`).
/// macOS has already applied its acceleration curve by the time the event reaches a session
/// event tap, but the result is never less than about one line per tick, which is why the
/// slowest setting in System Settings is still too fast for a high-resolution wheel like the
/// one on the MX Master 3S.
///
/// We rewrite each wheel event into a pixel-precise ("continuous") event, the same kind a
/// trackpad produces, so we can hand apps an arbitrarily small distance. Trackpad and Magic
/// Mouse events are already continuous and are passed through untouched.
final class ScrollTap {
    /// Multiplier for the main wheel (axis 1). 1.0 leaves events unchanged.
    var verticalFactor = 1.0
    /// Multiplier for the thumb wheel / horizontal axis (axis 2). 1.0 leaves events unchanged.
    var horizontalFactor = 1.0

    private(set) var isRunning = false
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var verticalRemainder = 0.0
    private var horizontalRemainder = 0.0

    /// AppKit treats one line of a non-continuous wheel event as roughly 10 points.
    private static let pointsPerLine = 10.0

    /// Installs the tap on the main run loop. Returns false when Accessibility access is missing.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        self.port = port
        self.source = source
        isRunning = true
        return true
    }

    func stop() {
        guard isRunning, let port, let source else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(port)
        self.port = nil
        self.source = nil
        verticalRemainder = 0
        horizontalRemainder = 0
        isRunning = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables a tap that responds too slowly; just switch it back on.
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return passthrough
        case .scrollWheel:
            break
        default:
            return passthrough
        }

        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else {
            return passthrough
        }

        let vertical = lines(of: event, integer: .scrollWheelEventDeltaAxis1, fixed: .scrollWheelEventFixedPtDeltaAxis1)
        let horizontal = lines(of: event, integer: .scrollWheelEventDeltaAxis2, fixed: .scrollWheelEventFixedPtDeltaAxis2)

        let verticalUnchanged = vertical == 0 || verticalFactor == 1
        let horizontalUnchanged = horizontal == 0 || horizontalFactor == 1
        guard !(verticalUnchanged && horizontalUnchanged) else {
            return passthrough
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        write(
            points: vertical * Self.pointsPerLine * verticalFactor,
            to: event,
            integer: .scrollWheelEventDeltaAxis1,
            fixed: .scrollWheelEventFixedPtDeltaAxis1,
            point: .scrollWheelEventPointDeltaAxis1,
            remainder: &verticalRemainder
        )
        write(
            points: horizontal * Self.pointsPerLine * horizontalFactor,
            to: event,
            integer: .scrollWheelEventDeltaAxis2,
            fixed: .scrollWheelEventFixedPtDeltaAxis2,
            point: .scrollWheelEventPointDeltaAxis2,
            remainder: &horizontalRemainder
        )
        return passthrough
    }

    /// The fixed-point field carries the accelerated, fractional line count. Fall back to the
    /// integer field for drivers that leave it empty.
    private func lines(of event: CGEvent, integer: CGEventField, fixed: CGEventField) -> Double {
        let fixedValue = event.getDoubleValueField(fixed)
        if fixedValue != 0 {
            return fixedValue
        }
        return Double(event.getIntegerValueField(integer))
    }

    private func write(
        points: Double,
        to event: CGEvent,
        integer: CGEventField,
        fixed: CGEventField,
        point: CGEventField,
        remainder: inout Double
    ) {
        let lines = points / Self.pointsPerLine

        // Continuous events: point delta in pixels, fixed-point delta in (fractional) lines,
        // and a legacy integer line count. The integer field would round tiny movements to
        // zero, so carry the fraction over to the next event; drop it on a direction change.
        event.setDoubleValueField(point, value: points)
        event.setDoubleValueField(fixed, value: lines)

        if lines != 0, (lines < 0) != (remainder < 0) {
            remainder = 0
        }
        remainder += lines
        let whole = remainder.rounded(.towardZero)
        remainder -= whole
        event.setIntegerValueField(integer, value: Int64(whole))
    }
}

private func scrollTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let tap = Unmanaged<ScrollTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
