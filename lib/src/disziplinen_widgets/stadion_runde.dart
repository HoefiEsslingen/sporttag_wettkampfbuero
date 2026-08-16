import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/mixins/stop_uhr_auswertung_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/stop_uhr.dart';

class Stadionrunde extends StatefulWidget {
  final Riege riegenPointer;

  const Stadionrunde({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  StadionrundeState createState() => StadionrundeState();
}

class StadionrundeState extends State<Stadionrunde>
    with
        StationenBasisMixin<Stadionrunde>,
        StopUhrAuswertungMixin<Stadionrunde> {
  @override
  void initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = "Stadionrunde";
    riegenPointer = widget.riegenPointer;
    ladeStationsdaten();
  }

  /// Läuft innerhalb von ladeStationsdaten(), NACHDEM riegenKinder UND
  /// ausgewerteteKinder (inkl. eines eventuellen Wiederaufnahme-Standes)
  /// feststehen, aber VOR dem abschließenden setState() -> kein separater,
  /// zeitlich versetzter Rebuild nötig (siehe StationenBasisMixin).
  ///
  /// Alle noch nicht ausgewerteten Kinder der Riege werden vorselektiert.
  /// Bereits ausgewertete Kinder (z. B. nach einem App-Neustart mitten in
  /// der Stadionrunde) werden bewusst NICHT vorselektiert -- sie haben ihr
  /// Resultat schon, ein erneutes Starten der Uhr für sie wäre falsch.
  @override
  void nachLadenHook() {
    // Alle Kinder der Riege als selektiert markieren
    selectedKinder.addAll(
      riegenKinder.where((kind) => !ausgewerteteKinder.contains(kind)),
);
  }

  @override
  void dispose() {
    // resetStationsdaten() (aus StationenBasisMixin) übernimmt bereits
    // riegenKinder/selectedKinder/kinderZurAnzeige/ausgewerteteKinder, und
    // wird durch StopUhrAuswertungMixin um kinderMitZeiten/
    // wertungWirdVerarbeitet erweitert -> die vorherigen manuellen
    // .clear()-Aufrufe hier waren redundant.
    resetStationsdaten();
    super.dispose();
  }

  /// Stationsspezifische Formel: Zeit in Sekunden -> Punkte (0 bis 5).
  /// Ersetzt das frühere private _werteZeitenAus().
  @override
  int berechnePunkte(int zeitInMillis, Kind kind) {
    final seconds = zeitInMillis ~/ 1000;
    // > 3:20 min -> 0 Punkte
    if (seconds > 200) return 0;
    // 2:40 min bis 3:20 min -> 1 Punkt
    if (seconds > 160) return 1;
    // 2:00 min bis 2:40 min -> 2 Punkte
    if (seconds > 120) return 2;
    // 1:40 min bis 2:00 min -> 3 Punkte
    if (seconds > 100) return 3;
    // 1:20 min bis 1:40 min -> 4 Punkte
    if (seconds > 80) return 4;
    // < 1:20 min -> 5 Punkte
    return 5;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: stationsName,
        stationsName: stationsName,
      ),
      body: Center(
          child: Column(
        children: [
          // Wertungslauf -Button anzeigen
          // in Stop-Uhr wechseln
          // Kinder mit Zeit speichern
          Text(
            '\nAlle Kinder nehmen an der Stadion-Runde teil.\nSollten Kinder nicht teilnehmen, dann diese bitte abwählen.',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyLarge, // Verwenden des Themes
          ),
          // Abstandshalter
          const SizedBox(height: 10),
          Text(
            'Je nach Verlauf des Rundenlaufs können Sie die Kinder in ihrer Reihenfolge verschieben.',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyLarge,
                 // Verwenden des Themes
          ),
          // Abstandshalter
          const SizedBox(height: 10),
          // Liste der Kinder in der ausgewählten Riege
          ElevatedButton(
            onPressed: (selectedKinder.isNotEmpty && !wertungWirdVerarbeitet)
                // Wenn selektierte Kinder vorhanden sind, dann den Timer starten
                ? () => starteStopUhr(
                      context,
                      builder: (context) => MyStopUhr(
                        teilNehmer: selectedKinder,
                        rufendeStation: stationsName,
                        auswertenDerWerte: stopUhrAuswerten, // Ergebnisse verarbeiten
                        onAbgebrochen: stopUhrAbgebrochen,
                      ),
                    )
                : null,
              child: wertungWirdVerarbeitet
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Starte Timer (alle Kinder der Riege nehmen teil!)',
                      textAlign: TextAlign.center,
                    ),
            ),
          // Alle Kinder werden als selektiert dargestellt
          // Die Kinder können hier durch einen Klick auf den Namen von der Teilnahme an der Stadion-Runde gewählt werden
          Expanded(
            child: DisziplinKinderListe(
              kinder: kinderZurAnzeige,
              selectedKinder: selectedKinder,
              ausgewerteteKinder: ausgewerteteKinder,
              kinderMitZeiten: kinderMitZeiten,
              onSelectionChanged: (Kind kind, bool istSelektiert) {
                setState(() {
                  // // mehrere Kinder können ausgewählt werden
                  // if (istSelektiert) {
                  //   selectedKinder.add(kind);
                  // } else {
                  //   selectedKinder.remove(kind);
                  // }
                });
              },
            ),
          ),
          if (riegenKinder.length ==
              ausgewerteteKinder.length) // Beenden-Button anzeigen
            // wenn alle Kinder ausgewertet sind wird
            // zur Disziplinen-Übersicht weitergeleitet und zuvor
            // die Anzahl der absolvierten Disziplinen für die aktuelle Riege erhöht
            ZurueckButton(
              label: 'Ende des Kinder-Sporttages',
              riegenPointer: riegenPointer,
              stationsPointer: station,
            ),
        ],
      )),
    );
  }
}
