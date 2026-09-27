import CoreAudio
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.milgra.asqf", category: "InputFixer")

/// Keeps the system default input on the preferred device, or on the built-in microphone when no
/// preferred device is connected, so that AirPods stay in their high-quality output mode.
@MainActor
@Observable
public final class InputFixer {
  public private(set) var devices: [AudioDevice] = []
  public private(set) var forcedDevice: AudioDevice?
  /// The device the last forcing attempt could not make the default input.
  public private(set) var failedDevice: AudioDevice?
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
  }

  public func start() {
    observation = hardware.observeChanges { [weak self] in self?.handleExternalChange() }
    refresh()
  }

  public func select(_ device: AudioDevice) {
    defaults.set(device.uid, forKey: Keys.forcedDeviceUID)
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
    forcedDevice = Self.deviceToForce(
      in: devices, preferredUID: defaults.string(forKey: Keys.forcedDeviceUID)
    )
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

  static func deviceToForce(in devices: [AudioDevice], preferredUID: String?) -> AudioDevice? {
    devices.first { $0.uid == preferredUID } ?? devices.first(where: \.isBuiltIn)
  }

  enum Keys {
    static let forcedDeviceUID = "ForcedDeviceUID"
  }
}
