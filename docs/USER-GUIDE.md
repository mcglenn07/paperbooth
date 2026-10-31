# Paperbooth user guide

For version 0.5.1. Paperbooth runs on Apple Silicon Macs with macOS 14 or later.

## Set up

1. Build the app with `./build.sh` (see the main README), then open **build/Paperbooth.app**.
2. Enter your event title and a date or short message. Open **Setup** to choose a background, title-cell artwork, or transparent overlay.
3. In **Setup → Saving & printing**, click **Choose sheets folder…**. Every finished sheet saves into this one folder. Optionally click **Choose backups folder…** to also keep the three original photos from each session.
4. Mount your iPhone horizontally with its rear cameras facing the guests. Turn on Continuity Camera on the iPhone and sign in to the same Apple Account on the phone and Mac. Keep Wi-Fi and Bluetooth on, or connect the iPhone by USB. Lock the phone.
5. Click **Enable camera**, approve macOS camera access, and choose your iPhone in **Setup** if needed.
6. Click **Start session**. The app takes three photos with a countdown before each. Review the sheet, save or print it, then click **Next guests**.

To test the layout without a camera, use **Import 3 photos…**. Choose exactly three files; they are placed in filename order. **Retake all** clears the current session after offering to save it. If capture is interrupted, the shots already taken are kept and **Continue** resumes. **Save session** can also save the photos from a partly finished session (this needs a backups folder).

## Capture modes

Choose the mode in **Setup → Camera & countdown → Capture mode**. The choice is remembered after quitting.

- **Automatic** (default): one press of **Start session** takes all three photos in a row.
- **Manual**: each press of **Space** or **Capture photo** runs one countdown and takes one photo. Press again when guests are ready for the next pose. After photo three, the sheet is composed and saved (if a sheets folder is set) and stays on screen.

In Manual mode, while the finished sheet is on screen, Space acts as **Next guests** and returns to the live camera. That press does not start a countdown; press Space again for the next group's first photo. If the sheet is not saved yet, the usual save or discard prompt appears first.

### Using a clicker

A presentation clicker or remote works if another app maps one click to a plain **Space** press and release, with no modifier keys. Pairing and mapping the clicker happen outside Paperbooth.

- Presses during a countdown or capture are ignored, not queued. Holding the key does not repeat.
- Space only triggers capture when the booth window or Guest View is the active window. It is not a system-wide shortcut.
- Space types normally in text fields and does nothing while Setup or a dialog is open.
- Before the event, finish editing any text, then click the camera view so it has keyboard focus.

## Guest View on another display

1. Connect the guests' monitor or TV. In macOS **System Settings → Displays**, set it to **Extended display**, not mirroring.
2. In **Setup → Guest display**, choose that monitor under **Display for guests**.
3. Click **Show Guest View**, then **Done**. The guest screen fills with the camera preview, countdown, and pose prompts. Run sessions from the main window as usual.
4. After photo three, both the guest screen and the main viewer show the finished sheet until **Next guests**.
5. To close it, click **Close Guest View** in the main window, or press Escape while the guest window is active.

**Preview in window** shows the guest layout in a normal window, for trying it without a second monitor.

Guest View uses the same camera and mirror setting, and keeps the current photo cell's framing, so it may show black bars around the preview. The chosen display is remembered, but Guest View only opens when you ask. Unplugging the guest monitor closes Guest View without resetting the session; reconnect and open it again. No screen-recording permission is needed.

## Finished sheets folder

The sheets folder is remembered after quitting. Each completed session saves one 1800 × 1200 JPEG directly in that folder, with no subfolders. Click **Open finished sheets** on the main screen to see them, for example when picking photos to upload.

- Filenames are unique per session, like `sheet-6x4_2026-10-31_14-30-05_A1B2C3.jpg`, so sheets from different sessions never overwrite each other.
- Saving the same session again updates its existing file instead of adding a copy.
- If you have a backups folder but have not chosen a sheets folder, sheets collect in a **Finished Sheets** folder inside the backups folder.
- Changing the sheets folder does not move sheets saved earlier. If a finished sheet is on screen when you choose a new folder, you can save it there too.
- Incomplete sessions never go into the sheets folder.
- If saving fails, the session stays marked unsaved. Choose a folder that is available and save again.

