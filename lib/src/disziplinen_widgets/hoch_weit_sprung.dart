import 'package:flutter/material.dart';
import '../hilfs_widgets/mein_listen_eintrag.dart';
import '../hilfs_widgets/meine_appbar.dart';
import '../hilfs_widgets/rueck_sprung_button.dart';
import '../klassen/kind_klasse.dart';
import '../tools/kind_repository.dart';
import '../tools/logger.util.dart';
import '../tools/mehrere_versuche_pro_durchgang.dart';
import '../tools/stationen_repository.dart';

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
  final StationenRepository stationenRepository = StationenRepository();

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
                  const ZurueckButton(label: 'Nächste Disziplin steht an'),
              ],
            ),
    );
  }
}
/**************************************************
 * Version Chat-GPT
import 'package:flutter/material.dart';
import '../hilfs_widgets/mein_listen_eintrag.dart';
import '../hilfs_widgets/meine_appbar.dart';
import '../hilfs_widgets/rueck_sprung_button.dart';
import '../klassen/kind_klasse.dart';
import '../tools/kind_repository.dart';
import '../tools/logger.util.dart';

class HochWeitSprung extends StatefulWidget {
  final int riegenNummer;

  const HochWeitSprung({super.key, required this.riegenNummer});

  @override
  HochWeitSprungState createState() => HochWeitSprungState();
}

class HochWeitSprungState extends State<HochWeitSprung> {
  final KindRepository kindRepository = KindRepository();
  final log = getLogger();

  late int riegenNummer;
  List<Kind> riegenKinder = [];
  List<Kind> kinderZurAnzeige = [];
  Map<Kind, int> kinderPunkte = {};
  Map<Kind, int> kinderVersuche = {};
  Set<Kind> ausgeschiedeneKinder = {};
  bool istAusgewertet = false;

  @override
  void initState() {
    super.initState();
    riegenNummer = widget.riegenNummer;
    _loadData();
  }

  Future<void> _loadData() async {
    riegenKinder = await kindRepository.ladeKinderDerRiege(riegenNummer);
    kinderZurAnzeige = List.from(riegenKinder);
    for (var kind in riegenKinder) {
      kinderPunkte[kind] = 0;
      kinderVersuche[kind] = 0;
    }
    setState(() {});
  }

  void _naechsterDurchgang() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Durchgang starten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kinderZurAnzeige.map((kind) {
            bool istAusgeschieden = ausgeschiedeneKinder.contains(kind);
            bool hatErstenVersuchBestanden = kinderVersuche[kind]! % 2 == 1;
            return ListTile(
              title: Text('${kind.vorname} ${kind.nachname}'),
              subtitle: Text(
                  'Punkte: ${kinderPunkte[kind]}, Versuche: ${kinderVersuche[kind]}'),
              trailing: istAusgeschieden
                  ? Text('Ausgeschieden')
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: hatErstenVersuchBestanden
                              ? null
                              : () {
                                  _verarbeiteVersuch(kind, true);
                                },
                          child: Text('Drüber'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: hatErstenVersuchBestanden
                              ? null
                              : () {
                                  _verarbeiteVersuch(kind, false);
                                },
                          child: Text('Gerissen'),
                        ),
                      ],
                    ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pruefeAusscheiden();
            },
            child: Text('Durchgang beenden'),
          ),
        ],
      ),
    );
  }

  void _verarbeiteVersuch(Kind kind, bool bestanden) {
    setState(() {
      kinderVersuche[kind] = kinderVersuche[kind]! + 1;
      if (bestanden) {
        kinderPunkte[kind] = kinderPunkte[kind]! + 1;
      }
    });
  }

  void _pruefeAusscheiden() {
    setState(() {
      for (var kind in kinderZurAnzeige) {
        if (kinderVersuche[kind]! >= 2 &&
            kinderPunkte[kind]! == 0 &&
            !ausgeschiedeneKinder.contains(kind)) {
          ausgeschiedeneKinder.add(kind);
        }
      }
      if (ausgeschiedeneKinder.length == riegenKinder.length) {
        _auswertungAbschliessen();
      }
    });
  }

  Future<void> _auswertungAbschliessen() async {
    setState(() {
      istAusgewertet = true;
    });
    for (var kind in riegenKinder) {
      kind.erreichtePunkte += kinderPunkte[kind]! * 2;
      await kindRepository.saveKindToDatabase(kind);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: 'Hoch-Weit-Sprung',
        stationsName: 'Hoch-Weit-Sprung',
      ),
      body: Center(
        child: Column(
          children: [
            Text(
              'Jedes Kind hat pro Durchgang zwei Versuche.\nBestandene Versuche erhöhen den Punktestand um 1.\nEs gibt so viele Durchgänge, bis alle Kinder ausgeschieden sind.\nAm Ende werden die Punkte verdoppelt.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 10),
            if (!istAusgewertet)
              ElevatedButton(
                onPressed: _naechsterDurchgang,
                child: Text('Ersten Durchgang starten'),
              ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: kinderZurAnzeige.length,
                itemBuilder: (context, index) {
                  final kind = kinderZurAnzeige[index];
                  final punkte = kinderPunkte[kind];
                  final istAusgeschieden =
                      ausgeschiedeneKinder.contains(kind);
                  return MeinListenEintrag(
                    kind: kind,
                    istAusgewertet: istAusgeschieden,
                    istSelektiert: false,
                    erreichtePunkte: punkte,
                    onSelectionChanged: (Kind kind, bool istSelektiert) {},
                  );
                },
              ),
            ),
            if (istAusgewertet)
              ZurueckButton(label: 'Nächste Disziplin steht an'),
          ],
        ),
      ),
    );
  }
}
************************************************* */
