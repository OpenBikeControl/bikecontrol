import 'package:flutter/material.dart';

class ScannedDevicesPlaceholderWidget extends StatelessWidget {
  const ScannedDevicesPlaceholderWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(
            Icons.bluetooth,
            color: Colors.grey,
            size: 100,
          ),
        ),
        Text(
          'Scan For Devices',
          style: TextStyle(color: Colors.grey, fontSize: 22),
        )
      ],
    );
  }
}
