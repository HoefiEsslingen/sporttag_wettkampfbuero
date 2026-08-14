import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';

class TeilnehmerListe extends StatefulWidget {
  final List<Kind> teilNehmer;
  final Map<Kind, int>
      kindMitWerten; // Enthält entweder gestoppte Zeiten oder Rundenzahlen
  final bool isRunning; // Zeigt an, ob die Stoppuhr gerade läuft
  final int modus; // 0 = Timer, 1 = StoppUhr, 2 = RundenModus
  final void Function(Kind kind, int value)
      onValueChanged; // Callback zur Übergabe des Werts

  const TeilnehmerListe({
    super.key,
    required this.teilNehmer,
    required this.kindMitWerten,
    required this.isRunning,
    required this.modus,
    required this.onValueChanged,
  });

  @override
  State<TeilnehmerListe> createState() => _TeilnehmerListeState();
}

class _TeilnehmerListeState extends State<TeilnehmerListe> {
  final Map<Kind, int> _rundenMap = {}; // Lokale Speicherung der Rundenzähler
  // Initialisiere die Übergabeparameter
  List<Kind> get teilNehmer => widget.teilNehmer;
  bool get isRunning => widget.isRunning;
  int get modus => widget.modus;
  Map<Kind, int> get kindMitWerten => widget.kindMitWerten;
  // Callback-Funktion zur Übergabe des Werts
  void Function(Kind kind, int value) get onValueChanged => widget.onValueChanged;

  @override
  void initState() {
    super.initState();
    // Initialisiere Rundenzähler mit vorhandenen Werten oder 1
    for (final kind in widget.teilNehmer) {
      _rundenMap[kind] = kindMitWerten[kind] ?? 1;
    }
  }

  // Erhöht den Rundenzähler, nur wenn die Uhr läuft
  void _increment(Kind kind) {
    if (!isRunning) return;
    setState(() {
      _rundenMap[kind] = _rundenMap[kind]! + 1;
      onValueChanged(kind, _rundenMap[kind]!);
    });
  }

  // Verringert den Rundenzähler (nicht unter 1), nur wenn die Uhr läuft
  void _decrement(Kind kind) {
    if (!isRunning) return;
    if ((_rundenMap[kind] ?? 1) > 1) {
      setState(() {
        _rundenMap[kind] = _rundenMap[kind]! - 1;
        onValueChanged(kind, _rundenMap[kind]!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.teilNehmer.length,
      itemBuilder: (context, index) {
        final kind = teilNehmer[index];
        final wert = kindMitWerten[kind];

        // Modus 2: Runden-Modus mit Plus- und Minus-Buttons
        if (widget.modus == 2) {
          return MeinKartenEintrag(
            istAusgewertet: wert != null,
            trailingFullWidth: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Button zum Verringern
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: isRunning ? () => _decrement(kind) : null,
                ),
                // Anzeige des aktuellen Rundenwerts
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_rundenMap[kind] ?? 1}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Button zum Erhöhen
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: isRunning ? () => _increment(kind) : null,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${kind.vorname} ${kind.nachname}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Modus 0 und 1: Timer/StoppUhr-Modus
        return MeinKartenEintrag(
          istAusgewertet: wert != null,
          trailingFullWidth: true,
          trailing: wert != null
              // Zeige Haken, wenn schon gestoppt
              ? const Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 28,
                )
              : isRunning
                  // Button zur Zeitnahme (nur aktiv, wenn Uhr läuft)
                  ? ElevatedButton(
                      onPressed: () => onValueChanged(kind, 0),
                      child: Text(kind.vorname),
                    )
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${kind.vorname} ${kind.nachname}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (wert != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Gestoppte Zeit: ${(wert / 1000).toStringAsFixed(1)} Sekunden',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
