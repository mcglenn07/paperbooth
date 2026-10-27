# Paperbooth: Recovery

Last updated: 2026-10-27

## Current state
Version 0.1.0, first working version.

Works (verified):
- `./build.sh` builds `build/Paperbooth.app` (checked 2026-10-27).
- `--self-test` passes: dimensions, 300 dpi, photo order and orientation, crop, title art, overlay, both styles, full and partial session saving, unique session folders, reset.
- Codex checked in the running app: window and Setup controls open, **Import 3 photos…** works, and the unsaved-session reset flow works.

Not tested yet:
- Capture from a real iPhone through Continuity Camera.
- A physical 6 × 4 print.

## Next steps
1. Run the hardware checklist in `README.md` ("Before an event") with the actual iPhone.
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
Passing output is one line starting with `PASS:` and exit code 0. A failure prints `FAILED: <error>` and exits 1.

Manual check without a camera: open the app, click **Import 3 photos…**, choose three images, and confirm they land in filename order.

## Known issues
- Three crash reports on 2026-10-27 between 21:05 and 21:09, during the Codex build (`~/Library/Logs/DiagnosticReports/Paperbooth-2026-10-27-*.ips`). All are SIGABRT in `HIServices _RegisterApplication` at AppKit startup, before any Paperbooth code ran. Likely cause: launched from a sandbox without window-server access. Not reproduced since. Unverified.
- Artwork is remembered by absolute file path. Moving or deleting the chosen image means it will not reload on next launch.
- Session photos live in memory until saved. Quitting or a crash before saving loses them. The quit guard warns about unsaved sessions.
- Printer drivers can override paper size and margins. Test print before every new printer.

## If something is lost or broken
- Backups / copies: GitHub `mcglenn07/paperbooth` (`main`). Codex's original output, including a prebuilt `Paperbooth.app` and `Paperbooth.zip`, is in `~/Documents/Codex/2026-10-27/do-y/outputs/`.
- Roll back: `git log`, then `git revert <commit>`, or `git checkout <commit> -- <file>`.
- Reset app settings: `defaults delete local.paperbooth.mac`.
- Secrets: none used.

## Last session
2026-10-27: Built with Codex. Moved into `~/Dev projects/paperbooth`, added README and continuity files, pointed the build at `build/`, pushed a public repo, and added the card to the portfolio's Other Projects tab (live). Stopped before hardware testing.
