import AppKit
import AudioInputFixer
import SwiftUI

@main
struct AirPodsSoundQualityFixerApp: App {
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
  @State private var fixer: InputFixer
  @AppStorage(DefaultsKeys.isIconVisible) private var isIconVisible = true
  // Kept alive here: UNUserNotificationCenter.delegate does not retain its delegate.
  private let overrideNotificationCenter: OverrideNotificationCenter

  init() {
    let fixer = InputFixer(hardware: CoreAudioHardware())
    overrideNotificationCenter = OverrideNotificationCenter(fixer: fixer)
    fixer.notifier = overrideNotificationCenter
    // Forcing has to begin at launch, not when the menu is first opened.
    fixer.start()
    _fixer = State(initialValue: fixer)
  }

  var body: some Scene {
    MenuBarExtra(isInserted: $isIconVisible) {
      MenuContent(fixer: fixer, isIconVisible: $isIconVisible)
    } label: {
      Image(.menuBarIcon)
        .help("AirPods Audio Quality & Battery Life Fixer")
    }

    Window("Preferred Input Devices", id: WindowIDs.advancedPriority) {
      AdvancedPriorityView(fixer: fixer)
    }
    .windowResizability(.contentSize)
  }
}

enum DefaultsKeys {
  static let isIconVisible = "IsIconVisible"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  /// Opening the app from Finder, Spotlight, or Launchpad while it runs is the only way to show a
  /// hidden menu bar icon again, since the app has no Dock icon or window.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    UserDefaults.standard.set(true, forKey: DefaultsKeys.isIconVisible)
    return false
  }
}
