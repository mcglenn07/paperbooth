# Paperbooth — first working version

A small native macOS photobooth with three photos and an event-title cell. The included designs are original; the supplied reference was used only for the arrangement.

## Open and set up

1. Build the app with `./build.sh` (see the main README), then open **build/Paperbooth.app**. This build is for Apple Silicon Macs running macOS 14 or later.
2. Enter your event title and date or short message. Open **Setup** to choose a background, title-cell artwork, or transparent overlay.
3. Choose a save folder in **Setup**. Completed sessions then save there automatically, each in a separate folder.
4. Mount your iPhone horizontally with its rear cameras facing the guests. Enable Continuity Camera on the iPhone and use the same Apple Account on the phone and Mac. Keep Wi-Fi and Bluetooth on, or connect the iPhone by USB. Lock the phone.
5. Click **Enable camera**, approve macOS camera access, and choose your iPhone in **Setup** if needed.
6. Click **Start session**. The app takes three photos with a countdown before each shot. Review the sheet, save or print it, then choose **Next guests**.

You can test the layout without a camera using **Import 3 photos…**. Choose exactly three files; they are placed in filename order. **Retake all** clears the current session after offering to save unsaved photos. If capture is interrupted, completed shots remain available and **Continue** resumes the sequence. **Save session** can also save a partially completed session's individual photos.

## Your sheet

- Landscape 6 inches wide × 4 inches high.
- Finished JPEG: **1800 × 1200 pixels, 300 dpi**.
- Photo 1 at top left, photo 2 at top right, photo 3 at bottom left.
- Editable event title or custom artwork at bottom right.
- Three separate full-resolution photos are saved alongside the completed sheet. Saved JPEGs are re-encoded at high quality, not byte-for-byte copies of imported files.
- Photos are center-cropped to fit the cells. Compose with some room around guests; individual saved photos retain the full frame.
- The **Mirror preview and captured photos** setting controls both views when supported by the selected camera.

The two preview PNGs in this folder show the included **Midnight** and **Warm paper** styles. Their numbered cells are placeholders; the app replaces them with your actual photos.

## Replace the artwork

**Background:** load an 1800 × 1200 image. It sits behind the three photos and event cell. Other proportions are center-cropped.

**Title cell:** load an 800 × 500 image to replace the entire event-title cell, including its text.

**Overlay:** load an 1800 × 1200 transparent PNG. This is drawn last, across the entire sheet. Keep the photo openings transparent. An opaque overlay will cover the photos.

For custom artwork, use these coordinates measured from the **top-left corner** of the canvas:

| Cell | X | Y | Width | Height |
| --- | ---: | ---: | ---: | ---: |
| Photo 1 | 80 | 80 | 800 | 500 |
| Photo 2 | 920 | 80 | 800 | 500 |
| Photo 3 | 80 | 620 | 800 | 500 |
| Event title | 920 | 620 | 800 | 500 |

The default photo borders extend 8 px outside each photo rectangle. Use the overlay to cover or restyle them. Use **Reset** beside an artwork item to return to the original design. Keep imported artwork at its chosen location so the app can reload it when reopened.

## Print

Click **Print…** after capturing or importing all three photos. Select the intended printer and its **4 × 6 / 6 × 4-inch paper** option, with landscape orientation. Use borderless mode if supported. The app requests a 432 × 288-point print area, equivalent to 6 × 4 inches. Printer drivers can override paper size and margins; make one test print before the event.

## What has been checked

The app compiled, its signature was verified, and its window and setup controls were opened. The three-photo import and unsaved-session reset flows were also checked in the running app. Automated checks verify output dimensions, 300 dpi metadata, image ordering and orientation, center cropping, title-art replacement, overlays, unique session folders, full and partial session exports, and resetting a session.

**iPhone capture and physical printing still need a test with your devices.** This is a local prototype, not an App Store or notarized distribution. The build included here targets Apple Silicon. No accounts, uploads, or cloud services are used by Paperbooth.

## Source and rebuild

With Xcode installed, run `./build.sh` from the repository root to build the app into `build/`. To run the rendering/export checks, invoke the built executable with `--self-test` followed by a test output directory.

Apple's Continuity Camera setup guide: [Use your iPhone as a webcam](https://support.apple.com/en-us/102546).
