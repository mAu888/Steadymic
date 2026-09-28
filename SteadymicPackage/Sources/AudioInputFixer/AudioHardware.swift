import CoreAudio

@MainActor
public protocol AudioHardware {
  func inputDevices() -> [AudioDevice]
  func defaultInputDeviceID() -> AudioDeviceID?
  /// Returns whether `id` is the default input afterwards. CoreAudio reports success for requests
  /// it ignores, such as an ID that no longer exists.
  func setDefaultInputDevice(_ id: AudioDeviceID) -> Bool
  /// Calls `onChange` on the main queue when the device list or the default input device changes,
  /// until the returned observation is released.
  func observeChanges(_ onChange: @escaping @MainActor () -> Void) -> AudioHardwareObservation
}

public final class AudioHardwareObservation {
  private let cancel: () -> Void

  public init(cancel: @escaping () -> Void) {
    self.cancel = cancel
  }

  deinit {
    cancel()
  }
}
