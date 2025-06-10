import 'package:flutter/material.dart';

class DankeEnde extends StatelessWidget {
  const DankeEnde({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vielen herzlichen Dank!'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Standard-Zurück-Pfeil ausblenden
      ),
      body: const Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                textAlign: TextAlign.center,
                'Vielen Dank,\ndass Sie die Riege durch die Sportttag-Spiele geführt haben.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 80), // Abstand zwischen Text und Button
              Text(
                textAlign: TextAlign.center,
                'Bitte informieren Sie die Turnierleitung,\ndass Ihre Riege die Sporttag-Spiele beendet hat.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 80), // Abstand zwischen Text und Button
              Text(
                textAlign: TextAlign.center,
                'Sie können die App jetzt schließen.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ]),
      ),
    );
  }
}
