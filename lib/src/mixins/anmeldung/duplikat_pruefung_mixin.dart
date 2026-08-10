import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/mixins/anmeldung/kind_pruef_ergebnis.dart';
import 'package:sporttag/src/tools/anmeldung/kind_validator.dart';

/// Stellt eine einheitliche Duplikat-Prüfung mit Bestätigungsdialog
/// für alle Anmelde-Screens bereit (Sporttag-Anmeldung, Vorabanmeldung).
///
/// Verwendung:
///   class MeinState extends State<MeinWidget> with DuplikatPruefungMixin<MeinWidget> {
///     ...
///     final ok = await pruefeAufDuplikat(kind, alleKinder);
///     if (!ok) { /* Nutzer hat abgelehnt */ }
///   }
mixin DuplikatPruefungMixin<T extends StatefulWidget> on State<T> {
  /// Prüft, ob [kind] ein Duplikat in [alleKinder] hat.
  /// Falls ja, wird ein Bestätigungsdialog gezeigt.
  ///
  /// Rückgabewert:
  ///   true  → kein Duplikat gefunden ODER Nutzer hat bestätigt (weiter machen)
  ///   false → Duplikat gefunden UND Nutzer hat abgelehnt (Vorgang abbrechen)
  Future<bool> pruefeAufDuplikat(Kind kind, List<Kind> alleKinder) async {
    final duplikat = KindValidator.findeDuplikat(kind, alleKinder);
    if (duplikat == null) {
      return true; // kein Duplikat, normal weiter
    }

    final bestaetigt = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag bereits vorhanden'),
        content: Text(
          'Es existiert bereits ein Eintrag mit identischen Daten:\n\n'
          '${duplikat.vorname} ${duplikat.nachname}, '
          '${duplikat.geschlecht}, ${duplikat.jahrgang}\n\n'
          'Ist Ihre Eingabe korrekt und soll zusätzlich gespeichert werden?',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nein, korrigieren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ja, trotzdem speichern'),
          ),
        ],
      ),
    );

    return bestaetigt ?? false;
  }
  /// Kombiniert Namens-Validierung und Duplikat-Prüfung in einem Aufruf.
  /// Zeigt bei Namensfehlern einen Fehlerdialog, bei Duplikaten den
  /// Bestätigungsdialog aus pruefeAufDuplikat().
  ///
  /// Gibt ein KindPruefErgebnis zurück, das der Aufrufer auswerten kann,
  /// ohne die Prüfung selbst erneut ausführen zu müssen.
  Future<KindPruefErgebnis> pruefeKindVorSpeichern(
    Kind kind,
    List<Kind> alleKinder,
  ) async {
    // 1. Namens-Validierung
    final namensFehler = KindValidator.validiereNamen(kind);
    if (namensFehler.isNotEmpty) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bitte Eingaben prüfen'),
            content: Text(namensFehler.join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return KindPruefErgebnis.namensfehler;
    }

    // 2. Duplikat-Prüfung (inkl. Bestätigungsdialog bei Bedarf)
    final duplikatOk = await pruefeAufDuplikat(kind, alleKinder);
    if (!duplikatOk) {
      return KindPruefErgebnis.duplikatAbgelehnt;
    }

    return KindPruefErgebnis.gueltig;
  }
}