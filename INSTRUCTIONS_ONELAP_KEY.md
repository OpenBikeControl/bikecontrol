# Magene Onelap Key Five-Button Controller

This beta driver supports the legacy `Onelap Key` five-button BLE controller. Physical devices advertise names such as `Onelap Key_12224`; name matching is case-insensitive. Other Magene products, QED/QED2 devices, and unnamed devices that happen to expose the same private service are outside the detection scope.

## Connection and mapping

Wake the controller, stop other applications from holding its BLE connection, and let BikeControl scan. The controller may advertise only the Battery Service, so the driver uses the device name for discovery. After connecting, it finds service `8ce5cc01-0a4d-11e9-ab14-d663bd873d93` and subscribes to characteristic `8ce5cc02-0a4d-11e9-ab14-d663bd873d93`. The driver does not send an initialization command.

The default single-click mapping is: Up = Shift Up, Down = Shift Down, Left/Right = menu navigation, Center = Select. The diagram uses the molded faces, not those actions: circle on Up, triangle on Left, square on Right, a dot pad on Down, and ONELAP on the center hub. All five buttons are registered through the existing keymap system, so BikeControl's custom mappings and output transports remain available. Hardware-reported long presses use the shared long-press dispatch path; the driver releases them when a follow-up valid frame or a disconnect arrives. It does not replace the hardware gesture with a software timer.

## Notification layout

A notification must contain at least 11 bytes, with `data[1] == 0xf5` and `data[2] == 0x10`. Indexes are zero-based.

| Byte | Meaning |
| --- | --- |
| `data[5] & 0x1f` | Device type: 0 general, 1 left-hand, 2 right-hand; unknown types are ignored |
| `(data[5] >> 5) & 7` | Device index |
| `data[8]` | Single-click bit mask |
| `data[10]` | Long-press bit mask |

Mask bits `01/02/04/08/10` represent Center, Left, Up, Right, and Down respectively. The upper three bits have no verified five-button meaning. The driver leaves other fields uninterpreted instead of inventing sequence numbers or checksums. Consecutive identical click frames are dispatched independently.

For the verified hardware, `8bf510e503000000000004` reports an Up long press and `8bf510e503000004000000` reports the corresponding release. The release frame does not trigger another Shift Up. The all-zero event mask in the initial hold frame also produces no click.

## Verification

On 2026-11-05, one `Onelap Key_12224` was captured on macOS. All five single-click gestures and all five long-press gestures passed the ten-step physical acceptance check. The real gesture frames and long-press release frames are stored in `test/fixtures/onelap_key_capture.json` and replayed by `test/onelap_key_test.dart`. Tests also cover notification subscription, the absence of initialization writes, native and Web detection paths, device isolation, malformed frames, and long-press cleanup.

The physical capture used a separate BLE diagnostic tool. BikeControl's Dart implementation is validated by replaying those frames and by simulated BLE tests. This does not claim real-device validation on Windows, Android, or iOS, nor in-game validation in MyWhoosh. No extracted application DLLs, firmware, account data, or authentication material are included.
