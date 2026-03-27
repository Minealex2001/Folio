import 'package:flutter/material.dart';

class FolioDialog extends StatelessWidget {
  const FolioDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.contentWidth,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double? contentWidth;

  @override
  Widget build(BuildContext context) {
    final body = contentWidth == null
        ? content
        : SizedBox(width: contentWidth, child: content);
    return AlertDialog(title: title, content: body, actions: actions);
  }
}
