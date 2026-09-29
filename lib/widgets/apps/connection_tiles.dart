import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/widgets/apps/local_tile.dart';
import 'package:bike_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_mdns_tile.dart';
import 'package:bike_control/widgets/apps/zwift_tile.dart';
import 'package:bike_control/widgets/mouse_pair_widget.dart';
import 'package:bike_control/widgets/keyboard_pair_widget.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Builds connection method tiles shared by TrainerPage and onboarding wizard.
/// Returns both recommended and other connection method tiles based on enabled features.
({List<Widget> recommended, List<Widget> other}) buildConnectionMethodTiles({
  required bool small,
  required VoidCallback onUpdate,
}) {
  final showLocalAsOther =
      //(core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) &&
      false && core.logic.showLocalControl && !core.settings.getLocalEnabled();
  final showWhooshLinkAsOther =
      (core.logic.showObpBluetoothEmulator || core.logic.showObpMdnsEmulator) && core.logic.showMyWhooshLink;

  final recommendedTiles = [
    if (core.logic.showObpMdnsEmulator) OpenBikeControlMdnsTile(small: small),
    if (core.logic.showObpBluetoothEmulator) OpenBikeControlBluetoothTile(small: small),

    if (core.logic.showZwiftMsdnEmulator)
      ZwiftMdnsTile(
        small: small,
        onUpdate: () {
          core.connection.signalNotification(
            LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
          );
        },
      ),
    if (core.logic.showZwiftBleEmulator)
      ZwiftTile(
        small: small,
        onUpdate: () {
          core.connection.signalNotification(
            LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
          );
          onUpdate();
        },
      ),
    if (core.logic.showLocalControl && !showLocalAsOther) LocalTile(small: small),
    if (core.logic.showMyWhooshLink && !showWhooshLinkAsOther) MyWhooshLinkTile(small: small),
  ];

  final otherTiles = [
    if (showWhooshLinkAsOther) MyWhooshLinkTile(small: small),
    if (core.logic.showRemote) RemoteMousePairingWidget(small: small),
    if (core.logic.showLocalControl && showLocalAsOther) LocalTile(small: small),
    if (core.logic.showRemote && core.settings.getTrainerApp() is! Zwift) RemoteKeyboardPairingWidget(small: small),
  ];

  return (recommended: recommendedTiles, other: otherTiles);
}
