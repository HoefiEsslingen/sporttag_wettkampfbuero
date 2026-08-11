import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/mixins/stop_uhr_auswertung_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/stop_uhr.dart';

class Lauf extends StatefulWidget {
  final Riege riegenPointer;

  const Lauf({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  LaufState createState() => LaufState();
}

class LaufState extends State<Lauf>
    with StationenBasisMixin<Lauf>, StopUhrAuswertungMixin<Lauf> {
  @override
  void initState() {
    super.initState();
    stationsName = '30sec-Lauf';
    riegenPointer = widget.riegenPointer;
    // stopUhrAuswerten() wertet beim ersten Aufruf direkt (kein Testlauf).
    // berechnePunkte() muss nicht überschrieben werden: der Mixin-Default
    // (Rohwert = Punkte) entspricht genau "Runden direkt als Punktzahl".
    ladeStationsdaten();
  }

  @override
  void dispose() {
    resetStationsdaten();
    super.dispose();
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
              'In 30 sek laufen mehrere Kinder (empfohlen 3 oder 4)\nso viele Runden wie möglich. \nGezählt wird zu Beginn jeder halben Runde',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            // Liste der Kinder in der ausgewählten Riege
            ElevatedButton(
              onPressed: (selectedKinder.isNotEmpty && !wertungWirdVerarbeitet)
                  // Wenn selektierte Kinder vorhanden sind, dann den Timer starten
                  ? () {
                      starteStopUhr(
                        context,
                        builder: (context) => MyStopUhr(
                          teilNehmer: selectedKinder,
                          rufendeStation: stationsName,
                          auswertenDerWerte:
                              stopUhrAuswerten, // Ergebnisse verarbeiten)
                        ),
                      );
                    }
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
                stationsPointer: station,
              ),
          ],
        ),
      ),
    );
  }
}
