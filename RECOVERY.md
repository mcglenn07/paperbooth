# Paperbooth: Recovery

Last updated: 2026-10-31

## Current state
Version 0.5.1.

Works (verified 2026-10-31):
- `./build.sh` builds `build/Paperbooth.app`.
- `--self-test` passes all seven groups: rendering and export, finished-sheets folder, mirror and filenames, Guest View rendering, finished-sheet review, Manual mode and the Space trigger, and the original sheet checks.

Features since 0.1: calibrated templates, finished-sheets folder, Guest View on an extended display, Manual capture mode with a Space or clicker trigger. Version history is in `README.md`.

Not tested by Claude:
- Capture from a real iPhone through Continuity Camera.
- Guest View on a real second monitor, including unplug and reconnect.
- A clicker mapped to Space.
- A physical 6 × 4 print.

TBD: whether Glenn has run any of these at an event. Record results here.

## Next steps
1. Run the hardware checklist in `README.md` ("Before an event") and write the results under Current state.
2. Make one test print on the intended printer with 4 × 6 paper, landscape, borderless if supported.
3. TBD: decide whether to publish a downloadable build (GitHub release with a zipped app).

## How to get running from zero
```sh
git clone https://github.com/mcglenn07/paperbooth.git
cd paperbooth
./build.sh
open build/Paperbooth.app
```
No environment variables or secrets.

## How to verify
```sh
build/Paperbooth.app/Contents/MacOS/Paperbooth --self-test /tmp/Paperbooth-tests
```
Passing output is seven lines starting with `PASS:` and exit code 0. A failure prints `FAILED: <error>` and exits 1.

Manual check without a camera: open the app, click **Import 3 photos…**, choose three images, and confirm they land in filename order.

## Known issues
- Three crash reports on 2026-10-27 between 21:05 and 21:09, during the Codex build (`~/Library/Logs/DiagnosticReports/Paperbooth-2026-10-27-*.ips`). All are SIGABRT in `HIServices _RegisterApplication` at AppKit startup, before any Paperbooth code ran. Likely cause: launched from a sandbox without window-server access. Not reproduced since. Unverified.
- Artwork and template files are remembered by absolute path. Moving or deleting them means they will not reload on next launch. A template's overlay, `.layout.json`, and base image must stay in one folder.
- Session photos live in memory until saved. Quitting or a crash before saving loses them. The quit guard warns about unsaved sessions.
- Printer drivers can override paper size and margins. Test print before every new printer.
- Manual-mode Space only works while a Paperbooth window is active. If another app takes focus, the clicker stops triggering.

## If something is lost or broken
- Backups / copies: GitHub `mcglenn07/paperbooth` (`main`). Codex's working copy, including a prebuilt `Paperbooth.app`, `Paperbooth.zip`, and the event templates, is in `~/Documents/Codex/2026-10-27/do-y/outputs/`.
- Roll back: `git log`, then `git revert <commit>`, or `git checkout <commit> -- <file>`.
- Reset app settings: `defaults delete local.paperbooth.mac`.
- Secrets: none used.

## Last session
2026-10-31: Imported v0.5.1 from the Codex folder (Manual mode and Space trigger), built, ran the self-test, and pushed. Rewrote `README.md` and `docs/USER-GUIDE.md` to cover v0.2 to v0.5.1 and updated these continuity files. Hardware testing still not recorded.
