# Flickbar

Manage macOS windows with trackpad gestures on their title bars. Free and open source.

Put the pointer on a window's title bar and swipe with two fingers:

| Gesture on title bar | Result |
|---|---|
| Swipe left / right | Snap to left / right half |
| Swipe up | Fill the screen |
| Swipe down | Minimize |
| Swipe left or right, then up or down (either order) | Snap to that quarter |
| Pinch in | Close window |
| Pinch out | Toggle full screen |
| Double-tap with two fingers | Center window |

Gestures that start anywhere else are passed through untouched, so normal scrolling and zooming keep working.

## Requirements

- macOS 14 Sonoma or later, with a trackpad
- Accessibility permission (Flickbar asks on first launch)
- For double-tap: *System Settings → Trackpad → Smart zoom* enabled. For pinch: *Zoom in or out* enabled.

## Build and run

```sh
swift test               # unit tests for the gesture recognizer and snap geometry
./scripts/bundle.sh      # builds build/Flickbar.app (universal, ad-hoc signed)
open build/Flickbar.app
```

Ad-hoc signed builds get a new signature each time, so after rebuilding you may need to remove and re-add
Flickbar under *System Settings → Privacy & Security → Accessibility*.

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
