import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A dialog that asks for text (a name, a shortcut, pasted JSON).
///
/// shadcn's [AlertDialog] is as wide as its content, and a [TextField] takes
/// all the width it gets — so on a desktop window the dialog stretched across
/// the whole screen. This keeps it at a phone dialog's width; on a narrower
/// screen it is as wide as the screen allows, as before.
class BkInputDialog extends StatelessWidget {
  const BkInputDialog({super.key, this.title, this.content, this.actions});

  /// Wide enough for a name or a one-line command, never wider.
  static const double maxWidth = 420;

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: AlertDialog(title: title, content: content, actions: actions),
    );
  }
}
