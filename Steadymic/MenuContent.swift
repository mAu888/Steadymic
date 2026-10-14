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
    // Toggles instead of a `Picker`, whose menu rows ignore `disabled`. Symbols trail the names,
    // since a leading one would indent its name past the other rows' names.
    Section("Force input to:") {
      ForEach(fixer.listedDevices) { device in
        switch device {
        case .connected(let device):
          Toggle(isOn: isSelected(device.uid)) {
            if device == standInDevice {
              Text(device.name) + Text(" ") + Text(Image(systemName: "arrow.turn.down.left"))
            } else {
              Text(device.name)
            }
          }
        case .disconnected(let device):
          Toggle(isOn: isSelected(device.uid)) {
            Text(device.name) + Text(" ") + Text(Image(systemName: "microphone.badge.xmark.fill"))
          }
          .disabled(true)
          .help("Not connected")
          if !fixer.isPaused {
            if let standInDevice {
              Text("Using \(standInDevice.name) until \(device.name) reconnects")
            } else if fixer.forcedDevice == nil {
              Text("No input to use until \(device.name) reconnects")
            }
          }
        }
      }
    }
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
  /// since no single row could represent an ordered list. A disconnected fixed device keeps the
  /// checkmark over the fallback device the input is forced to meanwhile.
  /// The device the input is held on while the fixed device is disconnected.
  private var standInDevice: AudioDevice? {
    fixer.disconnectedFixedDevice != nil && fixer.isForcing ? fixer.forcedDevice : nil
  }

  private func isSelected(_ uid: String) -> Binding<Bool> {
    Binding {
      !fixer.isPriorityEnabled && (fixer.disconnectedFixedDevice?.uid ?? fixer.forcedDevice?.uid) == uid
    } set: { _ in
      fixer.select(uid: uid)
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
