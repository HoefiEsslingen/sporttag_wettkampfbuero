import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';

/// Wiederverwendbarer Bestätigungs-Dialog.
///
/// Zeigt eine Liste von [Kind]-Objekten (Vor-/Nachname, Geschlecht, Jahrgang)
/// an und fragt den Anwender, ob diese Auswahl bestätigt werden soll.
///
/// Einsatzorte:
///  - Vorab-Anmeldung: genau ein neu erfasstes Kind wird zur Kontrolle
///    angezeigt, bevor es gespeichert wird.
///  - Stationen (z.B. Lauf): mehrere ausgewählte Kinder werden zur Kontrolle
///    angezeigt, bevor der Wertungslauf gestartet wird.
///
/// Rückgabewert von [zeigen]:
///  - `true`  -> Anwender hat bestätigt
///  - `false` -> Anwender hat abgebrochen (oder Dialog anders geschlossen)
class KinderBestaetigenDialog extends StatelessWidget {
  final String titel;
  final List<Kind> kinder;
  final String bestaetigenText;
  final String abbrechenText;
  final String? hinweisText;

  const KinderBestaetigenDialog({
    super.key,
    required this.kinder,
    this.titel = 'Bitte bestätigen',
    this.bestaetigenText = 'Bestätigen',
    this.abbrechenText = 'Abbrechen',
    this.hinweisText,
  });

  /// Öffnet den Dialog modal und liefert erst zurück, wenn der Anwender
  /// eine Entscheidung getroffen hat.
  ///
  /// [context]       BuildContext, von dem aus der Dialog geöffnet wird.
  /// [kinder]        Liste der anzuzeigenden Kinder (kann auch nur 1 Eintrag enthalten).
  /// [titel]         Überschrift des Dialogs.
  /// [hinweisText]   Optionaler zusätzlicher Hinweistext oberhalb der Kinderliste,
  ///                 z.B. "Soll diese Person tatsächlich angemeldet werden?".
  /// [bestaetigenText] Beschriftung des Bestätigen-Buttons.
  /// [abbrechenText]   Beschriftung des Abbrechen-Buttons.
  // static Future<bool> zeigen({
  //   required BuildContext context,
  //   required List<Kind> kinder,
  //   String titel = 'Bitte bestätigen',
  //   String bestaetigenText = 'Bestätigen',
  //   String abbrechenText = 'Abbrechen',
  //   String? hinweisText,
  // }) async {
  //   final ergebnis = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => KinderBestaetigenDialog(
  //       kinder: kinder,
  //       titel: titel,
  //       bestaetigenText: bestaetigenText,
  //       abbrechenText: abbrechenText,
  //       hinweisText: hinweisText,
  //     ),
  //   );
  //   // Wenn der Dialog z.B. per Zurück-Taste/Escape geschlossen wird,
  //   // kommt "null" zurück -> das werten wir als Abbruch.
  //   return ergebnis ?? false;
  // }

static Future<bool> zeigen({
    required BuildContext context,
    required List<Kind> kinder,
    String titel = 'Bitte bestätigen',
    String bestaetigenText = 'Bestätigen',
    String abbrechenText = 'Abbrechen',
    String? hinweisText,
  }) async {
    final ergebnis = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return PopScope(
            canPop: false, // Browser-Zurück soll den Dialog NICHT schließen
            child: Center(
              child: KinderBestaetigenDialog(
                kinder: kinder,
                titel: titel,
                bestaetigenText: bestaetigenText,
                abbrechenText: abbrechenText,
                hinweisText: hinweisText,
              ),
            ),
          );
        },
      ),
    );
    // Wenn der Dialog dennoch ohne Ergebnis geschlossen wird,
    // kommt "null" zurück -> das werten wir als Abbruch.
    return ergebnis ?? false;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hinweisText != null) ...[
              Text(hinweisText!),
              const SizedBox(height: 16),
            ],
            for (final kind in kinder) _KindZeile(kind: kind),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(abbrechenText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.green),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(bestaetigenText),
        ),
      ],
    );
  }
}

/// Einzelne Zeile für ein Kind innerhalb des Dialogs.
class _KindZeile extends StatelessWidget {
  final Kind kind;

  const _KindZeile({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            kind.geschlecht == 'w' ? Icons.female : Icons.male,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${kind.vorname} ${kind.nachname}  (Jg. ${kind.jahrgang})',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
