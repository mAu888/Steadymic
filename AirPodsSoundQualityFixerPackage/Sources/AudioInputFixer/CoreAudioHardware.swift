import CoreAudio
import Foundation

public struct CoreAudioHardware: AudioHardware {
  private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

  public init() {}

  public func inputDevices() -> [AudioDevice] {
    deviceIDs().compactMap(inputDevice)
  }

  public func defaultInputDeviceID() -> AudioDeviceID? {
    var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
    var deviceID = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &size, &deviceID)
    return status == noErr && deviceID != kAudioObjectUnknown ? deviceID : nil
  }

  public func setDefaultInputDevice(_ id: AudioDeviceID) -> Bool {
    var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
    var deviceID = id
    let status = AudioObjectSetPropertyData(
      Self.systemObject, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID
    )
    return status == noErr && defaultInputDeviceID() == id
  }

  // AudioObjectRemovePropertyListenerBlock leaves a listener added from Swift installed, even when
  // the same stored @convention(block) value is passed to both calls. The function-pointer API
  // identifies a listener by its context pointer, which here is a registry key instead of an object
  // address, so a notification already in flight during removal finds no handler.
  public func observeChanges(_ onChange: @escaping @MainActor () -> Void) -> AudioHardwareObservation {
    let key = ListenerRegistry.add(onChange)
    let context = UnsafeMutableRawPointer(bitPattern: key)
    for selector in Self.observedSelectors {
      var address = Self.address(selector)
      AudioObjectAddPropertyListener(Self.systemObject, &address, Self.listenerProc, context)
    }
    return AudioHardwareObservation {
      for selector in Self.observedSelectors {
        var address = Self.address(selector)
        AudioObjectRemovePropertyListener(Self.systemObject, &address, Self.listenerProc, context)
      }
      DispatchQueue.main.async {
        MainActor.assumeIsolated { ListenerRegistry.remove(key) }
      }
    }
  }

  private static let observedSelectors = [
    kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice,
  ]

  private static let listenerProc: AudioObjectPropertyListenerProc = { _, _, _, context in
    let key = Int(bitPattern: context)
    DispatchQueue.main.async {
      MainActor.assumeIsolated { ListenerRegistry.handler(for: key)?() }
    }
    return noErr
  }

  private func deviceIDs() -> [AudioDeviceID] {
    var address = Self.address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(Self.systemObject, &address, 0, nil, &size) == noErr else {
      return []
    }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &size, &ids) == noErr else {
      return []
    }
    // The device list can shrink between the size query and the read.
    return Array(ids.prefix(Int(size) / MemoryLayout<AudioDeviceID>.size))
  }

  private func inputDevice(_ id: AudioDeviceID) -> AudioDevice? {
    var streamsAddress = Self.address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
    var streamsSize: UInt32 = 0
    guard
      AudioObjectGetPropertyDataSize(id, &streamsAddress, 0, nil, &streamsSize) == noErr,
      streamsSize > 0,
      let uid = string(kAudioDevicePropertyDeviceUID, of: id),
      let name = string(kAudioObjectPropertyName, of: id)
    else { return nil }

    var address = Self.address(kAudioDevicePropertyTransportType)
    var transportType: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transportType)

    return AudioDevice(
      deviceID: id, uid: uid, name: name, isBuiltIn: transportType == kAudioDeviceTransportTypeBuiltIn
    )
  }

  private func string(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
    var address = Self.address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
    return value?.takeRetainedValue() as String?
  }

  @MainActor
  enum ListenerRegistry {
    private static var handlers: [Int: @MainActor () -> Void] = [:]
    private static var nextKey = 1

    static var keys: Set<Int> { Set(handlers.keys) }

    static func add(_ handler: @escaping @MainActor () -> Void) -> Int {
      defer { nextKey += 1 }
      handlers[nextKey] = handler
      return nextKey
    }

    static func remove(_ key: Int) {
      handlers[key] = nil
    }

    static func handler(for key: Int) -> (@MainActor () -> Void)? {
      handlers[key]
    }
  }

  private static func address(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain
    )
  }
}
