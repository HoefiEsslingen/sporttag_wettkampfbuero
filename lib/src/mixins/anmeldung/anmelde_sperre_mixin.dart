import 'package:flutter/material.dart';

/// Stellt eine einheitliche "UI gesperrt während Speichern"-Logik bereit.
/// Blockiert sowohl Interaktionen als auch den Zurück-Button, solange
/// eine asynchrone Aktion läuft.
///
/// Verwendung im build():
///   return sperrbaresPopScope(
///     child: Scaffold(...),
///   );
///
/// Für Aktionen:
///   await fuehreGesperrtAus(() async {
///     await irgendwasSpeichern();
///   });
mixin AnmeldeSperreMixin<T extends StatefulWidget> on State<T> {
  bool _istGesperrt = false;
  bool get istGesperrt => _istGesperrt;

  /// Führt [aktion] aus, während die UI gesperrt ist (setState triggert
  /// automatisch die Overlay-Anzeige, sofern sperrbaresPopScope genutzt wird).
  Future<void> fuehreGesperrtAus(Future<void> Function() aktion) async {
    setState(() => _istGesperrt = true);
    try {
      await aktion();
    } finally {
      if (mounted) {
        setState(() => _istGesperrt = false);
      }
    }
  }

  /// Wrapped das übergebene [child] mit PopScope + Sperr-Overlay.
  Widget sperrbaresPopScope({required Widget child}) {
    return PopScope(
      canPop: !_istGesperrt,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die Anmeldung wird gerade verarbeitet – bitte warten.'),
          ),
        );
      },
      child: Stack(
        children: [
          child,
          if (_istGesperrt)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}