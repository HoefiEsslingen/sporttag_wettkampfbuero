import 'package:flutter/material.dart';

import '../tools/logger.util.dart';

class ZurueckButton extends StatelessWidget {
  final String label; // Beschriftung des Buttons
  final VoidCallback?
      auswertenDerErgebnisse; // Callback für das rufende Widget

  const ZurueckButton({
    super.key,
    required this.label, // Standardbeschriftung
    this.auswertenDerErgebnisse, // Callback-Funktion zur Rückgabe der Zeiten
  });

  @override
  Widget build(BuildContext context) {

    final log = getLogger();

    log.i('ZurueckButton: $label und $auswertenDerErgebnisse');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: auswertenDerErgebnisse == null
            ? () => Navigator.pop(context)
            : () {
                auswertenDerErgebnisse!();
                Navigator.pop(context);
              },
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
