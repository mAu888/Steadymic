import AudioInputFixer

@MainActor
final class FakeOverrideNotifier: OverrideNotifier {
  private(set) var overrides: [(selectedDevice: AudioDevice, forcedDevice: AudioDevice)] = []

  func notifyOverride(selectedDevice: AudioDevice, forcedDevice: AudioDevice) {
    overrides.append((selectedDevice, forcedDevice))
  }
}
