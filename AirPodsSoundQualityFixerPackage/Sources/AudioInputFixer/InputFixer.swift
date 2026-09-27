import CoreAudio
import Foundation
import Observation
import os

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

  /// Snapshots the device list and default before recomputing, so `refresh` can tell a genuine
  /// sound-menu reselection (default changed, device list didn't) from a device connect/disconnect.
  private func handleExternalChange() {
    refresh(before: (deviceIDs: Set(devices.map(\.id)), defaultID: hardware.defaultInputDeviceID()))
  }

  private func refresh(before: (deviceIDs: Set<AudioDeviceID>, defaultID: AudioDeviceID?)? = nil) {
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
      Logger().error("Could not make \(forcedDevice.name) the default input")
    }
  }

  private func notifyOverrideIfNeeded(
    forcedDevice: AudioDevice, before: (deviceIDs: Set<AudioDeviceID>, defaultID: AudioDeviceID?)?
  ) {
    guard
      let before, before.deviceIDs == Set(devices.map(\.id)),
      let previousDefaultID = before.defaultID, previousDefaultID != forcedDevice.id,
      let selectedDevice = devices.first(where: { $0.id == previousDefaultID })
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
