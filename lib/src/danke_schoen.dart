import 'package:flutter/material.dart';

class Dankeschoen extends StatelessWidget {
  const Dankeschoen({super.key, required this.titel});
  final String titel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titel,
          textAlign: TextAlign.center,
        ),
      ),
      body: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 24.0,
            ),
            children: <TextSpan>[
              TextSpan(
                text: 'Vielen Dank für Ihre Anmeldung\n',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26.0,
                ),
              ),
              TextSpan(
                text:
                    '''\nAm Sporttag selbst müssen Sie nur noch\ndie Startgebühr von € 2,-- bezahlen,\ndamit die Anmeldung aktiv wird.\n\nBitte finden Sie sich \nam 22.09.2024\num 10:30 Uhr\nim Waldheimstadion (Zollberg) ein.\n''',
              ),
            TextSpan(
                text:
                    '''\nIhrem Kind wünschen wir bereits heute viel Spass.\nWir sehen uns am\n22. September!\n\nGerne können Sie nun das Browserfenster schließen.'''),
            ],
          ),
        ),
      ),
    );
  }
}
