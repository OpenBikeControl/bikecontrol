import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
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
          _actions = _actions.takeLast(kIsWeb ? 1000 : 60).toList();
        });
        if (_scrollController.hasClients) {
          // scroll to the bottom
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeInOut,
          );
        }
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
    return _actions.isEmpty
        ? Container()
        : SafeArea(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SelectionArea(
                  child: GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _actions = [];
                      });
                    },
                    child: ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _scrollController,
                      shrinkWrap: true,
                      reverse: true,
                      children: _actions
                          .map(
                            (action) => Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: action.date.toString().split(" ").last,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                      fontFamily: "monospace",
                                      fontFamilyFallback: <String>["Courier"],
                                    ),
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
                ),
              ),
            ),
          );
  }
}
