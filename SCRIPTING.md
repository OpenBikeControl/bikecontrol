# Scripting Guide (Experimental)

## What It Does
You can attach a custom Dart script to each controller device type (for example `ZwiftRide` or `ZwiftClickV2`).
When the device receives a BLE value update, BikeControl can run your script and write a new BLE payload based on the script output.

## Where To Find It
1. Look for the device in the devices list.
2. Click the menu (same menu that contains `Disconnect and Forget`).
3. Click `Run Script`.

## Script Storage
- Scripts are saved to a file per **device class/type**.
- Example: one script file for `ZwiftRide`, another for `ZwiftClickV2`.
- If no script file exists yet, the editor is prefilled with the default script from `lib/utils/interpreter.dart`.

## Required Signature
Your script must expose a top-level `main` function with:

```dart
Future<List<dynamic>> main(String characteristicUuid, List<int> data) async {
  return [characteristicUuid, data];
}
```

Validation checks on Save:
- A top-level `main` function exists.
- `main` has exactly 2 positional parameters.
- `main` returns `List<...>` or `Future<List<...>>`.

## Output Contract
`main(...)` must return a list with 0 items (nothing should happen), or 2 items (send a write command):
1. `String` characteristic UUID to write to.
2. `List<int>` byte payload (values must be in `0..255`).

Example:

```dart
Future<List<dynamic>> main(String characteristicUuid, List<int> data) async {
  final mirrored = data.reversed.toList();
  return [characteristicUuid, mirrored];
}
```

## Runtime Behavior
- Your script runs when a value from any characteristic is received for a device of the corresponding type.
- If the script exists for that device type, BikeControl uses the output and writes the value to the characteristic.
- If the returned characteristic does not exist on the connected device, the write is skipped and a log entry is added.

## Notes
- This is experimental and runs on every value update; keep scripts lightweight.
- Invalid scripts are rejected on Save and are not written to disk.
