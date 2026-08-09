import 'package:flutter/material.dart';

import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';

/// Auswertungs-Mixin für Stationen, die VersucheInDurchgaengen verwenden
/// (aktuell: HochWeitSprung).
///
/// Muster: alle Kinder treten gemeinsam an, pro Durchgang gibt es mehrere
/// Versuche; das Eingabe-Widget liefert bereits die verrechnete Punktzahl
/// pro Kind, die hier noch mit einem stationsspezifischen Multiplikator
/// versehen wird.
mixin VersucheAuswertungMixin<T extends StatefulWidget>
    on State<T>, StationenBasisMixin<T> {
  Map<Kind, int> kinderMitErreichtenPunkten = {};
  bool istAusgewertet = false;

  /// Multiplikator für die vom Eingabe-Widget gelieferten Punkte.
  /// Default: 1 (unverändert). HochWeitSprung überschreibt dies mit 2.
  int get punkteMultiplikator => 1;

  /// Callback für VersucheInDurchgaengen.onErgebnisseAbschliessen.
  Future<void> versucheAuswerten(Map<Kind, int> ergebnisse) async {
    for (final kind in riegenKinder) {
      final rohPunkte = ergebnisse[kind];
      if (rohPunkte == null) continue;

      final punkte = rohPunkte * punkteMultiplikator;
      kinderMitErreichtenPunkten[kind] = punkte;
      await kindRepository.speichereResultat(
          kind: kind, station: station!, punkte: punkte);
    }

    if (!mounted) return;
    setState(() {
      ausgewerteteKinder.addAll(riegenKinder);
      istAusgewertet = true;
      aktualisiereAnzeigeSortierung();
    });

    await markiereStationFallsKomplett();
  }

  @override
  void resetStationsdaten() {
    super.resetStationsdaten();
    kinderMitErreichtenPunkten.clear();
  }
}
