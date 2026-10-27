import SwiftUI
import AppKit

@main
struct PaperboothApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = BoothModel()

    init() {
        if CommandLine.arguments.contains("--self-test") {
            do { try SelfTest.run(); exit(0) }
            catch { fputs("FAILED: \(error)\n", stderr); exit(1) }
        }
    }

    var body: some Scene {
        WindowGroup("Paperbooth") {
            BoothView(model: model, camera: model.camera)
                .frame(minWidth: 1060, minHeight: 720)
                .preferredColorScheme(.light)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 1240, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .saveItem) {
                Button("Save session") { model.save() }.keyboardShortcut("s").disabled(model.photos.isEmpty || model.takingPhotos)
                Button("Print sheet…") { model.printSheet() }.keyboardShortcut("p").disabled(model.photos.count != 3 || model.takingPhotos)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: BoothModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.needsSave || model.takingPhotos else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Close this booth session?"
        alert.informativeText = "This session is still running or has unsaved photos. Return to the booth to finish and save it."
        alert.addButton(withTitle: "Return to booth")
        alert.addButton(withTitle: "Quit anyway")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
    }
}

private let boothInk = Color(red: 0.09, green: 0.18, blue: 0.20)
private let boothGreen = Color(red: 0.83, green: 0.92, blue: 0.67)

