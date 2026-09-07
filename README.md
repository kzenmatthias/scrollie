# Scrollie

A tiny macOS menu bar app that slows down your mouse's scroll wheel below the slowest
setting System Settings allows. Built for the Logitech MX Master 3S, works with any mouse.
A free replacement for the one SteerMouse feature I actually used.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Scroll wheel speed** from 5 % to 100 % of the system speed
- **Thumb wheel speed** adjustable separately (defaults to unchanged)
- **Trackpad and Magic Mouse untouched** — only classic wheel events are modified
- **On/off switch** in the menu, settings are remembered
- **Launch at login** support
- No kernel extension, no driver, no Logi Options+ needed

## How it works

Scrollie installs a session-wide `CGEventTap` for scroll wheel events. Wheel events are
"line" based: macOS has already applied its acceleration curve when the event reaches the
tap, but a tick never becomes less than about one line, which is why the slowest system
setting still feels fast on a high-resolution wheel.

Scrollie rewrites each wheel event into a pixel-precise ("continuous") event, the kind a
trackpad produces, and scales the distance by your chosen factor. Because that happens
in userland the app needs **Accessibility** access and nothing else.

## Building

Requires Xcode 15+ (or the Command Line Tools) on macOS 14+.

```bash
./scripts/build.sh            # builds build/Scrollie.app
./scripts/build.sh --install  # also copies it to /Applications and launches it
```

The first launch asks for Accessibility access. Grant it in
System Settings > Privacy & Security > Accessibility; Scrollie picks it up automatically
within a couple of seconds.

To hack on it in Xcode: `open Package.swift`. Running from Xcode works without the bundle,
but then Xcode itself needs the Accessibility grant.

### Signing

The build script signs with the first "Apple Development" identity in your keychain, so
the Accessibility grant survives rebuilds. Without such an identity it falls back to ad-hoc
signing; every rebuild then produces a new signature, and macOS treats it as a new app:
remove Scrollie from the Accessibility list and add it again. Pick an identity explicitly
with:

```bash
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/build.sh --install
```

## Architecture

- **ScrollieApp** — `MenuBarExtra` entry point
- **ScrollMenuContent** — the menu: sliders, on/off switch, launch at login
- **ScrollController** — `@Observable` settings persisted in `UserDefaults`, owns the tap
- **ScrollTap** — the `CGEventTap` that rewrites scroll wheel events
- **AccessibilityPermission** — permission check and prompt

## License

MIT
