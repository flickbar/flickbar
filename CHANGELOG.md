# Changelog

All notable changes to Flickbar are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Flickbar uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-11-08

### Added

- **简体中文 and 繁體中文.** Flickbar now speaks Simplified and Traditional Chinese. It follows your Mac's language, or choose one in *Settings → General → Language*.
- **Gestures that press keys.** Set a title-bar gesture to **Send Keys…** in **Settings → Gestures** and record a key combination, such as ⌘C or ⌘V. The gesture brings its window to the front and presses those keys in it.
- **Español.** Flickbar now speaks Spanish, and the French has been reviewed.

## [1.1.0] - 2026-11-04

### Added

- **Adjust swipes before lifting your fingers.** By default, reversing a swipe selects the new direction; perpendicular swipes combine into a quarter, and reversing the second swipe of a quarter swaps it (right, up, then down gives the bottom-right quarter). Any other swipe starts a new gesture. Turn off **Follow swipe direction changes** in **Settings → Gestures** to use swipe-back-to-cancel. Esc still cancels in either mode, and reversing a pinch always cancels.

## [1.0.0] - 2026-11-02

### Added

- **What's New.** After an update, Flickbar shows what changed in the new version. Open it again any time with *What's New…* in the menu or in *Settings → About*.
- **Dark, Clear and Tinted icons.** The app icon now has versions for macOS's Dark, Clear and Tinted looks, made to stay easy to see on dark wallpapers and in the Dock.
- **A proper installer download.** Downloading Flickbar now gets you a disk image: open it and drag Flickbar to Applications.
- **Website and support links.** *Settings → About* now links to Flickbar's website, and to a page where you can support Flickbar if you'd like to.

### Changed

- **Your settings are kept safe across updates.** Flickbar now keeps track of how its settings are stored, so future updates carry your gestures, shortcuts and options over.

### Fixed

- **Recording a keyboard shortcut works again.** Clicking a shortcut field and pressing keys now records them. On macOS 27, nothing was saved before.
- **Settings no longer opens already recording.** Reopening Settings from the menu used to leave the first shortcut field waiting for keys, with all Flickbar shortcuts paused.
- **Shortcuts work while a Flickbar window is in front.** Pressing a shortcut in Settings used to only beep; it now moves the window behind it.
- **Removing a keyboard shortcut works.** The ✕ next to a shortcut now deletes it, and so does pressing Escape or Delete while recording.
- **Shortcuts that couldn't be set now say why.** If a combination needs ⌃ or ⌥, is already used for another action, belongs to macOS or is held by another app, the field explains it. Your previous shortcut stays, and clicking the field lets you try another one. Combinations like ⌃⇧W and ⌘⌃R are saved. ⌘ alone (such as ⌘Q) is no longer accepted, since it would take over that key in every app.

## [0.11.0] - 2026-10-30

### Added

- **Français et فارسی.** Flickbar now speaks French and Persian. Persian is laid out right to left, and the layout pictures still point the right way. Flickbar follows your Mac's language, or choose one in *Settings → General → Language*.

### Changed

- **The original icon is back.** It's rebuilt in Apple's Icon Composer, so it gets the Liquid Glass look on macOS 26 and later.

## [0.10.0] - 2026-10-30

### Added

- **Gesture tutorial.** After you grant access, Flickbar offers a practice window that ticks off each main gesture as you do it. Open it again any time with *Gesture Tutorial…* in the menu.
- **Updates inside the app.** Choose *Check for Updates…* in the menu, or turn on daily checks in Settings (off unless you turn it on). Updates are signed, and Flickbar installs only those that match its key. Homebrew users can keep using `brew upgrade`.

### Changed

- **New icon.** Rebuilt in Apple's Icon Composer, so it gets the Liquid Glass look on macOS 26 and later.

### Fixed

- **Touch and hold works on a real trackpad.** Resting two fingers on a title bar now opens the layout grid. Before, it only worked in testing, because a resting hand sends a different signal than the test did.

## [0.9.0] - 2026-10-30

### Changed

- **Swipe down minimizes.** A swipe down on a title bar now always minimizes the window. The old behaviour (restore the size from before snapping, otherwise minimize) is still there as **Restore or Minimize**: pick it for swipe down, or any gesture or shortcut, in Settings. If you had already set Restore or Minimize on a gesture or shortcut, it keeps working as before.
- **Smoother animations.** The landing preview now grows and fades in, glides between targets, and fades out when you lift your fingers; the hold-to-grid fades in and out. With *Reduce Motion* on, it only fades.
- About now credits the author, Parsa Kamalipour.

## [0.8.0] - 2026-10-29

### Changed

- **Notarized by Apple.** Flickbar is now signed with a Developer ID and notarized, so it opens like any other app: no more *Open Anyway* in Privacy & Security.
- **One last permission reset.** The new signature means macOS treats this version as a different app for Accessibility. After updating, if gestures don't work, remove Flickbar from *System Settings → Privacy & Security → Accessibility* with **−** and add it again. Later updates keep the permission.

