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
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.airPods.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, .builtIn)
    expectNoDifference(fixer.isForcing, true)
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.deviceID])
  }

  @Test func leavesDefaultInputAloneWhenAlreadyForced() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func forcesInputAgainWhenSystemSwitchesToAirPods() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    hardware.defaultInput = AudioDevice.airPods.deviceID
    hardware.simulateChange()

    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.deviceID])
  }

  @Test func selectingDeviceForcesAndPersistsIt() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.select(uid: AudioDevice.interface.uid), true)

    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.interface.deviceID])

    let relaunched = InputFixer(hardware: hardware, defaults: defaults)
    relaunched.start()
    expectNoDifference(relaunched.forcedDevice, .interface)
  }

  @Test func selectingAnotherDeviceReplacesTheFixedDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.interface.uid)

    fixer.select(uid: AudioDevice.builtIn.uid)
    hardware.devices = [.airPods, .interface]
    hardware.simulateChange()

    expectNoDifference(fixer.forcedDevice, nil)
  }

  @Test func selectingDeviceDisablesButKeepsFallbackChain() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.setPriority([AudioDevice.interface.uid, AudioDevice.builtIn.uid])
    fixer.isPriorityEnabled = true
    expectNoDifference(fixer.forcedDevice, .interface)

    fixer.select(uid: AudioDevice.airPods.uid)
    expectNoDifference(fixer.isPriorityEnabled, false)
    expectNoDifference(fixer.priorityUIDs, [AudioDevice.interface.uid, AudioDevice.builtIn.uid])
    expectNoDifference(fixer.forcedDevice, .airPods)

    fixer.isPriorityEnabled = true
    expectNoDifference(fixer.forcedDevice, .interface)

    let relaunched = InputFixer(hardware: hardware, defaults: defaults)
    relaunched.start()
    expectNoDifference(relaunched.isPriorityEnabled, true)
    expectNoDifference(relaunched.fixedUID, AudioDevice.airPods.uid)
  }

  @Test func ignoresFallbackChainWhileDisabled() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    fixer.setPriority([AudioDevice.interface.uid])

    expectNoDifference(fixer.forcedDevice, .builtIn)
  }

  @Test func appendToPriorityAddsDeviceAsLeastPreferred() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.isPriorityEnabled = true
    fixer.appendToPriority(uid: AudioDevice.interface.uid)

    expectNoDifference(fixer.appendToPriority(uid: AudioDevice.builtIn.uid), true)

    expectNoDifference(fixer.priorityUIDs, [AudioDevice.interface.uid, AudioDevice.builtIn.uid])
    expectNoDifference(fixer.forcedDevice, .interface)
  }

  @Test func appendToPriorityRejectsDisconnectedOrDuplicateDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.appendToPriority(uid: AudioDevice.builtIn.uid)

    expectNoDifference(fixer.appendToPriority(uid: AudioDevice.interface.uid), false)
    expectNoDifference(fixer.appendToPriority(uid: AudioDevice.builtIn.uid), false)
    expectNoDifference(fixer.priorityUIDs, [AudioDevice.builtIn.uid])
  }

  @Test func rejectsSelectingDisconnectedDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
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
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.interface.uid)

    hardware.devices = [.airPods, .builtIn]
    hardware.defaultInput = AudioDevice.airPods.deviceID
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .builtIn)

    hardware.devices = [.airPods, .builtIn, .interface]
    hardware.simulateChange()
    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(
      hardware.setDefaultInputCalls,
      [AudioDevice.interface.deviceID, AudioDevice.builtIn.deviceID, AudioDevice.interface.deviceID]
    )
  }

  @Test func doesNotForceWhilePaused() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.isPaused = true

    hardware.defaultInput = AudioDevice.airPods.deviceID
    hardware.simulateChange()
    expectNoDifference(hardware.setDefaultInputCalls, [])
    expectNoDifference(fixer.isForcing, false)

    fixer.isPaused = false
    expectNoDifference(hardware.setDefaultInputCalls, [AudioDevice.builtIn.deviceID])
    expectNoDifference(fixer.isForcing, true)
  }

  @Test func doesNotForceWithoutBuiltInOrPreferredDevice() {
    let hardware = FakeAudioHardware(devices: [.airPods], defaultInput: AudioDevice.airPods.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.forcedDevice, nil)
    expectNoDifference(fixer.isForcing, false)
    expectNoDifference(hardware.setDefaultInputCalls, [])
  }

  @Test func reportsBuiltInMicrophoneAsFallbackWhilePresent() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    expectNoDifference(fixer.fallbackDevice, .builtIn)

    hardware.devices = [.airPods]
    hardware.simulateChange()

    expectNoDifference(fixer.fallbackDevice, nil)
  }

  @Test func notifiesWhenSoundMenuSelectionIsOverridden() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    let notifier = FakeOverrideNotifier()
    fixer.notifier = notifier
    fixer.start()

    hardware.defaultInput = AudioDevice.airPods.deviceID
    hardware.simulateChange()

    expectNoDifference(notifier.overrides.map(\.selectedDevice), [.airPods])
    expectNoDifference(notifier.overrides.map(\.forcedDevice), [.builtIn])
  }

  @Test func doesNotNotifyOnInitialLaunchMismatch() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn], defaultInput: AudioDevice.airPods.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    let notifier = FakeOverrideNotifier()
    fixer.notifier = notifier

    fixer.start()

    expectNoDifference(notifier.overrides.isEmpty, true)
  }

  @Test func doesNotNotifyWhenDeviceListAlsoChanged() {
    let hardware = FakeAudioHardware(devices: [.builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.select(uid: AudioDevice.interface.uid)
    hardware.devices = [.builtIn]
    hardware.defaultInput = AudioDevice.builtIn.deviceID
    hardware.simulateChange()
    let notifier = FakeOverrideNotifier()
    fixer.notifier = notifier

    hardware.devices = [.builtIn, .airPods, .interface]
    hardware.defaultInput = AudioDevice.airPods.deviceID
    hardware.simulateChange()

    expectNoDifference(fixer.forcedDevice, .interface)
    expectNoDifference(notifier.overrides.isEmpty, true)
  }

  @Test func fallsBackThroughPriorityOrderRatherThanStraightToBuiltIn() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.setPriority([AudioDevice.interface.uid, AudioDevice.airPods.uid])
    fixer.isPriorityEnabled = true

    hardware.devices = [.airPods, .builtIn]
    hardware.simulateChange()

    expectNoDifference(fixer.forcedDevice, .airPods)
  }

  @Test func removeFromPriorityDropsDeviceFromTheFallbackOrder() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    fixer.setPriority([AudioDevice.interface.uid, AudioDevice.builtIn.uid])
    fixer.isPriorityEnabled = true

    fixer.removeFromPriority(uid: AudioDevice.interface.uid)

    expectNoDifference(fixer.priorityUIDs, [AudioDevice.builtIn.uid])
    expectNoDifference(fixer.forcedDevice, .builtIn)
  }

  @Test func enablesChainSavedWithMultipleDevicesBeforeTheEnabledFlagExisted() {
    defaults.set(AudioDevice.airPods.uid, forKey: "ForcedDeviceUID")
    defaults.set([AudioDevice.interface.uid, AudioDevice.builtIn.uid], forKey: "PriorityDeviceUIDs")
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)

    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.isPriorityEnabled, true)
    expectNoDifference(fixer.forcedDevice, .interface)
  }

  @Test func fixesOneEntryChainSavedBeforeTheEnabledFlagExisted() {
    defaults.set(AudioDevice.builtIn.uid, forKey: "ForcedDeviceUID")
    defaults.set([AudioDevice.interface.uid], forKey: "PriorityDeviceUIDs")
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)

    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.isPriorityEnabled, false)
    expectNoDifference(fixer.forcedDevice, .interface)
  }

  @Test func keepsLegacySingleDevicePreference() {
    defaults.set(AudioDevice.interface.uid, forKey: "ForcedDeviceUID")
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.builtIn.deviceID)

    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()

    expectNoDifference(fixer.isPriorityEnabled, false)
    expectNoDifference(fixer.forcedDevice, .interface)
  }

  @Test func listsBuiltInMicrophoneFirstAndOthersAlphabetically() {
    let lowercase = AudioDevice(deviceID: 140, uid: "Lowercase", name: "blackHole 2ch", isBuiltIn: false)
    let numbered = AudioDevice(deviceID: 141, uid: "Numbered", name: "USB Interface 10", isBuiltIn: false)
    let hardware = FakeAudioHardware(
      devices: [numbered, .airPods, .interface, .builtIn, lowercase],
      defaultInput: AudioDevice.builtIn.deviceID
    )
    let fixer = InputFixer(hardware: hardware, defaults: defaults)

    fixer.start()

    expectNoDifference(fixer.devices, [.builtIn, .airPods, lowercase, .interface, numbered])
  }

  @Test func reportsDeviceThatCannotBecomeDefaultInput() {
    let hardware = FakeAudioHardware(devices: [.airPods, .builtIn, .interface], defaultInput: AudioDevice.airPods.deviceID)
    hardware.rejectedDeviceIDs = [AudioDevice.interface.deviceID]
    let fixer = InputFixer(hardware: hardware, defaults: defaults)
    fixer.start()
    expectNoDifference(fixer.failedDevice, nil)

    fixer.select(uid: AudioDevice.interface.uid)
    expectNoDifference(fixer.failedDevice, .interface)
    expectNoDifference(fixer.isForcing, false)
    expectNoDifference(hardware.defaultInput, AudioDevice.builtIn.deviceID)

    fixer.select(uid: AudioDevice.builtIn.uid)
    expectNoDifference(fixer.failedDevice, nil)
    expectNoDifference(fixer.isForcing, true)
  }
}
