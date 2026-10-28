# Flickbar

Manage macOS windows with trackpad gestures on their title bars. Free and open source.

Put the pointer on a window's title bar and swipe with two fingers:

| Gesture on title bar | Result |
|---|---|
| Swipe left / right | Snap to left / right half |
| Swipe up | Fill the screen |
| Swipe down | Restore the size from before Flickbar snapped it, otherwise minimize |
| Swipe left or right, then up or down (either order) | Snap to that quarter |
| Pinch in | Close window |
| Pinch out | Toggle full screen |
| Double-tap with two fingers | Center window |
| Hold ⌘ and swipe in any direction | Move window to the display on that side |

A haptic tick confirms when the gesture so far maps to an action; it runs when you lift your fingers.
Press Esc before lifting to cancel.
Gestures that start anywhere else are passed through untouched, so normal scrolling and zooming keep working.

The menu bar icon has options for gaps between snapped windows and launching at login.

## Requirements

- macOS 14 Sonoma or later, with a trackpad
- Accessibility permission (Flickbar asks on first launch)
- For double-tap: *System Settings → Trackpad → Smart zoom* enabled. For pinch: *Zoom in or out* enabled.

## Build and run

```sh
swift test               # unit tests for the gesture recognizer and snap geometry
./scripts/bundle.sh      # builds build/Flickbar.app (universal)
open build/Flickbar.app
```

macOS ties the Accessibility permission to the app's code signature. Without a signing certificate the
script signs ad-hoc, which produces a new signature on every build: the toggle in System Settings stays on
but no longer applies, and Flickbar does nothing. Either remove Flickbar from *System Settings → Privacy &
Security → Accessibility* (the **−** button) and grant it again after each build, or get a stable
signing identity once. The script picks the first valid *Developer ID Application*, *Apple Development*
or `Flickbar Local Signing` identity (override with `SIGN_IDENTITY=...`):

- **Apple Development (free):** *Xcode → Settings → Accounts →* your Apple ID *→ Manage Certificates… → + →
  Apple Development*. Works with a free Personal Team.
- **Or self-signed:** *Keychain Access → Certificate Assistant → Create a Certificate…*, name
  `Flickbar Local Signing`, Identity Type *Self Signed Root*, Certificate Type *Code Signing*.

Rebuild, then grant Accessibility one last time. Later builds keep the permission.

Flickbar logs to the unified log under the subsystem `io.github.flickbar.Flickbar`
(`log stream --predicate 'subsystem == "io.github.flickbar.Flickbar"'`).

## How it works

- A Core Graphics event tap receives scroll and magnify events system-wide. Only events with a touch
  phase are considered, which filters out mouse wheels.
- When a gesture begins, the Accessibility API finds the window under the pointer and checks whether the
  pointer is inside its title bar (derived from the position of the window's close button).
- `FlickbarCore.GestureRecognizer` turns the finger movement into strokes (`left`, `up`, `pinchIn`, …);
  each change of direction starts a new stroke. When the fingers lift, `ActionMap` picks the action and
  `SnapGeometry` computes the target frame.

## Project

Flickbar is an independent project, written from scratch. It is not affiliated with any other
window-management app. Contributions must be your own work: please don't submit code, assets or text
copied from other apps or derived from decompiling them.

## License

[GPL-3.0-or-later](LICENSE)