## Your sheet

- Landscape, 6 inches wide × 4 inches high.
- Finished JPEG: **1800 × 1200 pixels, 300 dpi**.
- Photo 1 at top left, photo 2 at top right, photo 3 at bottom left.
- Event title or custom artwork at bottom right.
- With a backups folder, each session also keeps its three full-resolution photos. Saved JPEGs are re-encoded at high quality, not byte-for-byte copies of imported files.
- Photos are center-cropped to fit the cells. Leave some room around guests; the backed-up photos keep the full frame.
- **Mirror preview and captured photos** controls both the preview and the saved photos, when the camera supports it. The setting is remembered.

The preview images in this folder show the built-in **Midnight** and **Warm paper** styles. Their numbered cells are placeholders.

## Replace the artwork

In **Setup → Replaceable artwork**:

- **Background:** an 1800 × 1200 image. It sits behind the photos and title cell. Other proportions are center-cropped.
- **Title cell:** an 800 × 500 image that replaces the whole event-title cell, including its text.
- **Overlay:** an 1800 × 1200 transparent PNG, drawn last across the whole sheet. Keep the photo openings transparent, or the overlay will cover the photos.

Use **Reset** beside an item to go back to the original design. Paperbooth remembers where each file is, so keep the artwork in the same place.

For custom artwork, these are the default cell positions, measured from the **top-left corner** of the canvas:

| Cell | X | Y | Width | Height |
| --- | ---: | ---: | ---: | ---: |
| Photo 1 | 80 | 80 | 800 | 500 |
| Photo 2 | 920 | 80 | 800 | 500 |
| Photo 3 | 80 | 620 | 800 | 500 |
| Event title | 920 | 620 | 800 | 500 |

The default photo borders extend 8 px outside each photo cell. Use an overlay to cover or restyle them.

### Calibrated templates

When an overlay's photo openings do not match the default cells, add a layout file next to it with the same name and `.layout.json` in place of `.png`. For `my-frame.png`, that is `my-frame.layout.json`:

```json
{
  "canvasWidth": 1800,
  "canvasHeight": 1200,
  "baseImage": "my-frame-base.png",
  "photos": [
    { "x": 120, "y": 100, "width": 760, "height": 440 },
    { "x": 920, "y": 100, "width": 720, "height": 440 },
    { "x": 120, "y": 585, "width": 760, "height": 425 }
  ]
}
```

- `canvasWidth` and `canvasHeight` must be 1800 and 1200.
- `photos` lists exactly three cells, in order, each at least 20 px wide and tall and inside the canvas.
- `baseImage` is optional. It is a background image drawn under the photos, and must be in the same folder.
- With a template, the built-in borders and title cell are hidden, so put the event title in the template's artwork. The camera preview matches each cell's shape.

Select the overlay PNG in **Setup → Overlay**; Paperbooth loads the layout file and base image automatically. Keep all of a template's files together. If the layout file is invalid or the base image is missing, Paperbooth shows an error and keeps the current template. Choosing an ordinary PNG with no layout file returns to the standard layout.

## Print

Click **Print sheet…** after all three photos are in. Choose the printer and its **4 × 6 / 6 × 4-inch** paper, landscape. Use borderless mode if the printer supports it. Paperbooth asks for a 6 × 4-inch print area, but printer drivers can change the paper size and margins, so make one test print before the event.

## Before the event

Test with your own devices: iPhone capture, Guest View on the real monitor, the clicker if you use one, saving to your sheets folder, and one physical print. The full checklist is in the main README.

Paperbooth is a local app, not an App Store or notarized download. It uses no accounts, uploads, or cloud services.

Apple's Continuity Camera setup guide: [Use your iPhone as a webcam](https://support.apple.com/en-us/102546).
