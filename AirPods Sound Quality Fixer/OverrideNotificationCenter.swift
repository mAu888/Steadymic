import AudioInputFixer
import UserNotifications

/// Presents a system notification when the fixer switches the input back after the user picked a
/// different one from the sound menu, with actions to undo that switch or pause the fixer.
@MainActor
final class OverrideNotificationCenter: NSObject, OverrideNotifier, UNUserNotificationCenterDelegate {
  private weak var fixer: InputFixer?
  private let center = UNUserNotificationCenter.current()

  private enum Action {
    static let category = "INPUT_OVERRIDE"
    static let setAsForcedInput = "SET_AS_FORCED_INPUT"
    static let pause = "PAUSE_FIXER"
  }

  private nonisolated static let selectedDeviceUIDKey = "selectedDeviceUID"

  init(fixer: InputFixer) {
    self.fixer = fixer
    super.init()
    center.delegate = self
    center.requestAuthorization(options: [.alert]) { _, _ in }
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: Action.category,
        actions: [
          UNNotificationAction(identifier: Action.setAsForcedInput, title: "Set as Forced Input", options: []),
          UNNotificationAction(identifier: Action.pause, title: "Pause Fixer", options: []),
        ],
        intentIdentifiers: []
      )
    ])
  }

  func notifyOverride(selectedDevice: AudioDevice, forcedDevice: AudioDevice) {
    let content = UNMutableNotificationContent()
    content.title = "Input Switched Back to \(forcedDevice.name)"
    content.body =
      "You selected \(selectedDevice.name), but AirPods Sound Quality Fixer switched the input back. "
      + "\"Set as Forced Input\" makes \(selectedDevice.name) the new pinned input instead."
    content.categoryIdentifier = Action.category
    content.userInfo = [Self.selectedDeviceUIDKey: selectedDevice.uid]
    center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
  }

  // Without this, UNUserNotificationCenter suppresses the alert whenever the app is foreground,
  // which for a menu-bar app includes whenever its own menu is open.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionIdentifier = response.actionIdentifier
    let selectedDeviceUID = response.notification.request.content.userInfo[Self.selectedDeviceUIDKey] as? String
    Task { @MainActor [self] in
      handle(actionIdentifier: actionIdentifier, selectedDeviceUID: selectedDeviceUID)
    }
    completionHandler()
  }

  private func handle(actionIdentifier: String, selectedDeviceUID: String?) {
    guard let fixer else { return }
    switch actionIdentifier {
    case Action.setAsForcedInput:
      if let selectedDeviceUID, let device = fixer.devices.first(where: { $0.uid == selectedDeviceUID }) {
        fixer.select(device)
      }
    case Action.pause:
      fixer.isPaused = true
    default:
      break
    }
  }
}
