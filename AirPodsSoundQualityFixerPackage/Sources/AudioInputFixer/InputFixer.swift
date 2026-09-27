import CoreAudio
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.milgra.asqf", category: "InputFixer")

/// Keeps the system default input on the highest-priority connected device, or on the built-in
/// microphone when none of the preferred devices are connected, so that AirPods stay in their
/// high-quality output mode.
@MainActor
@Observable
public final class InputFixer {
  public private(set) var devices: [AudioDevice] = []
  public private(set) var forcedDevice: AudioDevice?
  /// The device the last forcing attempt could not make the default input.
  public private(set) var failedDevice: AudioDevice?
  /// User's preferred devices, most preferred first. `select` moves a device to the front; devices
  /// not in this list, and the built-in microphone as an implicit last resort, are never chosen
  /// over a connected entry that is.
  public private(set) var priorityUIDs: [String]
  public var isPaused = false {
    didSet { refresh() }
  }

  @ObservationIgnored private let hardware: any AudioHardware
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var observation: AudioHardwareObservation?
  /// Set after construction, once the app has something able to present a notification.
  @ObservationIgnored public var notifier: (any OverrideNotifier)?

  public init(hardware: any AudioHardware, defaults: UserDefaults = .standard) {
    self.hardware = hardware
    self.defaults = defaults
    // Migrate the single-device preference an earlier version persisted into a one-entry list.
    if let list = defaults.array(forKey: Keys.priorityUIDs) as? [String] {
      priorityUIDs = list
    } else if let legacyUID = defaults.string(forKey: Keys.legacyForcedDeviceUID) {
      priorityUIDs = [legacyUID]
    } else {
      priorityUIDs = []
    }
  }

  public func start() {
    observation = hardware.observeChanges { [weak self] in self?.handleExternalChange() }
    refresh()
  }

  /// Makes the connected input device with `uid` the most preferred input, persisted across
  /// launches. Returns `false` and keeps the current preference when no connected input device
  /// has `uid`.
  @discardableResult
  public func select(uid: String) -> Bool {
    guard devices.contains(where: { $0.uid == uid }) else { return false }
    var uids = priorityUIDs
    uids.removeAll { $0 == uid }
    uids.insert(uid, at: 0)
    setPriority(uids)
    return true
  }

  /// Removes a device from the priority list. It can still be picked manually with `select`.
  public func removeFromPriority(uid: String) {
    setPriority(priorityUIDs.filter { $0 != uid })
  }

  /// Adds a connected device to the end of the priority list, as the least preferred entry.
  /// Returns `false` and leaves the list unchanged when `uid` isn't connected or is already in it.
  @discardableResult
  public func appendToPriority(uid: String) -> Bool {
    guard devices.contains(where: { $0.uid == uid }), !priorityUIDs.contains(uid) else { return false }
    setPriority(priorityUIDs + [uid])
    return true
  }

  /// Replaces the whole priority order, most preferred first, persisted across launches. Used by
  /// UI that lets the user reorder the list directly rather than only promote one device.
  public func setPriority(_ uids: [String]) {
    priorityUIDs = uids
    defaults.set(uids, forKey: Keys.priorityUIDs)
    refresh()
  }

  /// Snapshots the device list and default (by UID, stable across reconnects unlike `AudioDeviceID`)
  /// before recomputing, so `refresh` can tell a genuine sound-menu reselection (default changed,
  /// device list didn't) from a device connect/disconnect.
  private func handleExternalChange() {
    let selectedDefaultUID = hardware.defaultInputDeviceID().flatMap { id in
      devices.first(where: { $0.id == id })?.uid
    }
    refresh(before: (deviceUIDs: Set(devices.map(\.uid)), defaultUID: selectedDefaultUID))
  }

  private func refresh(before: (deviceUIDs: Set<String>, defaultUID: String?)? = nil) {
    devices = hardware.inputDevices()
    forcedDevice = Self.deviceToForce(in: devices, priorityUIDs: priorityUIDs)
    guard !isPaused, let forcedDevice, hardware.defaultInputDeviceID() != forcedDevice.id else {
      failedDevice = nil
      return
    }
    if hardware.setDefaultInputDevice(forcedDevice.id) {
      failedDevice = nil
      notifyOverrideIfNeeded(forcedDevice: forcedDevice, before: before)
    } else {
      failedDevice = forcedDevice
      logger.error("Could not make \(forcedDevice.name, privacy: .public) the default input")
    }
  }

  private func notifyOverrideIfNeeded(
    forcedDevice: AudioDevice, before: (deviceUIDs: Set<String>, defaultUID: String?)?
  ) {
    guard let before, before.deviceUIDs == Set(devices.map(\.uid)) else { return }
    guard let selectedDefaultUID = before.defaultUID else {
      logger.error("Could not determine the selected default input to report an override")
      return
    }
    guard selectedDefaultUID != forcedDevice.uid,
      let selectedDevice = devices.first(where: { $0.uid == selectedDefaultUID })
    else { return }
    notifier?.notifyOverride(selectedDevice: selectedDevice, forcedDevice: forcedDevice)
  }

  /// Returns the highest-priority connected device, falling back to the built-in microphone, then
  /// to `nil` when neither is present.
  static func deviceToForce(in devices: [AudioDevice], priorityUIDs: [String]) -> AudioDevice? {
    for uid in priorityUIDs {
      if let device = devices.first(where: { $0.uid == uid }) { return device }
    }
    return devices.first(where: \.isBuiltIn)
  }

  enum Keys {
    static let priorityUIDs = "PriorityDeviceUIDs"
    /// Single-device preference persisted by versions before the priority list existed.
    static let legacyForcedDeviceUID = "ForcedDeviceUID"
  }
}
