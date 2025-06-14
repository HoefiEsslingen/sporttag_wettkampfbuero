import 'package:flutter/material.dart';

enum HilfeThema {
  anmeldung,
  riegeneinteilung,
  auswertung,
  unbekannt,
}

HilfeThema hilfeThemaVonString(String widgetName) {
  switch (widgetName) {
    case 'Sporttag - Anmeldung':
      return HilfeThema.anmeldung;
    case 'Riegen einteilen':
      return HilfeThema.riegeneinteilung;
    case 'Auswerten mit Urkunden':
      return HilfeThema.auswertung;
    default:
      return HilfeThema.unbekannt;
  }
}

class BeschreibungButton extends StatelessWidget {
  final String widgetName;

  const BeschreibungButton({super.key, required this.widgetName});

  @override
  Widget build(BuildContext context) {
    final thema = hilfeThemaVonString(widgetName);

    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Hilfe zur Anwendung',
      onPressed: () {
        String titel = 'Hilfe';
        String inhalt;

        switch (thema) {
          case HilfeThema.anmeldung:
            titel = 'Hilfe zur Anmeldung';
            inhalt = '''
Hier können Sie Kinder für den Sporttag anmelden:

– Für vorab angemeldete Kinder bitte den Schalter "bezahlt" aktivieren (grün).
– Neue Kinder können über das Plus-Symbol mit Vorname, Nachname, Geschlecht und Jahrgang erfasst werden.
– Mit dem Stift-Symbol lassen sich Änderungen aktivieren.
– Speichern Sie über das Disketten-Symbol.
– Mit dem Kreuz-Symbol beenden Sie die Anmeldung – Änderungen werden gespeichert.
– Die Liste ist scrollbar.
– Nach Ende der Anmeldung erfolgt automatisch die Riegeneinteilung.
''';
            break;

          case HilfeThema.riegeneinteilung:
            titel = 'Hilfe zur Riegeneinteilung';
            inhalt = '''
Hier erfolgt die automatische Einteilung der Kinder in Riegen:

– Es werden alle gültig angemeldeten Kinder berücksichtigt.
– Die Einteilung erfolgt nach Geschlecht und Jahrgang.
– Mit einem Klick auf „Einteilen“ werden die Gruppen erstellt und gespeichert.
''';
            break;

          case HilfeThema.auswertung:
            titel = 'Hilfe zur Auswertung';
            inhalt = '''
Hier können die Urkunden nach Auswertung der Disziplinen gedruckt werden:

– Wählen Sie die Gruppe (Jahrgang & Geschlecht).
– Die Kinder werden nach erreichter Punktzahl sortiert angezeigt.
– Die Auswahl einer Riege entfernt sie aus der Liste.
''';
            break;

          default:
            inhalt = 'Für "$widgetName" ist keine Hilfe hinterlegt.';
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(titel),
            content: Text(inhalt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* Erste Version
import 'package:flutter/material.dart';

class BeschreibungButton extends StatelessWidget {
  final String widgetName;

  const BeschreibungButton({super.key, required this.widgetName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Hilfe zur Anwendung',
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hilfe zur Anwendung'),
            content: 
            widgetName == 'Sporttag - Anmeldung' 
            ? const Text(
              'Hier können Sie Kinder für den Sporttag anmelden.\n\n'
              '– Wenn vorab angemeldete Kinder Kinder die Startgebühr bezahlt haben bitte den Schalter aktivieren (grün setzen).\n'
              '- Neue Kinder können über den Plus-Button mit Vorname, Nachname, Geschlecht und Jahrgang erfasst werden.\n'
              '– Änderungen können mit dem Stift aktiviert und dann durchgeführt werden.\n'
              '– Mit dem Disketten-Symbol können alle Änderungen gespeichert werden.\n'
              '– Die Anwendung beenden Sie mit dem Kreuz-Symbol. Alle Änderungen werden gespeichert.\n'
              '– Die Liste ist scrollbar.\n'
              '– Nach Ende der Anmeldung werden die Riegen automatisch eingeteilt.',
            )
            : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
* Ende Erste Version */
