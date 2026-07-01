import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'klassen/riegen_klasse.dart';
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
import 'tools/riegen_repository.dart';

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
  final RiegenRepository riegenRepository = RiegenRepository();
  List<Kind> riegenKinder = [];

  final log = getLogger();

  final bool isDevelopment = true;
  late Map<String, Widget Function()> disziplinPages;
  final Set<String> besuchteDisziplinen = {};
  bool pauseGemacht = false;

  // State-Variable in der Methode _ladeRiege() gesetzt abhängig von der
  // beim Aufruf übergebenen riegneNummer. Wird an die Disziplinen-Widgets übergeben,
  //amit diese auf die Riege zugreifen können.
  Riege? riegenPointer;
  String get wettbewerbsTyp => widget.wettbewerbsTyp;

  @override
  void initState() {
    super.initState();
    _ladeRiege();

    disziplinPages = {
      'Schlagwurf': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Schlagwurf(riegenPointer: riegenPointer!),
      'Drehwurf': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Drehwurf(riegenPointer: riegenPointer!),
      'Druckwurf': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Druckwurf(riegenPointer: riegenPointer!),
      'Sprint': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Sprint(riegenPointer: riegenPointer!),
      '30m Banankartons': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Bananenkartons(riegenPointer: riegenPointer!),
      '30 sec Lauf': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Lauf(riegenPointer: riegenPointer!),
      'Stabfliegen': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Stabfliegen(riegenPointer: riegenPointer!),
      'Hoch-Weitsprung': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : HochWeitSprung(riegenPointer: riegenPointer!),
      'Zonenweitsprung': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Zonenweitsprung(riegenPointer: riegenPointer!),
      'Stadionrunde': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Stadionrunde(riegenPointer: riegenPointer!),
    };

    _loadState();
  }

  Future<void> _ladeRiege() async {
    // Lade die Riege aus dem Repository basierend auf der Riegennummer
    final geladen = await riegenRepository.ladeRiegeNachNummer(
      riegenNummer: widget.riegenNummer,
    );
    setState(() {
      riegenPointer = geladen;
    });
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
    const String dieLetzeStation =
        'Stadionrunde'; // für Zehnkampf immer Stadionrunde
//        angeboteneDisziplinen.keys.last; // hier: Stadionrunde
    final List<String> disziplinNamen = angeboteneDisziplinen.keys.toList();

    return Scaffold(
      appBar: MeineAppBar(
        titel: 'Riege ${riegenPointer?.riegenNummer} Sporttag-Wettbewerbe',
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: disziplinNamen.map((disziplin) {
                      final istBesucht =
                          besuchteDisziplinen.contains(disziplin);
                      final istLetzteStation = disziplin == dieLetzeStation;
                      final alleAnderenBesucht = besuchteDisziplinen.length ==
                          angeboteneDisziplinen.length - 1;
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
                                          angeboteneDisziplinen[disziplin]
                                              ?.call() ??
                                          const Center(
                                              child: Text(
                                                  'Disziplin nicht gefunden')),
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
                            istBesucht ? '$disziplin (besucht)' : disziplin,
                            style: TextStyle(
                              color: istBesucht ? Colors.black45 : Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
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
      ),
    );
  }
}
