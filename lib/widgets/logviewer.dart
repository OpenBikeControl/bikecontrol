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
  List<({DateTime date, String entry})> _actions = [];

  late StreamSubscription<BaseNotification> _actionSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _actionSubscription = connection.actionStream.listen((data) {
      if (mounted) {
        setState(() {
          _actions.add((date: DateTime.now(), entry: data.toString()));
          _actions = _actions.takeLast(60).toList();
        });
        // scroll to the bottom
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _actionSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SelectionArea(
          child: ListView(
            controller: _scrollController,
            children:
                _actions
                    .map(
                      (action) => Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: action.date.toString().split(" ").last,
                              style: TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                            TextSpan(
                              text: "  ${action.entry}",
                              style: TextStyle(
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
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
