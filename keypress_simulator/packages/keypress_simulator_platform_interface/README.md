# keypress_simulator_platform_interface

[![pub version][pub-image]][pub-url]

[pub-image]: https://img.shields.io/pub/v/keypress_simulator_platform_interface.svg
[pub-url]: https://pub.dev/packages/keypress_simulator_platform_interface

A common platform interface for the [keypress_simulator](https://pub.dev/packages/keypress_simulator) plugin.

## Usage

To implement a new platform-specific implementation of keypress_simulator, extend `KeyPressSimulatorPlatform` with an implementation that performs the platform-specific behavior, and when you register your plugin, set the default `KeyPressSimulatorPlatform` by calling `KeyPressSimulatorPlatform.instance = MyPlatformKeyPressSimulator()`.

## License

[MIT](./LICENSE)
