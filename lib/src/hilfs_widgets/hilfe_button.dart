import 'package:flutter/material.dart';
import '../tools/pdf_modal.dart';

enum HilfeTyp {
  pdf,
  text,
}

enum HilfeThema {
  anmeldung,
  riegeneinteilung,
  riegenzuordnung,
  auswertung,
  unbekannt,
}

class HelpIconButton extends StatelessWidget {
  final HilfeTyp typ;
  final String? titel; // z. B. Widget-Titel oder Stationsname
  final HilfeThema? thema; // nur für Text-Hilfe

  const HelpIconButton({
    super.key,
    required this.typ,
    this.titel,
    this.thema,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Hilfe anzeigen',
      onPressed: () {
        if (typ == HilfeTyp.pdf && titel != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => PdfModal(stationsName: titel!),
          );
        } else if (typ == HilfeTyp.text && thema != null) {
          _zeigeTextHilfe(context);
        }
      },
    );
  }

  void _zeigeTextHilfe(BuildContext context) {
    String inhalt;
    String dialogTitel;

    switch (thema) {
      case HilfeThema.anmeldung:
        dialogTitel = 'Hilfe zur Anmeldung';
        inhalt = '''
Hier können Sie Kinder für den Sporttag anmelden:

– Für vorab angemeldete Kinder bitte den Schalter "bezahlt" aktivieren (grün).
– Neue Kinder können über das Plus-Symbol mit Vorname, Nachname, Geschlecht und Jahrgang erfasst werden.
– Mit dem Stift-Symbol lassen sich Änderungen aktivieren.
– Speichern Sie über das Disketten-Symbol.
– Mit dem Kreuz-Symbol beenden Sie die Anmeldung – Änderungen werden gespeichert.
– Die Liste ist scrollbar.
– Nach Ende der Anmeldung erfolgt die automatische Riegeneinteilung.
''';
        break;

      case HilfeThema.riegeneinteilung:
        dialogTitel = 'Hilfe zur Riegeneinteilung';
        inhalt = '''
- Mit der Einteilung der Riegen können keine weiteren Kinder mehr angemeldet werden.
– Es werden alle gültig angemeldeten Kinder berücksichtigt. 
– Die Einteilung erfolgt nach Jahrgang & Geschlecht.
- Im DropDown-Menü können die einzelnen Riegen zur Ansicht ausgewählt werden.
– Eine Änderung der Riegeneinteilung ist nicht mehr möglich.
''';
        break;

      case HilfeThema.riegenzuordnung:
        dialogTitel = 'Hilfe zur Riegenzuordnung';
        inhalt = '''
- Per DropDown-Menü können die einzelnen Riegen zur Ansicht und zur Zordnung ausgewählt werden.
– Der / die Riegenführer:in scannt den QR-Code.
- Dadurch werden dem Riegenführer die Disziplinen für den Sporttag auf dem eigenen Gerät angezeigt.
- Der / die Riegenführer:in führt die Riege durch die Disziplinen.
''';
        break;

      case HilfeThema.auswertung:
        dialogTitel = 'Hilfe zur Auswertung';
        inhalt = '''
– Riegen, welche alle Disziplinen abgeschlossen haben, können ausgewertet werden.
– Die Kinder werden nach Gruppen (Jahrgang & Geschlecht) sortiert und angezeigt.
– Innerhalb der Gruppen werden die Kinder absteigend nach Punktzahl sortiert.
– Urkunden können geschreiben werden.
– Die entsprechenden Riegen werden als 'ausgewertet' markiert.
''';
        break;

      default:
        dialogTitel = 'Keine Hilfe verfügbar';
        inhalt = 'Für diesen Bereich ist keine Hilfe hinterlegt.';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(dialogTitel),
        content: Text(inhalt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/* Bisherige Löung erweitert um textuelle Hilfe
import 'package:flutter/material.dart';
import '../tools/pdf_modal.dart';

class HelpIconButton extends StatelessWidget {
  final String stationsName;

  const HelpIconButton({super.key, required this.stationsName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline), // ?-Icon
      tooltip: 'Zeige Informationen',
      onPressed: () {
        // Öffnet das modale Fenster
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => PdfModal(stationsName: stationsName),
        );
      },
    );
  }
}
* Ende bisherige Lösung */
