import 'package:flutter/material.dart';

class Pause extends StatelessWidget {
  const Pause({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guten Appetit'),
        automaticallyImplyLeading: false, // Standard-Zurück-Pfeil ausblenden
      ),
      body: const Center(
        child: 
            Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  textAlign:TextAlign.center, 
                  'Vielen Dank,\ndass Sie die Riege durch den Sporttag-Spiele führen.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 80), // Abstand zwischen Text und Button
                Text(
                  textAlign:TextAlign.center, 
                  'Die Mittagspause haben Sie und Ihre Riegenkinder verdient.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 80), // Abstand zwischen Text und Button
                Text(
                  textAlign:TextAlign.center, 
                  'Sie können die App schließen,\nwährend Ihrer Mittagspause.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
      ),
    );
  }

}