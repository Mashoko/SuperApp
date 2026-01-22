import 'package:flutter/material.dart';

import 'views/screens/dialer_shell.dart';

class CatchCallApp extends StatelessWidget {
  const CatchCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatchCall',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const DialerShell(),
    );
  }
}

