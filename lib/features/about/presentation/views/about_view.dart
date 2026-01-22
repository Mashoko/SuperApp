import 'package:flutter/material.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Center(
            child: Column(
              children: const <Widget>[
                Text('GitHub:\nhttps://github.com/cloudwebrtc/dart-sip-ua.git'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

