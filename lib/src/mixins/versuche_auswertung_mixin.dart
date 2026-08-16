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

  /// Schutz gegen Doppel-Start, analog zu StopUhrAuswertungMixin und
  /// BesteZweiAuswertungMixin: wird SYNCHRON gesetzt, sobald der
  /// Start-Button gedrückt wird, und erst wieder zurückgesetzt, wenn
  /// versucheAuswerten() vollständig fertig ist ODER die Durchgangsserie
  /// über versucheAbgebrochen() explizit abgebrochen wurde.
  bool wertungWirdVerarbeitet = false;

  /// Multiplikator für die vom Eingabe-Widget gelieferten Punkte.
  /// Default: 1 (unverändert). HochWeitSprung überschreibt dies mit 2.
  int get punkteMultiplikator => 1;


  /// Von der konkreten Station statt eines direkten Navigator.push
  /// aufzurufen. Sperrt den Button SOFORT (synchron), bevor überhaupt
  /// navigiert wird.
  void starteVersuche(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    if (wertungWirdVerarbeitet) return; // bereits in Bearbeitung -> ignorieren
    setState(() => wertungWirdVerarbeitet = true);
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  /// Wird von VersucheInDurchgaengen als onAbgebrochen-Callback übergeben.
  /// Greift, wenn der Nutzer eine laufende Durchgangsserie über die
  /// Zurück-Bestätigung abbricht, OHNE dass versucheAuswerten() je
  /// aufgerufen wird. Ohne diesen Reset bliebe wertungWirdVerarbeitet
  /// dauerhaft true -> der Start-Button dieser Station wäre für immer im
  /// Spinner-Zustand gefangen (siehe StopUhrAuswertungMixin.stopUhrAbgebrochen
  /// bzw. BesteZweiAuswertungMixin.besteZweiAbgebrochen).
  void versucheAbgebrochen() {
    if (!mounted) return;
    setState(() => wertungWirdVerarbeitet = false);
  }
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
      wertungWirdVerarbeitet = false; // Sperre wieder freigeben
    });

    await markiereStationFallsKomplett();
  }

  /// Falls nach dem Laden bereits ALLE Kinder ein Resultat für diese
  /// Station haben, muss istAusgewertet ebenfalls gesetzt werden -- sonst
  /// würde der "Start"-Button trotz bereits abgeschlossener Station wieder
  /// angezeigt.
  /// Übernimmt einen beim (Neu-)Laden aus der DB gefundenen Punktewert
  /// (siehe StationenBasisMixin.uebernehmeVorhandeneResultate) in die
  /// stationseigene Punkte-Map, damit bereits erfasste Kinder nach einem
  /// App-Neustart korrekt mit ihren Punkten als ausgewertet erscheinen.
  ///
  /// WICHTIG: punkte kommt hier bereits aus der DB, also bereits inkl.
  /// punkteMultiplikator (der wurde beim ursprünglichen Speichern in
  /// versucheAuswerten() schon angewendet) -> hier NICHT nochmal
  /// multiplizieren.
  @override
  void uebernimmVorhandenePunkte(Kind kind, int punkte) {
    kinderMitErreichtenPunkten[kind] = punkte;
  }

  /// Falls nach dem Laden bereits ALLE Kinder ein Resultat für diese
  /// Station haben, muss istAusgewertet ebenfalls gesetzt werden -- sonst
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
