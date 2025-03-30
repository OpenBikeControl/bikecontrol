import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

import '../bluetooth/messages/notification.dart';
import '../main.dart';

class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  State<LogViewer> createState() => _LogviewerState();
}

class _LogviewerState extends State<LogViewer> {
  List<String> _actions = [];

  late StreamSubscription<BaseNotification> _actionSubscription;

  @override
  void initState() {
    super.initState();

    _actionSubscription = connection.actionStream.listen((data) {
      if (mounted) {
        setState(() {
          _actions.add('${DateTime.now().toString().split(" ").last}: $data');
          _actions = _actions.takeLast(30).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _actionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          shrinkWrap: true,
          children:
              _actions
                  .map(
                    (action) =>
                        Text(action, style: TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                  )
                  .toList(),
        ),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            onPressed: () {
              _actions.clear();
              setState(() {});
            },
            icon: Icon(Icons.clear),
          ),
        ),
      ],
    );
  }
}
