
import 'package:flutter/material.dart';

enum MessageType { success, error, info }

/// Show a loading dialog that blocks user interaction
Future<void> showLoadingDialog(BuildContext context, {String message = 'جاري المعالجة...'}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (BuildContext context) {
      return PopScope(
        canPop: false, // Prevent dismissing with back button
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Hide loading dialog
void hideLoadingDialog(BuildContext context) {
  Navigator.of(context).pop();
}

Future<void> showMessageDialog(BuildContext context, {required String title, required String message, required MessageType type}) async {
  IconData icon;
  Color color;

  switch (type) {
    case MessageType.success:
      icon = Icons.check_circle;
      color = Colors.green;
      break;
    case MessageType.error:
      icon = Icons.error;
      color = Colors.red;
      break;
    case MessageType.info:
      icon = Icons.info;
      color = Colors.blue;
      break;
  }

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Flexible(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(child: Text(message, textAlign: TextAlign.center)),
        actions: <Widget>[
          TextButton(
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)), // <-- THE FIX IS HERE
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