struct BoothView: View {
    @ObservedObject var model: BoothModel
    @ObservedObject var camera: CameraController

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 25)).foregroundStyle(boothInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text("paperbooth").font(.system(size: 26, weight: .bold, design: .rounded)).tracking(-0.8)
                    Text("A LITTLE MOMENT, MADE TO KEEP.").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                }
                Spacer()
                Label("6 × 4 LANDSCAPE", systemImage: "rectangle").font(.system(size: 10, weight: .semibold)).tracking(1)
                    .padding(.horizontal, 14).padding(.vertical, 9).background(.white.opacity(0.7), in: Capsule())
                Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Toggle full screen")
                Button { model.showSettings = true } label: { Label("Setup", systemImage: "slider.horizontal.3") }.disabled(model.takingPhotos)
            }.buttonStyle(.borderless).padding(.horizontal, 30).padding(.top, 27).padding(.bottom, 24)

            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        smallLabel("01 / THE MOMENT")
                        Spacer()
                        Circle().fill(camera.ready ? Color.green : Color.gray).frame(width: 6, height: 6)
                        Text(camera.ready ? "CAMERA READY" : "CAMERA OFF").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    ZStack {
                        CameraPreview(session: camera.session, mirrored: model.mirrored)
                        if !camera.ready {
                            Color(red: 0.09, green: 0.16, blue: 0.18)
                            VStack(spacing: 14) {
                                Image(systemName: "camera.fill").font(.system(size: 34, weight: .light)).foregroundStyle(boothGreen)
                                Text(camera.busy ? "Connecting your camera…" : "Make room for a good memory.")
                                    .font(.system(size: 21, weight: .medium, design: .serif)).foregroundStyle(.white)
                                Text(camera.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                                    .multilineTextAlignment(.center).frame(maxWidth: 360)
                                Button(camera.permissionDenied ? "Open camera settings" : "Enable camera") {
                                    if camera.permissionDenied {
                                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                                    } else { camera.enable() }
                                }.buttonStyle(.plain).padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(boothGreen, in: Capsule()).foregroundStyle(boothInk).disabled(camera.busy || model.takingPhotos)
                            }.padding(30)
                        }
                        if let count = model.countdown {
                            Text("\(count)").font(.system(size: 120, weight: .bold, design: .rounded))
                                .foregroundStyle(.white).shadow(color: .black.opacity(0.35), radius: 15)
                        }
                        if model.flash { Color.white }
                        VStack {
                            HStack {
                                Text(model.takingPhotos ? "PHOTO \(min(model.photos.count + 1, 3)) OF 3" : "LIVE VIEW")
                                    .font(.system(size: 9, weight: .bold)).tracking(1.5)
                                    .padding(.horizontal, 12).padding(.vertical, 7).background(.black.opacity(0.35), in: Capsule())
                                Spacer()
                            }
                            Spacer()
                        }.padding(18).foregroundStyle(.white).allowsHitTesting(false)
                    }.aspectRatio(1.6, contentMode: .fit).frame(maxWidth: .infinity, maxHeight: 350)
                        .background(boothInk).clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 12) {
                        ForEach(0..<3) { index in
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.white)
                                if model.photos.indices.contains(index) {
                                    GeometryReader { geo in
                                        Image(nsImage: model.photos[index]).resizable().scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.height).clipped()
                                    }.clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "camera")
                                        Text(String(format: "%02d", index + 1)).monospacedDigit()
                                    }.font(.system(size: 13)).foregroundStyle(boothInk.opacity(0.3))
                                }
                            }.aspectRatio(1.6, contentMode: .fit)
                        }
                    }.frame(maxHeight: 86)
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.photos.count == 3 ? "Looking good." : "Your turn to shine.")
                                .font(.system(size: 25, weight: .medium, design: .serif))
                            Text(model.status).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if model.takingPhotos {
                            Button("Cancel") { model.cancel() }.buttonStyle(.bordered).controlSize(.large)
                        } else if model.photos.count == 3 {
                            primaryButton("Next guests", icon: "arrow.right") { requestReset("reset") }
                        } else {
                            primaryButton(model.photos.isEmpty ? "Start session" : "Continue", icon: "camera.fill") { model.start() }
                                .disabled(!camera.ready)
                        }
                    }.padding(.top, 4)
                    HStack {
                        Button("Import 3 photos…") { requestReset("import") }
                        if !model.photos.isEmpty { Button("Retake all") { requestReset("reset") } }
                        Spacer()
                        Text("\(model.countdownSeconds)s countdown · 3 poses").foregroundStyle(.tertiary)
                    }.font(.system(size: 11)).buttonStyle(.borderless).disabled(model.takingPhotos)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    HStack { smallLabel("02 / THE KEEPSAKE"); Spacer(); Text("1800 × 1200 PX").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary) }
                    Image(nsImage: model.proof).resizable().aspectRatio(1.5, contentMode: .fit)
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                        .padding(14).background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("Make it yours").font(.system(size: 17, weight: .semibold, design: .serif)); Spacer(); Text("EVENT DETAILS").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(.secondary) }
                        TextField("Event title", text: $model.title, axis: .vertical).lineLimit(2...3)
                            .textFieldStyle(.plain).font(.system(size: 18, weight: .semibold)).padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                            .onChange(of: model.title) { _, value in if value.count > 120 { model.title = String(value.prefix(120)) } }
                        TextField("Date or a short message", text: $model.subtitle).textFieldStyle(.roundedBorder)
                            .onChange(of: model.subtitle) { _, value in if value.count > 64 { model.subtitle = String(value.prefix(64)) } }
                        if model.titleArtwork != nil { Text("Your title artwork replaces these text fields on the sheet.").font(.caption).foregroundStyle(.secondary) }
                        HStack {
                            Picker("Style", selection: $model.theme) { Text("Midnight").tag("Midnight"); Text("Warm paper").tag("Warm paper") }.labelsHidden()
                            Button("Artwork…") { model.showSettings = true }.buttonStyle(.borderless)
                        }
                    }.disabled(model.takingPhotos)
                    Divider()
                    HStack(spacing: 10) {
                        Button { model.save() } label: { Label(model.savedFolder == nil ? "Save session" : "Saved", systemImage: model.savedFolder == nil ? "square.and.arrow.down" : "checkmark") }
                            .disabled(model.photos.isEmpty || model.takingPhotos)
                        Spacer()
                        Button { model.printSheet() } label: { Label("Print…", systemImage: "printer") }
                            .disabled(model.photos.count != 3 || model.takingPhotos)
                    }.controlSize(.large)
                    if let folder = model.savedFolder {
                        Button { NSWorkspace.shared.open(folder) } label: { Label("Show saved session", systemImage: "folder") }.buttonStyle(.borderless).font(.caption)
                    } else {
                        Text(model.outputFolder == nil ? "Choose a save folder in Setup to save every session automatically." : "Completed sessions save automatically to \(model.outputFolder!.lastPathComponent).")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.frame(width: 400)
            }.padding(.horizontal, 30).padding(.bottom, 25)
            HStack {
                Text("THREE PHOTOS + YOUR EVENT").tracking(1.6)
                Spacer()
                Text("Made here. Saved here. Yours to keep.")
            }.font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 30).padding(.vertical, 14)
                .background(.white.opacity(0.5))
        }
        .foregroundStyle(boothInk)
        .background(Color(red: 0.94, green: 0.94, blue: 0.91))
        .sheet(isPresented: $model.showSettings) { SetupView(model: model, camera: camera) }
        .alert("Something needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert("Keep this session?", isPresented: Binding(get: { model.discardAction != nil }, set: { if !$0 { model.discardAction = nil } }), presenting: model.discardAction) { action in
            Button("Save and continue") { model.save(); if !model.needsSave { perform(action) }; model.discardAction = nil }
            Button("Discard unsaved changes", role: .destructive) { perform(action); model.discardAction = nil }
            Button("Cancel", role: .cancel) { model.discardAction = nil }
        } message: { _ in Text("Save the current photos before starting over, or discard the unsaved session.") }
    }

    private func requestReset(_ action: String) {
        if model.needsSave { model.discardAction = action } else { perform(action) }
    }
    private func perform(_ action: String?) {
        if action == "import" { model.importPhotos() } else { model.reset() }
    }
    private func smallLabel(_ value: String) -> some View { Text(value).font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary) }
    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 12) }
            .buttonStyle(.plain).background(boothGreen, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(boothInk)
    }
}

