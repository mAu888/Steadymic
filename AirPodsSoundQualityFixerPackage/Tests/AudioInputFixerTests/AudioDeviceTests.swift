import AudioInputFixer
import CustomDump
import Testing

struct AudioDeviceTests {
  @Test func keepsIdentityWhenReconnectingWithNewDeviceID() {
    let reconnected = AudioDevice(
      deviceID: AudioDevice.airPods.deviceID + 1,
      uid: AudioDevice.airPods.uid,
      name: AudioDevice.airPods.name,
      isBuiltIn: AudioDevice.airPods.isBuiltIn
    )

    expectNoDifference(reconnected.id, AudioDevice.airPods.id)
    expectNoDifference(reconnected.id, AudioDevice.airPods.uid)
  }
}
