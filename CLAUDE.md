# Paperbooth

Native macOS photobooth: three countdown shots from an iPhone through Continuity Camera, composed into a printable 6 × 4-inch sheet. Details live in CONTEXT.md and RECOVERY.md.

## Session protocol
At the start of every session, before any new work:
1. Read CLAUDE.md, CONTEXT.md, and RECOVERY.md.
2. Check git status and recent commits. If the docs disagree with the code, flag it and fix the docs first.
3. Give a short orientation: current state, next step, open risks.

At the end of every session, after the work:
1. Update CONTEXT.md (new decisions with reasons, anything that changed).
2. Update RECOVERY.md (current state, next steps, known issues, last session).
3. Update this file with durable rules or gotchas only.
Do this before saying the work is done.

## Conventions
- One file per role in `Sources/`: camera, model, renderer, template layout, guest display, Space trigger, app/UI, self-test. Keep new code in the matching file.
- Camera session work stays on the `app.paperbooth.camera` serial queue. UI and model state change on the main thread (`BoothModel` is `@MainActor`).
- No external packages. Add a framework to the `-framework` list in `build.sh` if a new one is needed.
- Commands: build `./build.sh`, test `build/Paperbooth.app/Contents/MacOS/Paperbooth --self-test /tmp/Paperbooth-tests`.
- Add a self-test check in `SelfTest.swift` for any change to rendering or export.

## Gotchas
- `build/` is gitignored. Never commit the built app.
- Importing a Codex update from `~/Documents/Codex/2026-10-27/do-y/outputs/Paperbooth Source/`: copy only `Sources/*.swift` and `Info.plist`. Keep this repo's `build.sh` (Codex's builds to `../Paperbooth.app`) and `README.md`. Never commit files from the outputs folder itself, such as `Renamed-event-photos.csv` or event photos. Build and run the self-test before committing, and update the README version table.
- `Info.plist` needs `NSCameraUsageDescription` and `NSCameraUseContinuityCameraDeviceType`, or the app crashes when it asks for camera access (first key) or never finds the iPhone (second key).
- Sheet geometry (1800 × 1200, 800 × 500 cells) is documented for users in `docs/USER-GUIDE.md`. Change both together.
- The portfolio card for this project is in `~/Dev projects/portfolio/index.html`, Other Projects panel. Update it if features change. Pushing the portfolio's `main` deploys the live site.

## Preferences
- Concise, direct writing. No filler. No em dashes.
- Flag uncertainty instead of guessing.
