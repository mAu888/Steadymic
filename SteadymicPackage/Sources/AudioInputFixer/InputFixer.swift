import CoreAudio
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.milgra.asqf", category: "InputFixer")

/// Keeps the system default input on the user's fixed device, or on the highest-priority connected
/// device of the fallback chain while that is enabled, and otherwise on the built-in microphone, so
/// that AirPods stay in their high-quality output mode.
@MainActor
@Observable
public final class InputFixer {
  public private(set) var devices: [AudioDevice] = []
  public private(set) var forcedDevice: AudioDevice?
  /// The device the last forcing attempt could not make the default input.
  public private(set) var failedDevice: AudioDevice?
  /// The single device `select` fixes the input to while the fallback chain is disabled.
  public private(set) var fixedUID: String?
  /// The fallback chain, most preferred first. Kept while the chain is disabled, so that the user
  /// can switch between a fixed device and the chain without reconfiguring it.
  public private(set) var priorityUIDs: [String]
  /// Whether the fixer forces from `priorityUIDs` instead of `fixedUID`.
  public var isPriorityEnabled: Bool {
    didSet {
      defaults.set(isPriorityEnabled, forKey: Keys.isPriorityEnabled)
      refresh()
    }
  }
  public var isPaused = false {
    didSet { refresh() }
  }
  /// Whether the default input is held on `forcedDevice`: the fixer is not paused, has a device to
  /// force, and its last attempt to switch to that device succeeded.
  public var isForcing: Bool {
    !isPaused && forcedDevice != nil && failedDevice == nil
  }
  /// The device forced when no preferred device is connected: the built-in microphone, if present.
  public var fallbackDevice: AudioDevice? {
    Self.fallbackDevice(in: devices)
  }

  @ObservationIgnored private let hardware: any AudioHardware
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var observation: AudioHardwareObservation?
  /// Set after construction, once the app has something able to present a notification.
  @ObservationIgnored public var notifier: (any OverrideNotifier)?

  public init(hardware: any AudioHardware, defaults: UserDefaults = .standard) {
    self.hardware = hardware
    self.defaults = defaults
    let priorityUIDs = defaults.array(forKey: Keys.priorityUIDs) as? [String] ?? []
    self.priorityUIDs = priorityUIDs
    if let isPriorityEnabled = defaults.object(forKey: Keys.isPriorityEnabled) as? Bool {
      fixedUID = defaults.string(forKey: Keys.fixedUID)
      self.isPriorityEnabled = isPriorityEnabled
    } else {
      // Builds that predate the enabled flag always forced from the chain, and left `fixedUID`
      // stale once it existed. A one-entry chain carries over as the fixed device.
      fixedUID = priorityUIDs.count == 1 ? priorityUIDs[0] : defaults.string(forKey: Keys.fixedUID)
      isPriorityEnabled = priorityUIDs.count > 1
    }
  }

  public func start() {
    observation = hardware.observeChanges { [weak self] in self?.handleExternalChange() }
    refresh()
  }

  /// Fixes the input to the connected input device with `uid` and disables the fallback chain,
  /// persisted across launches. Returns `false` and keeps the current preference when no connected
  /// input device has `uid`.
  @discardableResult
  public func select(uid: String) -> Bool {
    guard devices.contains(where: { $0.uid == uid }) else { return false }
    fixedUID = uid
    defaults.set(uid, forKey: Keys.fixedUID)
    if isPriorityEnabled {
      isPriorityEnabled = false
    } else {
      refresh()
    }
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

  /// Replaces the whole priority order, most preferred first, persisted across launches.
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
      devices.first(where: { $0.deviceID == id })?.uid
    }
    refresh(before: (deviceUIDs: Set(devices.map(\.uid)), defaultUID: selectedDefaultUID))
  }

  private func refresh(before: (deviceUIDs: Set<String>, defaultUID: String?)? = nil) {
    devices = hardware.inputDevices()
    forcedDevice = Self.deviceToForce(in: devices, preferredUIDs: isPriorityEnabled ? priorityUIDs : fixedUID.map { [$0] } ?? [])
    guard !isPaused, let forcedDevice, hardware.defaultInputDeviceID() != forcedDevice.deviceID else {
      failedDevice = nil
      return
    }
    if hardware.setDefaultInputDevice(forcedDevice.deviceID) {
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

  /// Returns the first connected device of `preferredUIDs`, falling back to the built-in microphone,
  /// then to `nil` when neither is present.
  static func deviceToForce(in devices: [AudioDevice], preferredUIDs: [String]) -> AudioDevice? {
    for uid in preferredUIDs {
      if let device = devices.first(where: { $0.uid == uid }) { return device }
    }
    return fallbackDevice(in: devices)
  }

  static func fallbackDevice(in devices: [AudioDevice]) -> AudioDevice? {
    devices.first(where: \.isBuiltIn)
  }

  enum Keys {
    static let fixedUID = "ForcedDeviceUID"
    static let priorityUIDs = "PriorityDeviceUIDs"
    static let isPriorityEnabled = "PriorityEnabled"
  }
}
