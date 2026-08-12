import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/mixins/beste_zwei_auswertung_mixin.dart';
import 'package:sporttag/src/mixins/stationen_basis_mixin.dart';
import 'package:sporttag/src/tools/disziplin_kinder_liste.dart';
import 'package:sporttag/src/tools/stationen_in_durchgaengen.dart';

class Schlagwurf extends StatefulWidget {
  final Riege riegenPointer;

  const Schlagwurf({super.key, required this.riegenPointer});

  /// Aktivität vorbereiten
  @override
  SchlagwurfState createState() => SchlagwurfState();
}

class SchlagwurfState extends State<Schlagwurf>
    with StationenBasisMixin<Schlagwurf>, BesteZweiAuswertungMixin<Schlagwurf>  {

  @override
  void initState() {
    super.initState();
    // widget.toString() der Variable zuweisen
    stationsName = "Schlagwurf";
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
              'Jedes Kind darf in drei Durchgängen je mit einem Tennis- bzw. Schweifball werfen.\nDie erreichten Zonen werden notiert.\nDie zwei besten Würfe werden addiert.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodySmall, // Verwenden des Themes
            ),
            // Abstandshalter
            const SizedBox(height: 10),
            // Liste der Kinder in der ausgewählten Riege
            if (!istAusgewertet)
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StationenInDurchgaengen(
                            teilnehmer: kinderZurAnzeige,
                            anzahlDurchgaenge: 3,
                            onErgebnisseAbschliessen: besteZweiAuswerten,
                            iconWidget: Image.asset(
                              'assets/icons/speerwurf.png',
                              width: 30,
                              height: 30,
                            ),
                          ),
                        ));
                  },
                  // Rücksprung auf
                  child: const Text(
                    'In den ersten Durchgang starten',
                    textAlign: TextAlign.center,
                  )),
            // Abstandshalter
            const SizedBox(height: 10),
            // Zeigt die Liste der Kinder in der Riege an
            Expanded(
              child: DisziplinKinderListe(
                kinder: kinderZurAnzeige,
                selectedKinder: selectedKinder,
                ausgewerteteKinder: ausgewerteteKinder,
                kinderMitZeiten: kinderMitErreichtenPunkten,
                onSelectionChanged: (Kind kind, bool istSelektiert) {
                  setState(() {
                    // Keine Aktion
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
