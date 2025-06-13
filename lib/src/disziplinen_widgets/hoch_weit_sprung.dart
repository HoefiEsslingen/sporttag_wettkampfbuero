import 'package:flutter/material.dart';
import '../hilfs_widgets/mein_listen_eintrag.dart';
import '../hilfs_widgets/meine_appbar.dart';
import '../hilfs_widgets/rueck_sprung_button.dart';
import '../klassen/kind_klasse.dart';
import '../tools/kind_repository.dart';
import '../tools/logger.util.dart';
import '../tools/mehrere_versuche_pro_durchgang.dart';

class HochWeitSprung extends StatefulWidget {
  final int riegenNummer;

  const HochWeitSprung({super.key, required this.riegenNummer});

  @override
  HochWeitSprungState createState() => HochWeitSprungState();
}

class HochWeitSprungState extends State<HochWeitSprung> {
  late String stationsName; // Variable für die zugewiesene Ausgabe
  // Repository-Objekte
  final KindRepository kindRepository = KindRepository();

  late int riegenNummer;
  List<Kind> riegenKinder = [];
  List<Kind> selectedKinder = [];
  List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
  Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
  var istAusgewertet = false;
  Map<Kind, int> kinderMitErreichtenPunkten = {}; // Speichert die Summe der beiden besten Würfe

  final log = getLogger();

  @override
  void initState() {
    super.initState();
    stationsName = 'Hoch-Weitsprung';
    riegenNummer = widget.riegenNummer;
    _loadData();
  }

  Future<void> _loadData() async {
    riegenKinder = await kindRepository.loadKinderAusRiege(mitRiegenNummer: riegenNummer);
    // Liste zur Anzeige aufbereiten -> nicht ausgewertete Kinder oben
    kinderZurAnzeige =
        kindRepository.zurAnzeigeSortieren(alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    setState(() {});
  }

  Future<void> _auswertungAbschliessen(Map<Kind, int> ergebnisse) async {
    for (var dasKind in riegenKinder) {
      final punkte = ergebnisse[dasKind];
      kinderMitErreichtenPunkten[dasKind] = punkte! * 2;
      dasKind.erreichtePunkte += punkte * 2;
      await kindRepository.saveKindToDatabase(kind: dasKind);
    }
    setState(() {
      istAusgewertet = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: stationsName,
        stationsName: stationsName,
      ),
      body: riegenKinder.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Text(
                  'Jedes Kind hat pro Durchgang zwei Versuche.\nBestandene Versuche erhöhen den Punktestand um 1.\nEs gibt so viele Durchgänge, bis alle Kinder ausgeschieden sind.\nAm Ende werden die Punkte verdoppelt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                // Liste der Kinder in der ausgewählten Riege
                if (!istAusgewertet)
                  ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VersucheInDurchgaengen(
                                teilnehmer: riegenKinder,
                                anzahlVersuche: 2,
                                onErgebnisseAbschliessen:
                                    _auswertungAbschliessen,
                                iconWidget: Image.asset(
                                  'assets/icons/hochsprung.png',
                                  width: 30,
                                  height: 30,
                                ),
                              ),
                            ));
                      },
                      child: const Text(
                        'In den ersten Durchgang starten',
                        textAlign: TextAlign.center,
                      )),
                // Abstandshalter
                const SizedBox(height: 10),
                // Zeigt die Liste der Kinder in der Riege an
                // Hier können die Kinder, welche an der nächsten Runde teilnehmen sollen ausgewählt werden
                Expanded(
                  child: ListView.builder(
                    itemCount: riegenKinder.length,
                    itemBuilder: (context, index) {
                      final kind = kinderZurAnzeige[index];
                      final zeit = kinderMitErreichtenPunkten[kind]; // Gestoppte Zeit abrufen
                      final istAusgewertet = ausgewerteteKinder.contains(kind);
                      final istSelektiert = selectedKinder.contains(kind);
                      return MeinListenEintrag(
                        kind: kind,
                        istAusgewertet: istAusgewertet,
                        istSelektiert: istSelektiert,
                        erreichtePunkte: zeit,
                        onSelectionChanged: (Kind kind, bool istSelektiert) {
                          setState(() {
                            // Keine Aktion
                          });
                        },
                      );
                    },
                  ),
                ),
                if (istAusgewertet)
                  ZurueckButton(label: 'Nächste Disziplin steht an', riegenNummer: riegenNummer,),
              ],
            ),
    );
  }
}