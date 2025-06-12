import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pause.dart';
import 'danke_ende.dart';
import 'disziplinen_widgets/hoch_weit_sprung.dart';
import 'disziplinen_widgets/lauf.dart';
import 'disziplinen_widgets/bananen_kartons.dart';
import 'disziplinen_widgets/sprint.dart';
import 'disziplinen_widgets/schlag_wurf.dart';
import 'disziplinen_widgets/dreh_wurf.dart';
import 'disziplinen_widgets/stab_fliegen.dart';
import 'disziplinen_widgets/druck_wurf.dart';
import 'disziplinen_widgets/weit_sprung.dart';
import 'disziplinen_widgets/stadion_runde.dart';
import 'klassen/kind_klasse.dart';
import 'tools/kind_repository.dart';
import 'tools/logger.util.dart';
import 'hilfs_widgets/meine_appbar.dart';

class Wettbewerb extends StatefulWidget {
  final int riegenNummer;
  final String wettbewerbsTyp;

  const Wettbewerb(
      {super.key, required this.riegenNummer, required this.wettbewerbsTyp});

  @override
  WettbewerbState createState() => WettbewerbState();
}

class WettbewerbState extends State<Wettbewerb> {
  final KindRepository kindRepository = KindRepository();
  List<Kind> riegenKinder = [];
  final log = getLogger();
  final bool isDevelopment = true;
  late Map<String, Widget Function()> disziplinPages;
  final Set<String> besuchteDisziplinen = {};
  bool pauseGemacht = false;

  int get riegenNummer => widget.riegenNummer;
  String get wettbewerbsTyp => widget.wettbewerbsTyp;

  @override
  void initState() {
    super.initState();

    disziplinPages = {
      'Schlagwurf': () => Schlagwurf(riegenNummer: riegenNummer),
      'Drehwurf': () => Drehwurf(riegenNummer: riegenNummer),
      'Druckwurf': () => Druckwurf(riegenNummer: riegenNummer),
      'Sprint': () => Sprint(riegenNummer: riegenNummer),
      '30m Banankartons': () => Bananenkartons(riegenNummer: riegenNummer),
      '30 sec Lauf': () => Lauf(riegenNummer: riegenNummer),
      'Stabfliegen': () => Stabfliegen(riegenNummer: riegenNummer),
      'Hoch-Weitsprung': () => HochWeitSprung(riegenNummer: riegenNummer),
      'Zonenweitsprung': () => Zonenweitsprung(riegenNummer: riegenNummer),
      'Stadionrunde': () => Stadionrunde(riegenNummer: riegenNummer),
    };

    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDisziplinen = prefs.getStringList('besuchteDisziplinen');
    if (savedDisziplinen != null) {
      setState(() {
        besuchteDisziplinen.addAll(savedDisziplinen);
      });
    }
    final savedPause = prefs.getBool('pauseGemacht');
    if (savedPause != null) {
      setState(() {
        pauseGemacht = savedPause;
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'besuchteDisziplinen',
      besuchteDisziplinen.toList(),
    );
    prefs.setBool('pauseGemacht', pauseGemacht);
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Widget Function()> angeboteneDisziplinen =
        wettbewerbsTyp != 'Zehnkampf'
            ? Map.fromEntries(disziplinPages.entries.take(5))
            : disziplinPages;
    // Hier wird die letzte Station ermittelt, diese sollte am Ende auswählbaren Disziplinen stehen
    // und ist erst dann auswählbar, wenn alle anderen Disziplinen besucht wurden
    final String dieLetzeStation = angeboteneDisziplinen.keys.last; // hier: Stadionrunde
    final List<String> disziplinNamen = angeboteneDisziplinen.keys.toList();

    return Scaffold(
      appBar: MeineAppBar(
        titel: 'Riege $riegenNummer Sporttag-Wettbewerbe',
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // TODO: Liste der Disziplinen muss scrollbar gemacht werden
          children: [
            ...disziplinNamen.map((disziplin) {
              // Überprüft, ob die Disziplin bereits besucht wurde
              final istBesucht = besuchteDisziplinen.contains(disziplin);
              // Überprüft, ob es sich bei der 'disziplin' um 'dieLetzteStation' handelt. Diese soll erst ganz am Ende auswählbar sein.
              final istLetzteStation = disziplin == dieLetzeStation;
              // Stellt sicher, dass alle anderen Disziplinen außer dieLetzeStation bereits abgeschlossen sind.
              final alleAnderenBesucht = besuchteDisziplinen.length ==
                  angeboteneDisziplinen.length - 1;

              // Logik zur Aktivierung des Buttons: Der Button darf nur aktiv sein, wenn die Disziplin noch nicht besucht wurde
              // Und: Falls es sich um dieLetzeStation handelt, darf er nur aktiv sein, 
              // wenn alle anderen Disziplinen bereits besucht wurden
              final istAktiv = !istBesucht &&
                  (!istLetzteStation || alleAnderenBesucht);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: istAktiv
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  angeboteneDisziplinen[disziplin]?.call() ??
                                  const Center(
                                      child: Text('Disziplin nicht gefunden')),
                            ),
                          );
                          setState(() {
                            besuchteDisziplinen.add(disziplin);
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        istBesucht ? Colors.grey : Colors.red,
                  ),
                  child: Text(
                    istBesucht
                        ? '$disziplin (besucht)'
                        : disziplin,
                    style: TextStyle(
                      color: istBesucht ? Colors.black45 : Colors.white,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            if (besuchteDisziplinen.length == angeboteneDisziplinen.length)
              ElevatedButton(
                onPressed: () {
                  _clearState();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DankeEnde(),
                    ),
                  );
                },
                child: const Text('Ende Sporttag'),
              )
              else if (!pauseGemacht &&
                wettbewerbsTyp == 'Zehnkampf' &&
                besuchteDisziplinen.length >= 4)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    pauseGemacht = true;
                  });
                  _saveState();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Pause(),
                    ),
                  );
                },
                child: const Text('Pause'),
              ),             
          ],
        ),
      ),
    );
  }
}