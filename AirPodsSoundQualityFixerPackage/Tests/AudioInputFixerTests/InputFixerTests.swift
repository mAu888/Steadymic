import AudioInputFixer
import CustomDump
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct InputFixerTests {
  let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: "AudioInputFixerTests")!
    defaults.removePersistentDomain(forName: "AudioInputFixerTests")
  }

  @Test func forcesBuiltInMicrophoneWithoutPreference() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.airPods.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, .builtIn)
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.id])
  }

  @Test func leavesDefaultInputAloneWhenAlreadyForced() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func forcesInputAgainWhenSystemSwitchesToAirPods() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()

    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.id])
  }

  @Test func selectingDeviceForcesAndPersistsIt() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.select(uid: AudioDevice.interface.uid), true)

    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.interface.id])

    let relaunched = InputFixer(hardware: hardware, defaults: defaults)
    relaunched.start()
    expectNoDifference(relaunched.forcedDevice, .interface)
  }

  @Test func appendToPriorityAddsDeviceAsLeastPreferred() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.interface.uid)

    expectNoDifference(fixer.appendToPriority(uid: AudioDevice.builtIn.uid), true)

    expectNoDifference(fixer.priorityUIDs, [AudioDevice.interface.uid, AudioDevice.builtIn.uid])
    expectNoDifference(fixer.forcedDevice, .interface)
  }

  @Test func appendToPriorityRejectsDisconnectedOrDuplicateDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.builtIn.uid)

    expectNoDifference(fixer.appendToPriority(uid: AudioDevice.interface.uid), false)
    expectNoDifference(fixer.appendToPriority(uid: AudioDevice.builtIn.uid), false)
    expectNoDifference(fixer.priorityUIDs, [AudioDevice.builtIn.uid])
  }

  @Test func rejectsSelectingDisconnectedDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.select(uid: AudioDevice.interface.uid), false)
    expectNoDifference(fixer.forcedDevice, .builtIn)

    hardware.devices = [.airPods, .builtIn, .interface]
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .builtIn)
    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func fallsBackToBuiltInWhilePreferredDeviceIsDisconnected() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.interface.uid)

    hardware.devices = [.airPods, .builtIn]
    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .builtIn)

    hardware.devices = [.airPods, .builtIn, .interface]
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(
      hardware.setDefaultInputCalls,
      [AudioDevice.interface.id, AudioDevice.builtIn.id, AudioDevice.interface.id]
    )
  }

  @Test func doesNotForceWhilePaused() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.isPaused = true

    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()
    expectNoDifference(hardware.setDefaultInputCalls, [])

    fixer.isPaused = false
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.id])
  }

  @Test func doesNotForceWithoutBuiltInOrPreferredDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods], defaultInput: AudioDevice.airPods.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, nil)
    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func notifiesWhenSoundMenuSelectionIsOverridden() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    let notifier = FakeOverrideNotifier()
    fixer.notifier = notifier
    fixer.start()

    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()

    expectNoDifference(notifier.overrides.map(\.selectedDevice), [.airPods])
    expectNoDifference(notifier.overrides.map(\.forcedDevice), [.builtIn])
  }

  @Test func doesNotNotifyOnInitialLaunchMismatch() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.airPods.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    let notifier = FakeOverrideNotifier()
    fixer.notifier = notifier

    fixer.start()

    expectNoDifference(notifier.overrides.isEmpty, true)
  }

  @Test func doesNotNotifyWhenDeviceListAlsoChanged() {
    let hardware = FakeAudioHardware(devices: [.builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.interface.uid)
    hardware.devices = [.builtIn]
    hardware.defaultInput = AudioDevice.builtIn.id
    hardware.simulateChange()
    let notifier = FakeOverrideNotifier()
    fixer.notifier = notifier

    hardware.devices = [.builtIn, .airPods, .interface]
    hardware.defaultInput = AudioDevice.airPods.id
    hardware.simulateChange()

    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(notifier.overrides.isEmpty, true)
  }

  @Test func fallsBackThroughPriorityOrderRatherThanStraightToBuiltIn() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.builtIn.uid)
    fixer.select(uid: AudioDevice.interface.uid)
    expectNoDifference(fixer.priorityUIDs, [AudioDevice.interface.uid, AudioDevice.builtIn.uid])

    hardware.devices = [.airPods, .builtIn]
    hardware.simulateChange()

    expectNoDifference(fixer.forcedDevice, .builtIn)
  }

  @Test func removeFromPriorityDropsDeviceFromTheFallbackOrder() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.builtIn.uid)
    fixer.select(uid: AudioDevice.interface.uid)

    fixer.removeFromPriority(uid: AudioDevice.interface.uid)

    expectNoDifference(fixer.priorityUIDs, [AudioDevice.builtIn.uid])
    expectNoDifference(fixer.forcedDevice, .builtIn)
  }

  @Test func migratesLegacySingleDevicePreferenceIntoPriorityList() {
    defaults.set(AudioDevice.interface.uid, forKey: "ForcedDeviceUID")
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.id)

    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.priorityUIDs, [AudioDevice.interface.uid])
    expectNoDifference(fixer.forcedDevice, .interface)
  }

  @Test func reportsDeviceThatCannotBecomeDefaultInput() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.airPods.id)
    hardware.rejectedDeviceIDs = [AudioDevice.interface.id]
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    expectNoDifference(fixer.failedDevice, nil)

    fixer.select(uid: AudioDevice.interface.uid)
    expectNoDifference(fixer.failedDevice, .interface)
    expectNoDifference(hardware.defaultInput, AudioDevice.builtIn.id)

    fixer.select(uid: AudioDevice.builtIn.uid)
    expectNoDifference(fixer.failedDevice, nil)
  }
}
