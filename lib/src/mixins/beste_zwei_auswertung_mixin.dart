import 'package:flutter/material.dart';

import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';

/// Auswertungs-Mixin für Stationen, in denen jedes Kind mehrere Durchgänge
/// absolviert (StationenInDurchgaengen) und die zwei besten Ergebnisse
/// aufaddiert werden: Zonenweitsprung, Schlagwurf, Stabfliegen, Druckwurf,
/// Drehwurf.
///
/// Analog zu StopUhrAuswertungMixin: DB-Schreibvorgänge werden VOR dem
/// setState() sequenziell mit await ausgeführt, danach EIN synchroner
/// setState()-Block für alle UI-relevanten Änderungen. Das vermeidet den
/// Bug, der bisher in jeder Disziplin einzeln auftrat (async-Callback
/// innerhalb von setState()/forEach(), dessen await nicht abgewartet
/// wurde).
mixin BesteZweiAuswertungMixin<T extends StatefulWidget>
    on State<T>, StationenBasisMixin<T> {
  /// Speichert die Summe der zwei besten Ergebnisse je Kind.
  Map<Kind, int> kinderMitErreichtenPunkten = {};

  /// Steuert, ob der "Start"-Button (erster Durchgang) noch angezeigt wird.
  /// Diese Stationen lassen NICHT einzeln selektieren/starten -> alle
  /// Kinder der Riege treten gemeinsam in einer Durchgangsserie an, daher
  /// ein eigener Flag statt riegenKinder.length == ausgewerteteKinder.length
  /// als Auslöser für den Start-Button.
  bool istAusgewertet = false;

  /// Callback für StationenInDurchgaengen.onErgebnisseAbschliessen.
  /// resultate: je Kind die Liste der in den Durchgängen erreichten Werte
  /// (z. B. Zonen, Weiten). Die zwei besten Werte werden addiert.
  Future<void> besteZweiAuswerten(Map<Kind, List<int>> resultate) async {
    // 1. Punkte synchron berechnen (kein DB-Zugriff, kann vor setState
    //    passieren).
    final Map<Kind, int> summenProKind = {
      for (final entry in resultate.entries)
        entry.key: _besteZweiSumme(entry.value)
    };

    // 2. DB-Schreibvorgänge VOR dem setState, sequenziell mit await.
    //    (Vorher pro Disziplin: resultate.forEach((k, v) async {...})
    //    INNERHALB von setState() -> forEach wartet nicht auf async
    //    Callbacks, die await-Aufrufe liefen unkontrolliert weiter.)
    for (final entry in summenProKind.entries) {
      await kindRepository.speichereResultat(
          kind: entry.key, station: station!, punkte: entry.value);
    }
    for (final kind in resultate.keys) {
      await kindRepository.saveKind(kind: kind);
    }

    // 3. EIN synchroner setState-Aufruf für alle UI-relevanten Änderungen.
    if (!mounted) return;
    setState(() {
      kinderMitErreichtenPunkten.addAll(summenProKind);
      ausgewerteteKinder.addAll(resultate.keys);
      selectedKinder.clear();
      aktualisiereAnzeigeSortierung();
      istAusgewertet = true;
    });
  }

  /// Sortiert absteigend und addiert die zwei besten Werte.
  int _besteZweiSumme(List<int> werte) {
    final sortiert = List<int>.from(werte)..sort((a, b) => b.compareTo(a));
    return sortiert.take(2).reduce((a, b) => a + b);
  }

  @override
  void resetStationsdaten() {
    super.resetStationsdaten();
    kinderMitErreichtenPunkten.clear();
    istAusgewertet = false;
  }
}
