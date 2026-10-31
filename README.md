# Paperbooth

A native macOS photobooth for events. Mount an iPhone as the camera through Continuity Camera, and guests get three countdown shots composed into a printable 6 × 4-inch sheet with an event-title cell.

Current version: **0.5.1**

![Warm paper layout](docs/Warm-paper-layout.png)

## What it does

- **Two capture modes.** Automatic takes three photos in a row with a countdown before each. Manual takes one photo per press of **Space** or the capture button, so a host or a presentation clicker can pace each pose.
- **Print-ready sheets.** Exact 1800 × 1200 px, 300 dpi JPEG: photos in three cells, event title or custom artwork in the fourth. Prints through the system dialog at 6 × 4 inches.
- **Guest View.** A second window on an extended display shows guests the live camera, countdown, pose prompts, and then the finished sheet.
- **One folder of finished sheets.** Every completed sheet saves into a single folder with a unique filename, ready to pick for uploading. An optional backups folder also keeps each session's three original photos.
- **Custom artwork.** Swap the background, title cell, or a transparent overlay. Calibrated templates add a small layout file that moves the photo cells to match the artwork's openings.
- **Recovers from interruptions.** Completed shots are kept and **Continue** resumes the sequence. Unsaved sessions prompt before being cleared.
- **Works offline.** No accounts, uploads, or cloud services.

Two built-in styles, **Midnight** and **Warm paper**, plus an example [Halloween theme](themes/halloween/).

## Build

Requires macOS 14+ on Apple Silicon and Xcode (for `swiftc`). No external packages.

```sh
./build.sh
open build/Paperbooth.app
```

The script compiles `Sources/*.swift` with `swiftc` and produces an ad-hoc-signed app. It is a local build, not notarized.

Run the rendering, export, and capture-flow checks:

```sh
build/Paperbooth.app/Contents/MacOS/Paperbooth --self-test /tmp/Paperbooth-tests
```

A pass prints several `PASS:` lines and exits with code 0.

## How it's built

SwiftUI and AppKit for the interface, AVFoundation for camera discovery and capture, ImageIO for JPEG output with 300 dpi metadata.

| File | Role |
| --- | --- |
| `CameraController.swift` | Camera discovery, still capture, and the video frames for Guest View. Session work runs on a serial queue. |
| `BoothModel.swift` | Session state: countdown, shots, save, reset, print, settings. Runs on the main thread. |
| `SheetRenderer.swift` | Draws the sheet: center-cropped photo cells, title cell, artwork layers. |
| `TemplateLayout.swift` | Reads a calibrated template's `.layout.json` and optional base image. |
| `GuestDisplay.swift` | The Guest View window on a chosen display. |
| `SpaceTrigger.swift` | Turns a single Space press into one capture in Manual mode. Ignores held keys and repeats. |
| `PaperboothApp.swift` | App entry point, booth window, and Setup sheet. |
| `SelfTest.swift` | Automated checks that run without a camera. |

Camera access is requested only when the user clicks **Enable camera**. Settings live in `UserDefaults` under `local.paperbooth.mac`. The capture code takes the camera and timer as parameters, so the self-tests can run real countdown, cancellation, and error paths with fake photos.

## Before an event

Camera, display, and printing need a test with your own devices:

- Approve camera access and select the actual iPhone.
- Complete three shots; check framing, orientation, mirroring, and image quality.
- Disconnect and reconnect the camera, then check the retained shots and **Continue**.
- Cancel during a countdown and during a capture.
- If using Guest View: open it on the guest monitor, run a session, then unplug and reconnect the monitor.
- If using Manual mode with a clicker: confirm one click takes exactly one photo.
- Choose a finished sheets folder and confirm sheets save there.
- Make one physical 6 × 4-inch print on the intended printer.

Full setup, artwork coordinates, templates, and printing: [docs/USER-GUIDE.md](docs/USER-GUIDE.md).

## Version history

| Version | Change |
| --- | --- |
| 0.5.1 | In Manual mode, Space on the finished sheet acts as **Next guests** without starting a countdown. |
| 0.5.0 | Manual capture mode with a Space-key trigger. |
| 0.4.1 | Both viewers show the finished sheet until **Next guests**. |
| 0.4.0 | Guest View on an extended display. |
| 0.3.0 | Finished sheets folder: all completed sheets in one place. |
| 0.2.x | Calibrated templates, remembered mirror setting, unique sheet filenames. |
| 0.1.0 | First working version. |

## Scope

Paperbooth intentionally has no sharing service, accounts, freeform layout editor, printer-specific integration, or kiosk lock. Full-screen mode is available.
