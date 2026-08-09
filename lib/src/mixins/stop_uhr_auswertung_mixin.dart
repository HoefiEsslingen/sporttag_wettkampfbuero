import 'package:flutter/material.dart';

import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';

/// Auswertungs-Mixin für Stationen, die MyStopUhr verwenden
/// (Sprint, Lauf, Huerdenlauf/Bananenkartons, Stadionrunde).
///
/// Deckt sowohl einphasige Stationen (direkt Wertungslauf, z. B. Lauf)
/// als auch zweiphasige Stationen (Testlauf -> Wertungslauf, z. B. Sprint)
/// ab, gesteuert über das Feld `testLauf`.
///
/// WICHTIG für die UI-Konsistenz beim Rücksprung aus MyStopUhr:
/// Alle Zustandsänderungen, die zusammen einen konsistenten Anzeige-
/// Zustand ergeben (Punkte, ausgewerteteKinder, Sortierung, ggf. Toggle
/// von testLauf), werden in EINEM einzigen setState()-Aufruf gebündelt.
/// Zwei zeitlich getrennte setState()-Aufrufe würden einen Frame
/// erzeugen, in dem z. B. selectedKinder schon geleert, testLauf aber
/// noch nicht umgeschaltet ist -> kurzzeitig falscher/leerer Zustand.
mixin StopUhrAuswertungMixin<T extends StatefulWidget>
    on State<T>, StationenBasisMixin<T> {
  Map<Kind, int> kinderMitZeiten = {}; // Speichert gestoppte Zeiten/Punkte

  /// Nur für zweiphasige Stationen relevant (z. B. Sprint). Einphasige
  /// Stationen lassen dies auf false (Default) -> stopUhrAuswerten()
  /// wertet sofort, ohne jemals in den true-Zweig zu kommen.
  bool testLauf = false;

  /// Schutz gegen Doppel-Start: wird SYNCHRON gesetzt, sobald der
  /// Start-Button gedrückt wird (siehe starteStopUhr()), und erst wieder
  /// zurückgesetzt, wenn stopUhrAuswerten() vollständig fertig ist. Damit
  /// ist der Button gesperrt, EGAL wie lange die DB-Schreibvorgänge dauern
  /// und EGAL ob MyStopUhr den Callback vor dem Pop awaited oder nicht -
  /// die Sperre hängt an unserem eigenen State, nicht am Timing von
  /// MyStopUhr.
  bool wertungWirdVerarbeitet = false;

  /// Rechnet den Rohwert (z. B. Millisekunden, Runden) in Punkte um.
  /// Default: Rohwert = Punkte unverändert (z. B. Lauf: Runden direkt als
  /// Punktzahl). Stationen mit eigener Formel (Sprint, Huerdenlauf,
  /// Stadionrunde) überschreiben diese Methode.
  int berechnePunkte(int rohwert, Kind kind) => rohwert;

  /// Hook, der INNERHALB desselben setState()-Aufrufs ausgeführt wird,
  /// direkt nachdem die Wertungslauf-Ergebnisse übernommen wurden. Für
  /// zweiphasige Stationen (Sprint) hier testLauf wieder auf true setzen
  /// -> Button-Reset passiert atomar mit den übrigen UI-Änderungen, ohne
  /// einen zweiten, zeitlich versetzten Rebuild zu benötigen.
  void nachAuswertungHook() {}

  /// Von der konkreten Station statt eines direkten Navigator.push
  /// aufzurufen. Sperrt den Button SOFORT (synchron), bevor überhaupt
  /// navigiert wird - verhindert doppelte MyStopUhr-Aufrufe zuverlässig,
  /// unabhängig davon, wie schnell/langsam die spätere Auswertung ist.
  void starteStopUhr(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    if (wertungWirdVerarbeitet) return; // bereits in Bearbeitung -> ignorieren
    setState(() => wertungWirdVerarbeitet = true);
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  /// Callback für MyStopUhr.auswertenDerWerte.
  Future<void> stopUhrAuswerten(Map<Kind, int> resultate) async {
    log.i(
        'in auswerten -> Ergebnis erstes Kind: ${resultate.values.first.toString()}');

    if (testLauf) {
      // Testlauf-Phase beendet -> in die Wertungslauf-Phase wechseln.
      // Einzelner synchroner setState-Aufruf: kein DB-Zugriff, daher
      // kein Zeitfenster für einen inkonsistenten Zwischenzustand.
      if (!mounted) return;
      setState(() {
        testLauf = false;
        wertungWirdVerarbeitet = false; // Button für Wertungslauf freigeben
      });
      return;
    }

    // Wertungslauf: 1. Punkte berechnen (synchron)
    final punkteProKind = {
      for (final entry in resultate.entries)
        entry.key: berechnePunkte(entry.value, entry.key)
    };

    // 2. Punkte in 'resultate' speichern (bewusst OHNE setState davor/
    //    dazwischen, damit die Sprint-Seite währenddessen weiterhin den
    //    letzten konsistenten Zustand zeigt statt eines Teil-Updates).
    for (final entry in punkteProKind.entries) {
      log.i('in auswerten ${entry.value} für ${entry.key.nachname}');
      await kindRepository.speichereResultat(
          kind: entry.key, station: station!, punkte: entry.value);
    }
    for (final kind in resultate.keys) {
      await kindRepository.saveKind(kind: kind);
    }
    await markiereStationFallsKomplett();

    // 3. GENAU EIN setState-Aufruf für ALLE UI-relevanten Änderungen,
    //    inklusive des Hooks (z. B. testLauf-Reset bei Sprint). Dadurch
    //    gibt es nur einen einzigen Rebuild mit garantiert konsistentem
    //    Endzustand - keine Zwischenanzeige mit alten/leeren Daten mehr.
    if (!mounted) return;
    setState(() {
      kinderMitZeiten.addAll(punkteProKind);
      ausgewerteteKinder.addAll(resultate.keys);
      selectedKinder.clear();
      aktualisiereAnzeigeSortierung();
      nachAuswertungHook();
      wertungWirdVerarbeitet = false; // Button wieder freigeben
    });
  }

  @override
  void resetStationsdaten() {
    super.resetStationsdaten();
    kinderMitZeiten.clear();
    wertungWirdVerarbeitet = false;
  }
}
