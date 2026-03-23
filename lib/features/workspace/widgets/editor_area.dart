import 'package:flutter/material.dart';

class EditorArea extends StatelessWidget {
  const EditorArea({
    super.key,
    required this.pageTitle,
    required this.contentController,
    required this.onContentChanged,
  });

  final String pageTitle;
  final TextEditingController contentController;
  final ValueChanged<String> onContentChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pageTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: contentController,
              onChanged: onContentChanged,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Escribe el contenido de la página…',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                alignLabelWithHint: true,
              ),
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
