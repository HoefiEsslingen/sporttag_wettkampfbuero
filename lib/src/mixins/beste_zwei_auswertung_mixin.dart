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

  /// Schutz gegen Doppel-Start, analog zu
  /// StopUhrAuswertungMixin.wertungWirdVerarbeitet: wird SYNCHRON gesetzt,
  /// sobald der Start-Button gedrückt wird, und erst wieder zurückgesetzt,
  /// wenn besteZweiAuswerten() vollständig fertig ist. Ohne diesen Schutz
  /// zeigt die UI zwischen dem Rücksprung aus StationenInDurchgaengen und
  /// dem abschließenden setState() weiterhin den Start-Button an, obwohl
  /// im Hintergrund noch DB-Schreibvorgänge laufen -> ein zweiter Klick
  /// könnte eine parallele Auswertung anstoßen.
  bool wertungWirdVerarbeitet = false;

  /// Von der konkreten Station statt eines direkten Navigator.push
  /// aufzurufen. Sperrt den Button SOFORT (synchron), bevor überhaupt
  /// navigiert wird.
  void starteDurchgaenge(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    if (wertungWirdVerarbeitet) return; // bereits in Bearbeitung -> ignorieren
    setState(() => wertungWirdVerarbeitet = true);
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  /// Wird von StationenInDurchgaengen als onAbgebrochen-Callback übergeben.
  /// Greift, wenn der Nutzer eine laufende Durchgangsserie über die
  /// Zurück-Bestätigung abbricht, OHNE dass besteZweiAuswerten() je
  /// aufgerufen wird. Ohne diesen Reset bliebe wertungWirdVerarbeitet
  /// dauerhaft true -> der Start-Button dieser Station wäre für immer im
  /// Spinner-Zustand gefangen (siehe StopUhrAuswertungMixin.stopUhrAbgebrochen).
  void besteZweiAbgebrochen() {
    if (!mounted) return;
    setState(() => wertungWirdVerarbeitet = false);
  }

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
      wertungWirdVerarbeitet = false; // Sperre wieder freigeben, wenn Verarbeitung abgeschlossen
    });
  }

  /// Sortiert absteigend und addiert die zwei besten Werte.
  int _besteZweiSumme(List<int> werte) {
    final sortiert = List<int>.from(werte)..sort((a, b) => b.compareTo(a));
    return sortiert.take(2).reduce((a, b) => a + b);
  }

  /// Übernimmt einen beim (Neu-)Laden aus der DB gefundenen Punktewert
  /// (siehe StationenBasisMixin.uebernehmeVorhandeneResultate) in die
  /// stationseigene Punkte-Map, damit bereits erfasste Kinder nach einem
  /// App-Neustart korrekt mit ihren Punkten als ausgewertet erscheinen.
  @override
  void uebernimmVorhandenePunkte(Kind kind, int punkte) {
    kinderMitErreichtenPunkten[kind] = punkte;
  }

  /// Falls nach dem Laden bereits ALLE Kinder ein Resultat für diese
  /// Station haben (z. B. App wurde erst nach vollständigem Abschluss neu
  /// gestartet), muss istAusgewertet ebenfalls gesetzt werden -- sonst
  /// würde der "Start"-Button trotz bereits abgeschlossener Station wieder
  /// angezeigt.
  @override
  void resetStationsdaten() {
    super.resetStationsdaten();
    kinderMitErreichtenPunkten.clear();
    istAusgewertet = false;
    wertungWirdVerarbeitet = false;
  }
}
