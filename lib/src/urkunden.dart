import 'package:flutter/material.dart';

class UrkundenDruck extends StatefulWidget {
  const UrkundenDruck({super.key, required this.titel});
  final String? titel;

  /// Aktivität vorbereiten
  @override
  UrkundenDruckState createState() => UrkundenDruckState();
}

class UrkundenDruckState extends State<UrkundenDruck> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel!),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Urkundendruck'),
            const SizedBox(height: 40),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text(
                  "Urkundendruck abschließen",
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
