import 'dart:async';
import 'dart:io';

import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../bluetooth/messages/notification.dart';

class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  State<LogViewer> createState() => _LogviewerState();
}

class _LogviewerState extends State<LogViewer> {
  late StreamSubscription<BaseNotification> _actionSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _actionSubscription = core.connection.actionStream.listen((data) {
      if (mounted) {
        setState(() {});
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.i18n.logViewer).bold,
              OutlineButton(
                child: Text(context.i18n.share),
                onPressed: () {
                  final logText = core.connection.lastLogEntries
                      .map((entry) => '${entry.date.toString().split(" ").last}  ${entry.entry}')
                      .join('\n');
                  Clipboard.setData(ClipboardData(text: logText));

                  buildToast(title: context.i18n.logsHaveBeenCopiedToClipboard);
                },
              ),
            ],
          ),
          core.connection.lastLogEntries.isEmpty
              ? Container()
              : Expanded(
                  child: Card(
                    child: SelectionArea(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: SizedBox(
                          width: double.infinity,
                          child: Text.rich(
                            TextSpan(
                              children: core.connection.lastLogEntries
                                  .map(
                                    (action) => [
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
                                        text: "  ${action.entry}\n",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                  .flatten()
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

          if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Text('Logs file: '),
                  SelectableText('${Directory.current.path}/app.log').inlineCode,
                ],
              ).small,
            ),
        ],
      ),
    );
  }
}
