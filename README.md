# Steadymic

Keeps the default audio input on a microphone of your choice when macOS switches the output to a headset with a microphone, such as AirPods or other Bluetooth headphones.
When macOS also switches the input to the headset's microphone, the Bluetooth connection drops to a low-quality call codec for playback.
Keeping the input on another device, such as the built-in microphone, keeps playback at full quality and saves headset battery, because the headset does not send audio back.
You can pick the forced input device, or define an ordered fallback chain of preferred input devices.

The app runs in the menu bar.

Download the compiled application from [releases](https://github.com/mAu888/Steadymic/releases).

## Building

Requires macOS 14 or later.

Open `Steadymic.xcworkspace`, not the `.xcodeproj`.
The workspace contains the app target and the `SteadymicPackage` Swift package, which holds the CoreAudio and device-forcing logic.

Run the tests with ⌘U in Xcode or `swift test` in `SteadymicPackage`.
