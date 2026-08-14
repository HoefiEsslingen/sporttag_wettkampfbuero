import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/mixins/stop_uhr_auswertung_mixin.dart';
import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/stop_uhr.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';

class Huerdenlauf extends StatefulWidget {
  final Riege riegenPointer;

  const Huerdenlauf({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  HuerdenlaufState createState() => HuerdenlaufState();
}

class HuerdenlaufState extends State<Huerdenlauf>
    with StationenBasisMixin<Huerdenlauf>, StopUhrAuswertungMixin<Huerdenlauf> {
  @override
  initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = "Huerdenlauf";
    riegenPointer = widget.riegenPointer;
    ladeStationsdaten();
  }

  @override
  void dispose() {
    resetStationsdaten();
    super.dispose();
  }

  /// Stationsspezifische Formel: Zeit in Sekunden -> Punkte (0 bis 5).
  /// Ersetzt das frühere private _werteZeitenAus().
  @override
  int berechnePunkte(int zeitInMillis, Kind kind) {
    final seconds = zeitInMillis ~/ 1000;
    if (seconds > 17) return 0;
    if (seconds > 16) return 1;
    if (seconds > 15) return 2;
    if (seconds > 14) return 3;
    if (seconds > 13) return 4;
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
            Text(
              'Bitte selektieren Sie die an der nächsten Runde teilnehmenden Kinder.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
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
                          auswertenDerWerte: stopUhrAuswerten, // Ergebnisse verarbeiten)
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
                      'Wertungslauf mit ausgewählten Namen',
                      textAlign: TextAlign.center,
                    ),
            ),
            // Hier können die Kinder aus der Riege gewählt werden, welche im nächsten Durchgang miteinander die Runden laufen.
            Expanded(
              child: DisziplinKinderListe(
                kinder: kinderZurAnzeige,
                selectedKinder: selectedKinder,
                ausgewerteteKinder: ausgewerteteKinder,
                kinderMitZeiten: kinderMitZeiten,
                onSelectionChanged: (Kind kind, bool istSelektiert) {
                  setState(() {
                    // mehrere Kinder können ausgewählt werden
                    if (istSelektiert) {
                      selectedKinder.add(kind);
                    } else {
                      selectedKinder.remove(kind);
                    }
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
                  label: 'Nächste Disziplin steht an',
                  riegenPointer: riegenPointer,
                  stationsPointer: station),
          ],
        ),
      ),
    );
  }
}
