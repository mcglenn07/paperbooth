# Paperbooth: Context

Last updated: 2026-10-31

## Purpose
A native macOS photobooth for events. An iPhone on a mount acts as the camera through Continuity Camera; guests get three countdown photos composed into a printable 6 × 4-inch sheet with an event-title cell.

## Goals and non-goals
- Goal: run a photobooth at an event from one Mac and one iPhone, with no internet.
- Goal: print-ready output: 1800 × 1200 px JPEG at 300 dpi, plus the three full-resolution photos.
- Goal: custom artwork per event (background, title cell, transparent overlay, calibrated templates) without code changes.
- Goal: guests can watch themselves on a separate screen (Guest View).
- Goal: a host or clicker can pace each pose (Manual mode).
- Goal: all finished sheets land in one folder, ready to pick for uploading.
- Non-goal: sharing service, accounts, or uploads.
- Non-goal: freeform layout editor. The four cells are fixed.
- Non-goal: printer-specific integration. Printing goes through the system print dialog.
- Non-goal: kiosk lock. Full-screen mode only.
- Non-goal: App Store or notarized distribution (for now).

## Stack and architecture
- Languages / frameworks: Swift 5, SwiftUI + AppKit, AVFoundation (camera), ImageIO (JPEG + dpi metadata), UniformTypeIdentifiers. No external packages.
- Build: `build.sh` calls `xcrun swiftc` directly on `Sources/*.swift`. There is no Xcode project file. Output is an ad-hoc-signed `build/Paperbooth.app` for arm64, macOS 14+.
- Data store: `UserDefaults` (domain `local.paperbooth.mac`) for title, subtitle, theme, countdown, `mirrorPhotos`, `manualMode`, backups folder, `finishedSheetsFolder`, guest display, and artwork file paths. Session photos stay in memory until saved.
- Hosting / deployment: none. Local app. Source at https://github.com/mcglenn07/paperbooth (public).
- Development flow: Glenn builds features with Codex in `~/Documents/Codex/2026-10-27/do-y/outputs/Paperbooth Source/`, then the code is copied into this repo and committed. See CLAUDE.md for what to copy.
- How the pieces fit:
  - `CameraController.swift`: device discovery, still capture, and a video data output that feeds Guest View (max 1920 px, 24 fps). All session work runs on the serial queue `app.paperbooth.camera`.
  - `BoothModel.swift`: `@MainActor` session state: countdown, shots, import, save, reset, print, settings. `runCapture` takes capture and sleep closures so tests can fake the camera.
  - `SheetRenderer.swift`: draws the 1800 × 1200 sheet. Layer order: background, photos and borders, title cell, overlay.
  - `TemplateLayout.swift`: loads `<overlay>.layout.json` (three photo rects, optional base image) for calibrated templates.
  - `GuestDisplay.swift`: `GuestDisplayController` owns the Guest View window on a chosen screen and closes it if the screen disconnects.
  - `SpaceTrigger.swift`: local key monitor. In Manual mode, one Space press (no modifiers, Paperbooth window active, not in a text field) calls `triggerManualAction`. `SpacePressGate` blocks held keys and repeats.
  - `PaperboothApp.swift`: app entry, `BoothView`, Setup sheet, menu commands (Save ⌘S, Print ⌘P), quit guard for unsaved sessions.
  - `SelfTest.swift`: `--self-test <dir>` runs rendering, export, Guest View, and capture-flow checks without a camera.

## Sheet layout
Canvas 1800 × 1200, coordinates from top-left. Each cell 800 × 500. Photos are center-cropped into cells.

| Cell | X | Y |
| --- | ---: | ---: |
| Photo 1 | 80 | 80 |
| Photo 2 | 920 | 80 |
| Photo 3 | 80 | 620 |
| Event title | 920 | 620 |

A calibrated template's `.layout.json` replaces the three photo positions and hides the built-in borders and title cell. Format is in `docs/USER-GUIDE.md`.

Print area: 432 × 288 pt (6 × 4 in), landscape.

## Key decisions
| Date | Decision | Reason |
|------|----------|--------|
| 2026-10-27 | Built with Codex (Glenn's first Codex project) as a native Swift app | Needs direct camera access and native printing on a Mac |
| 2026-10-27 | iPhone through Continuity Camera as the camera | Glenn's event setup: iPhone mounted horizontally, rear cameras facing guests |
| 2026-10-27 | Plain `swiftc` build script, no Xcode project | No dependencies, so one script is enough (inferred; Codex's choice) |
| 2026-10-27 | Fixed 6 × 4 in, 300 dpi, four-cell layout | Matches standard 4 × 6 photo paper |
| 2026-10-27 | Fully offline, no accounts | Event use without relying on venue internet; no data leaves the Mac |
| 2026-10-27 | Camera permission requested only on **Enable camera** | No permission prompt at launch |
| 2026-10-27 | Repo moved from the Codex output folder to `~/Dev projects/paperbooth`; build output goes to `build/` (gitignored) | Matches Glenn's other projects; keeps build artifacts out of git |
| 2026-10-27 | Public repo, listed under **Other Projects** on the portfolio | Not AI, not WordPress, not a kids' game |
| 2026-10-28 | v0.2: calibrated templates with a companion `.layout.json` | Event artwork had photo openings that did not match the default cells |
| 2026-10-28 | v0.2.2: one overlay, `halloween-frame-transparent.png`, is recognized by SHA-256 and gets built-in placement | It was selected from Downloads without its layout file. Only that exact file is affected |
| by 2026-10-30 | v0.3: one flat finished-sheets folder with unique, stable filenames | Picking sheets to upload is easier from one folder; re-saving must not create duplicates |
| by 2026-10-30 | v0.4: Guest View on an extended display, fed by a video data output | Guests watch a separate screen; a second preview layer on the same camera was avoided |
| by 2026-10-31 | v0.5: Manual mode with a local Space trigger, no global keyboard hook | Lets a host or clicker pace poses; a local monitor needs no extra macOS permission |
| 2026-10-31 | Only `Sources/` and `Info.plist` are imported from Codex | Codex's `build.sh` builds outside the repo, and its README and output folder hold local or event-specific files |

## Rejected approaches
- None recorded yet.

## Constraints
- Apple Silicon only (`-target arm64-apple-macosx14.0`). Intel Macs need a build change.
- macOS 14 or later.
- Needs Xcode or the Command Line Tools for `swiftc` and `codesign`.
- Ad-hoc signature only. Other Macs will show a Gatekeeper warning.
- Continuity Camera needs the iPhone and Mac on the same Apple Account with Wi-Fi and Bluetooth on, or a USB connection.

## Glossary
- **Sheet**: the finished 1800 × 1200 composite image.
- **Cell**: one of the four 800 × 500 areas on the sheet.
- **Title cell**: the fourth cell, with editable event text or custom artwork.
- **Overlay**: a transparent 1800 × 1200 PNG drawn last, over everything.
- **Session**: one set of three photos for one group of guests. Saved to its own timestamped folder.
- **Proof**: the live sheet preview shown in the app (`BoothModel.proof`).
- **Style / theme**: built-in looks, currently **Midnight** (default) and **Warm paper**.
- **Calibrated template**: an overlay PNG plus a same-named `.layout.json` and optional base image, kept in one folder.
- **Finished sheets folder**: the one folder where every completed sheet is saved.
- **Backups folder**: optional folder that also keeps each session's three original photos.
- **Guest View**: the second window on a guest-facing display.
- **Automatic / Manual mode**: three photos per press, or one photo per press of Space or Capture photo.
