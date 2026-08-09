import 'package:flutter/material.dart';

import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';

/// Auswertungs-Mixin für Stationen, die StationenInDurchgaengen verwenden
/// (Drehwurf, Druckwurf, Schlagwurf, Stabfliegen, Zonenweitsprung).
///
/// Muster: pro Kind werden mehrere Versuche (Zonen) erfasst, die N besten
/// Versuche werden addiert.
mixin DurchgaengeAuswertungMixin<T extends StatefulWidget>
    on State<T>, StationenBasisMixin<T> {
  Map<Kind, int> kinderMitErreichtenPunkten = {};
  bool istAusgewertet = false;

  /// Anzahl der besten Versuche, die addiert werden. Default: 2
  /// (entspricht allen fünf Durchgänge-Stationen in diesem Projekt).
  int get anzahlBesterVersuche => 2;

  /// Callback für StationenInDurchgaengen.onErgebnisseAbschliessen.
  Future<void> durchgaengeAuswerten(Map<Kind, List<int>> resultate) async {
    for (final entry in resultate.entries) {
      final kind = entry.key;
      final werte = List<int>.from(entry.value)
        ..sort((a, b) => b.compareTo(a)); // absteigend sortieren
      final beste = werte.take(anzahlBesterVersuche).toList();
      final summe = beste.isEmpty ? 0 : beste.reduce((a, b) => a + b);

      kinderMitErreichtenPunkten[kind] = summe;
      await kindRepository.speichereResultat(
          kind: kind, station: station!, punkte: summe);
    }

    if (!mounted) return;
    setState(() {
      ausgewerteteKinder.addAll(resultate.keys);
      selectedKinder.clear();
      aktualisiereAnzeigeSortierung();
      istAusgewertet = ausgewerteteKinder.length == riegenKinder.length;
    });

    final zuSpeicherndeKinder = resultate.keys.toList();
    for (final kind in zuSpeicherndeKinder) {
      await kindRepository.saveKind(kind: kind);
    }

    await markiereStationFallsKomplett();
  }

  @override
  void resetStationsdaten() {
    super.resetStationsdaten();
    kinderMitErreichtenPunkten.clear();
  }
}
