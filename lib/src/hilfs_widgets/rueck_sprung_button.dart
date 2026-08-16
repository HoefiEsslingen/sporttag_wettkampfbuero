import 'package:flutter/material.dart';

import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/tools/logger.util.dart';

class ZurueckButton extends StatelessWidget {
  final String label; // Beschriftung des Buttons
  final Riege? riegenPointer; // Zeiger auf die Riege mit der Riegen-Nummer, falls benötigt
  final Station? stationsPointer; // Zeiger auf die Station, falls benötigt
  final VoidCallback? auswertenDerErgebnisse; // Callback für das rufende Widget

  const ZurueckButton({
    super.key,
    required this.label, // Standardbeschriftung
    this.riegenPointer,
    this.stationsPointer,
    this.auswertenDerErgebnisse, // Callback-Funktion zur Rückgabe der Zeiten
  });

  @override
  Widget build(BuildContext context) {
    final log = getLogger();

    log.i('ZurueckButton: $label und $auswertenDerErgebnisse');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: (auswertenDerErgebnisse == null && riegenPointer == null)
            ? () => Navigator.pop(context)
            : auswertenDerErgebnisse != null // Wenn eine Auswertung erforderlich ist
                ? () {
                    auswertenDerErgebnisse!();
                    Navigator.pop(context);
                  }
                : riegenPointer != null // Wenn eine Riegen-Nummer angegeben ist
                    ? () {
                        Navigator.pop(context);
                      }
                    : () => Navigator.pop(context),
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }  
}
