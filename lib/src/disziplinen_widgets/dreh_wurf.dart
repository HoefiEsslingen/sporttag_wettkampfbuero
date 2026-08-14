import 'package:flutter/material.dart';
import 'package:sporttag/src/mixins/beste_zwei_auswertung_mixin.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/stationen_in_durchgaengen.dart';

class Drehwurf extends StatefulWidget {
  final Riege riegenPointer;

  const Drehwurf({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  DrehwurfState createState() => DrehwurfState();
}

class DrehwurfState extends State<Drehwurf>
    with StationenBasisMixin<Drehwurf>, BesteZweiAuswertungMixin<Drehwurf> {
  @override
  void initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = "Drehwurf";
    riegenPointer = widget.riegenPointer;
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
              'Jedes Kind darf in drei Durchgängen je einmal einen Reifen schleudern.\nDie erreichten Zonen werden notiert.\nDie zwei besten Drehwürfe werden addiert.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodyLarge, // Verwenden des Themes
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            // Liste der Kinder in der ausgewählten Riege
            ElevatedButton(
              onPressed: (selectedKinder.isNotEmpty && !wertungWirdVerarbeitet)
                  ? () => starteDurchgaenge(
                        context,
                        builder: (context) => StationenInDurchgaengen(
                          teilnehmer: selectedKinder
                              .toList(), //auskommentiert:  kinderZurAnzeige,
                          anzahlDurchgaenge: 3,
                          onErgebnisseAbschliessen: besteZweiAuswerten,
                          onAbgebrochen: besteZweiAbgebrochen,
                          iconWidget: Image.asset(
                            'assets/icons/diskus.png',
                            width: 30,
                            height: 30,
                          ),
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
                      'In die Wertungsdurchgänge starten',
                      textAlign: TextAlign.center,
                    ),
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            // Zeigt die Liste der Kinder in der Riege an
            // Hier kann das Kind gewählt werden, welches als nächstes drei Schleuder-Versuche hat
            Expanded(
              child: DisziplinKinderListe(
                kinder: kinderZurAnzeige,
                selectedKinder: selectedKinder,
                ausgewerteteKinder: ausgewerteteKinder,
                kinderMitZeiten: kinderMitErreichtenPunkten,
                onSelectionChanged: (Kind kind, bool istSelektiert) {
                  setState(() {
                    // es kann nur ein Kind ausgewählt werden, welches die drei Versuche hat
                    if (selectedKinder.isEmpty && istSelektiert) {
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
