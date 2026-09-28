/// Notifies the user that a manual input selection was overridden by the fixer.
@MainActor
public protocol OverrideNotifier {
  func notifyOverride(selectedDevice: AudioDevice, forcedDevice: AudioDevice)
}