## [0.7.1] - 2026-10-29

### Fixed

- **Minimized windows.** Gestures now work on a minimized window's tile in the Dock: swipe up brings it back, and other title-bar gestures bring it back and snap it (swipe left for the left half). On an app's Dock icon, swipe left or right now cycles through minimized windows too, and swipe up brings the app's windows back when they're all minimized. Before, minimized windows were skipped because macOS reports them as a different kind of window.
- **Grid.** The first grid after Flickbar starts could freeze gestures for a couple of seconds; it now appears instantly.

## [0.7.0] - 2026-10-29

### Added

- **Hold-to-grid.** Rest two fingers on a window's title bar for a moment before swiping and a grid appears: the screen's three columns, each full height or as a top or bottom half. Move your fingers to pick a cell and lift them to snap the window there. Esc cancels.

### Changed

- **Redesigned Settings.** Each gesture is now a tile with a picture of where the window goes, title bar and Dock gestures sit behind one switch, the General tab opens with Flickbar's status and on/off switch, and keyboard shortcuts are grouped with the same pictures.
- Signed with the same certificate as 0.6.0, so if you're updating from 0.6.0 the Accessibility permission carries over.

## [0.6.0] - 2026-10-29

### Added

- **Update check (opt-in).** Turn on *Check for updates* in Settings → General and Flickbar looks for a new release once a day, showing *Update Available* in its menu when there is one. It's off by default; when on, it only asks GitHub for the latest release.

### Changed

- **Stable signature.** Releases are now signed with a dedicated Flickbar certificate instead of an ad-hoc signature, so the Accessibility permission survives updates from now on. Updating from 0.5 or earlier needs one last re-grant of the Accessibility permission.

## [0.5.0] - 2026-10-28

### Added

- **Dock gestures.** Use two fingers on a running app's Dock icon: swipe up to show all its windows, swipe down to hide it, swipe left or right to bring its next window to the front, pinch in to quit it.
- Every Dock gesture can be changed or turned off in *Settings → Gestures → On an app's Dock icon*.
- New action for title bars and shortcuts too: **Show App's Windows**.

## [0.4.0] - 2026-10-28

### Added

- **Keyboard shortcuts.** *Settings → Shortcuts* lets you record a shortcut for every action: halves, thirds, quarters, fill, center, restore or minimize, full screen, close, next window of the app, hide or quit the app, and moving a window to the display on any side. None are set at first, so Flickbar doesn't take keys you already use.
- Repeating a half or Fill Screen shortcut cycles through thirds, like repeating the swipe. Restore or Minimize puts back a window's size from before Flickbar moved it, whether you moved it with a gesture or a shortcut.

## [0.3.0] - 2026-10-28

### Added

- **Choose what each gesture does.** *Settings → Gestures* now has a menu for every gesture: any half, third or quarter, fill, center, full screen, close, next window of the app, hide or quit the app, or nothing. **Restore Defaults** puts everything back.
- **Gesture anywhere in a window.** Hold **⌥ Option** and the same gestures work anywhere over a window, not just on its title bar. You can switch the key to ⌃ Control or turn this off.

### Changed

- If you turned gestures off in 0.2, those choices carry over.

## [0.2.0] - 2026-10-28

### Added

- **See where the window will land.** While your fingers are on the trackpad, a highlight shows the window's destination. Turn it off in *Settings → General*.
- **Thirds.** Swipe left again on a window in the left half to make it two-thirds wide, and again for one third (the same works on the right). Swipe up again on a window that fills the screen to put it in the middle third. Handy on wide displays.

### Fixed

- **Better with apps that have size limits.** If an app won't take the requested size, its window now stays against the edge you snapped it to, and on screen.

## [0.1.0] - 2026-10-28

### Added

- First public build of Flickbar: snap, resize and move macOS windows with two-finger trackpad gestures on their title bars.
- **Gestures:** swipe left/right for halves, swipe sideways then up/down for quarters, swipe up to fill the screen, swipe down to restore or minimize, two-finger double-tap to center, pinch out for full screen, pinch in to close, and hold ⌘ while swiping to move a window to another display.
- Settings let you turn each gesture on or off, add space between windows, and keep gestures off in specific apps.

[Unreleased]: https://github.com/flickbar/flickbar/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/flickbar/flickbar/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/flickbar/flickbar/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/flickbar/flickbar/compare/v0.11.0...v1.0.0
[0.11.0]: https://github.com/flickbar/flickbar/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/flickbar/flickbar/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/flickbar/flickbar/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/flickbar/flickbar/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/flickbar/flickbar/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/flickbar/flickbar/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/flickbar/flickbar/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/flickbar/flickbar/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/flickbar/flickbar/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/flickbar/flickbar/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/flickbar/flickbar/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/flickbar/flickbar/releases/tag/v0.1.0
