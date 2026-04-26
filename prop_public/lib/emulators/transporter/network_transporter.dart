import 'dart:io';

import 'package:prop/emulators/transporter/transporter.dart';

class NetworkTransporter extends Transporter {
  final Socket socket;
  NetworkTransporter({required super.definition, required this.socket});

  @override
  void sendCharacteristicNotification(String characteristicUUID, List<int> data, {int responseCode = 1}) {
    // TODO: implement sendCharacteristicNotification
  }

  void handleIncomingData(List<int> data) {}
}
