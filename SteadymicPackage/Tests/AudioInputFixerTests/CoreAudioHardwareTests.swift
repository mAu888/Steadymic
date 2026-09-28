@testable import AudioInputFixer
import CustomDump
import Foundation
import Testing

@MainActor
struct CoreAudioHardwareTests {
  @Test func releasingObservationRemovesHandler() async {
    // Only this observation's key is asserted, since tests in other suites run in parallel and can
    // add and remove their own registry entries.
    let keysBefore = CoreAudioHardware.ListenerRegistry.keys
    let addedKeys: Set<Int>
    do {
      let observation = CoreAudioHardware().observeChanges {}
      addedKeys = CoreAudioHardware.ListenerRegistry.keys.subtracting(keysBefore)
      expectNoDifference(addedKeys.count, 1)
      withExtendedLifetime(observation) {}
    }

    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }

    expectNoDifference(CoreAudioHardware.ListenerRegistry.keys.isDisjoint(with: addedKeys), true)
  }
}
