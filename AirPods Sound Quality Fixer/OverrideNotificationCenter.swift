import AudioInputFixer
import UserNotifications
import os

nonisolated private let logger = Logger(subsystem: "com.milgra.asqf", category: "OverrideNotificationCenter")

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
    center.requestAuthorization(options: [.alert]) { granted, error in
      if let error {
        logger.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
      } else if !granted {
        logger.error("Notification authorization was denied")
      }
    }
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
    post(content)
  }

  private func notifyDeviceUnavailable() {
    let content = UNMutableNotificationContent()
    content.title = "Device No Longer Available"
    content.body = "The input you selected is no longer connected, so it could not be set as the forced input."
    post(content)
  }

  private func post(_ content: UNNotificationContent) {
    center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { error in
      if let error {
        logger.error("Could not present notification: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  // Without this, UNUserNotificationCenter suppresses the alert whenever the app is foreground,
  // which for a menu-bar app includes whenever its own menu is open.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    // Only these Sendable values cross to the main actor; UNNotificationResponse is not Sendable.
    let actionIdentifier = response.actionIdentifier
    let selectedDeviceUID = response.notification.request.content.userInfo[Self.selectedDeviceUIDKey] as? String
    await handle(actionIdentifier: actionIdentifier, selectedDeviceUID: selectedDeviceUID)
  }

  private func handle(actionIdentifier: String, selectedDeviceUID: String?) {
    guard let fixer else { return }
    switch actionIdentifier {
    case Action.setAsForcedInput:
      guard let selectedDeviceUID, fixer.select(uid: selectedDeviceUID) else {
        notifyDeviceUnavailable()
        return
      }
    case Action.pause:
      fixer.isPaused = true
    default:
      break
    }
  }
}