struct SetupView: View {
    @ObservedObject var model: BoothModel
    @ObservedObject var camera: CameraController
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Set the scene").font(.system(size: 26, weight: .semibold, design: .serif)); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            Form {
                Section("Camera & countdown") {
                    HStack {
                        Picker("Camera", selection: Binding(get: { camera.selectedID }, set: { camera.select($0) })) {
                            if camera.devices.isEmpty { Text("Enable camera to discover devices").tag("") }
                            ForEach(camera.devices, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
                        }.disabled(camera.busy)
                        Button("Enable / refresh") { camera.enable() }.disabled(camera.busy)
                    }
                    Text(camera.message).font(.caption).foregroundStyle(.secondary)
                    Text("For iPhone: use the same Apple Account on both devices, enable Continuity Camera, and mount the locked phone horizontally. A USB connection is also supported.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Mirror preview and captured photos", isOn: $model.mirrored)
                    Stepper("Countdown: \(model.countdownSeconds) seconds per photo", value: $model.countdownSeconds, in: 2...10)
                }
                Section("Replaceable artwork") {
                    artworkRow("Background", name: model.backgroundName, kind: "background", present: model.background != nil)
                    artworkRow("Title cell", name: model.titleArtworkName, kind: "titleArtwork", present: model.titleArtwork != nil)
                    artworkRow("Overlay", name: model.overlayName, kind: "overlay", present: model.overlay != nil)
                    Text("Background / overlay: 1800 × 1200 px. Title artwork: 800 × 500 px. Overlays should be transparent PNGs with openings for the three photos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Saving & printing") {
                    HStack { Text(model.outputFolder?.path ?? "No save folder chosen").font(.caption).lineLimit(2); Spacer(); Button("Choose folder…") { model.chooseOutputFolder() } }
                    Text("After choosing a folder, completed sessions save automatically: one 1800 × 1200 JPEG at 300 dpi plus three original photos. Print on 6 × 4-inch landscape paper; select the matching paper size and borderless mode if your printer supports it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
        }.padding(24).frame(width: 650, height: 680)
    }

    private func artworkRow(_ title: String, name: String, kind: String, present: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { Text(title); Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            Spacer()
            if present { Button("Reset") { model.clearArtwork(kind) } }
            Button("Choose…") { model.chooseArtwork(kind) }
        }
    }
}
