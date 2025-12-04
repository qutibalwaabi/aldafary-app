
import 'package:flutter/material.dart';

class NewPage extends StatelessWidget {
  const NewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Page'),
      ),
      body: const Center(
        child: Text(
          'This is a new page created by Gemini!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
