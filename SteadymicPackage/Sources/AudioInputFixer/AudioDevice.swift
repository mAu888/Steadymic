import CoreAudio

public struct AudioDevice: Equatable, Identifiable, Sendable {
  /// The CoreAudio object ID, which can change across reconnects and reboots.
  public let deviceID: AudioDeviceID
  /// Stable across reboots and reconnects, unlike `deviceID`.
  public let uid: String
  public let name: String
  public let isBuiltIn: Bool

  public var id: String { uid }

  public init(deviceID: AudioDeviceID, uid: String, name: String, isBuiltIn: Bool) {
    self.deviceID = deviceID
    self.uid = uid
    self.name = name
    self.isBuiltIn = isBuiltIn
  }
}
