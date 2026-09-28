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
      Image(nsImage: fixer.isForcing ? Self.activeIcon : Self.inactiveIcon)
        .help(Text(Self.status(of: fixer)))
    }

    Window("Preferred Input Devices", id: WindowIDs.advancedPriority) {
      AdvancedPriorityView(fixer: fixer)
    }
    .windowResizability(.contentSize)

    Settings {
      SettingsView()
    }
  }

  private static let activeIcon = menuBarIcon(
    "headphones.circle.fill", description: String(localized: "AirPods Sound Quality Fixer")
  )
  private static let inactiveIcon = menuBarIcon(
    "headphones.circle", description: String(localized: "AirPods Sound Quality Fixer, not forcing an input")
  )

  private static func status(of fixer: InputFixer) -> LocalizedStringResource {
    if fixer.isPaused {
      return "AirPods Sound Quality Fixer is paused"
    }
    if let failedDevice = fixer.failedDevice {
      return "AirPods Sound Quality Fixer could not switch the input to \(failedDevice.name)"
    }
    guard let forcedDevice = fixer.forcedDevice else {
      return "AirPods Sound Quality Fixer has no connected input to force"
    }
    return "AirPods Sound Quality Fixer is forcing the input to \(forcedDevice.name)"
  }

  /// MenuBarExtra ignores image modifiers such as `imageScale` on its label, so the size is part of
  /// the NSImage's symbol configuration. At the default size the circle is 3 pt smaller than the
  /// system's own circular status items.
  private static func menuBarIcon(_ symbolName: String, description: String) -> NSImage {
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)!
    return image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)) ?? image
  }
}

enum DefaultsKeys {
  static let isIconVisible = "IsIconVisible"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  /// SwiftUI terminates an app with a `Window` scene once its last window closes, and closing the
  /// menu bar menu counts as such a close.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  /// Opening the app from Finder, Spotlight, or Launchpad while it runs is the only way to show a
  /// hidden menu bar icon again, since the app has no Dock icon or window.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    UserDefaults.standard.set(true, forKey: DefaultsKeys.isIconVisible)
    return false
  }
}
