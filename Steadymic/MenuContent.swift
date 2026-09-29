import AudioInputFixer
import SwiftUI

struct MenuContent: View {
  @Bindable var fixer: InputFixer
  @Binding var isIconVisible: Bool
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Toggle("Pause", isOn: $fixer.isPaused)
    Divider()
    Picker("Force input to:", selection: forcedDeviceUID) {
      ForEach(fixer.devices) { device in
        Text(device.name).tag(Optional(device.uid))
      }
    }
    .pickerStyle(.inline)
    if let failedDevice = fixer.failedDevice {
      Text("Could not switch the input to \(failedDevice.name)")
    }
    Toggle(isOn: advancedIsActive) {
      Text("Advanced…")
    }
    .keyboardShortcut(",", modifiers: [.command, .option])
    Divider()
    Button("Hide") {
      if Self.confirmHide() {
        isIconVisible = false
      }
    }
    .keyboardShortcut("h")
    Button("Settings…") {
      // Without activation, the Settings window of an app with no Dock icon opens behind the
      // frontmost app's windows.
      NSApp.activate()
      openSettings()
    }
    .keyboardShortcut(",")
    Button("Quit") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  /// `Advanced…` carries the checkmark instead of a device while the fallback chain is enabled,
  /// since no single row could represent an ordered list.
  private var forcedDeviceUID: Binding<String?> {
    Binding {
      fixer.isPriorityEnabled ? nil : fixer.forcedDevice?.uid
    } set: { uid in
      if let uid {
        fixer.select(uid: uid)
      }
    }
  }

  private var advancedIsActive: Binding<Bool> {
    Binding {
      fixer.isPriorityEnabled
    } set: { _ in
      // The user's tap always opens the editor; it never sets this checkmark directly.
      NSApp.activate()
      openWindow(id: WindowIDs.advancedPriority)
    }
  }

  private static func confirmHide() -> Bool {
    let alert = NSAlert()
    alert.messageText = String(localized: "Hide the Menu Bar Icon?")
    alert.informativeText = String(
      localized: "Steadymic keeps running. To show the icon again, open Steadymic from the Applications folder."
    )
    alert.addButton(withTitle: String(localized: "Hide"))
    alert.addButton(withTitle: String(localized: "Cancel"))
    // An app with no Dock icon stays inactive while its menu is open, so without activation the
    // alert cannot become key and does not receive Return or Escape.
    NSApp.activate()
    return alert.runModal() == .alertFirstButtonReturn
  }
}
