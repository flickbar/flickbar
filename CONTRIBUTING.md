# Contributing to Flickbar

Thanks for helping! Bug reports, ideas, translations and code are all welcome.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems go through
[SECURITY.md](SECURITY.md), not public issues.

## Clean-room rule

Flickbar is an independent project written from scratch. Contributions must be your own work: don't submit
code, assets or text copied from other apps, or derived from decompiling or disassembling them.

## Reporting bugs and suggesting features

[Open an issue](https://github.com/flickbar/flickbar/issues/new/choose) and fill in the form. Search existing
issues first. For bugs, the macOS version, Mac and trackpad model, and the Flickbar version (Settings →
About) help most.

## Setting up

You need macOS 14 or later and Xcode 26 or later (the full app; the build compiles the icon with `actool`).

```sh
git clone https://github.com/flickbar/flickbar.git
cd flickbar
swift test               # unit tests, no permissions needed
./scripts/bundle.sh      # builds build/Flickbar.app
open build/Flickbar.app
```

Window control needs Accessibility permission, and macOS ties it to the app's signature. See *Keeping the
permission across rebuilds* in the [README](README.md#keeping-the-permission-across-rebuilds) to avoid
re-granting it after every build.

The gesture logic lives in `Sources/FlickbarCore` (no AppKit, fully unit-tested); the app layer is in
`Sources/Flickbar`. `./scripts/livetest.sh` drives the running app end to end; it moves windows and the
pointer for about a minute, so leave the Mac alone while it runs.

## Sending a pull request

1. Open or pick an issue first so we can agree on the approach, especially for new features.
2. Fork, then branch from `main`: `fix/<issue>-short-name` or `feat/<issue>-short-name`.
3. Keep the change focused: one issue per pull request, with tests for new logic in `FlickbarCore`.
4. Run `swift test`, and try the change in the built app.
5. Write [Conventional Commit](https://www.conventionalcommits.org) messages that mention the issue,
   e.g. `fix: ignore taps on the Dock (#42)`.
6. If the change is something users would notice (a feature, a fix, a changed default), add a line under
   `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md), in the *Added*, *Changed* or *Fixed* group. Write it for
   users, not developers: what they can now do, or what works better.
7. Open the pull request against `main` and fill in the template, including `Closes #<issue>`.

Pull requests are squash-merged. There's no automated CI, so please say in the description how you tested.

## Changelog and releases

[CHANGELOG.md](CHANGELOG.md) follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each version's
section is shown everywhere: as the GitHub release notes, in the update window, and in the app's *What's New*
(shown once after an update, and from the menu or *Settings → About*). To release, rename `## [Unreleased]` to
`## [x.y.z] - YYYY-MM-DD`, add a new empty `## [Unreleased]` above it, update the compare links at the bottom,
commit, then run `./scripts/release.sh x.y.z`. It refuses to run without notes for that version; check them
first with `./scripts/changelog-section.sh x.y.z`.

## Translations

Flickbar speaks English, French and Persian. Run `scripts/update-strings.sh`, then edit
`Resources/Localizable.xcstrings` (Xcode opens it in its String Catalog editor). To add a language, open an
issue first. Please have a fluent speaker check the wording.

## License

Flickbar is [GPL-3.0-or-later](LICENSE). By contributing you agree your work is released under that license.
