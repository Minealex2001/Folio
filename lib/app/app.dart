import 'package:flutter/material.dart';

import '../features/workspace/workspace_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Folio',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: Colors.blueGrey.shade700,
          surface: const Color(0xFFF5F5F5),
          onSurface: Colors.black87,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      ),
      home: const WorkspacePage(),
    );
  }
}
