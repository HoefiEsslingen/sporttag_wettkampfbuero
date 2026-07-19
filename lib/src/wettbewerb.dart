import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/tools/pdf_modal.dart';
import 'package:sporttag/src/tools/station_repository.dart';
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

  const Wettbewerb({super.key, required this.riegenNummer});

  @override
  WettbewerbState createState() => WettbewerbState();
}

class WettbewerbState extends State<Wettbewerb> {
  final KindRepository kindRepository = KindRepository();
  final RiegenRepository riegenRepository = RiegenRepository();
  final StationRepository stationRepository = StationRepository();
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
  // Aus der DB geladene Stationen, passend zum Wettkampftyp der Riege
  // (bereits nach stationsNummer sortiert, siehe StationRepository).
  List<Station>? erlaubteStationen;

  // Wettbewerbstyp wird aus der Riege (Feld fuenfKampf) abgeleitet.
  String get wettbewerbsTyp =>
      (riegenPointer?.fuenfKampf ?? false) ? 'Fuenfkampf' : 'Zehnkampf';

  @override
  void initState() {
    super.initState();
    _ladeRiegeUndStationen();

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
      'Huerdenlauf': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Huerdenlauf(riegenPointer: riegenPointer!),
      '30sec-Lauf': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Lauf(riegenPointer: riegenPointer!),
      'Stabfliegen': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Stabfliegen(riegenPointer: riegenPointer!),
      'Hochsprung': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : HochWeitSprung(riegenPointer: riegenPointer!),
      'Weitsprung': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Zonenweitsprung(riegenPointer: riegenPointer!),
      'Stadionrunde': () => (riegenPointer == null)
          ? const Center(child: CircularProgressIndicator())
          : Stadionrunde(riegenPointer: riegenPointer!),
    };

    _loadState();
  }

  Future<void> _ladeRiegeUndStationen() async {
    // Lade die Riege aus dem Repository basierend auf der Riegennummer
    final geladeneRiege = await riegenRepository.ladeRiegeNachNummer(
      riegenNummer: widget.riegenNummer,
    );
    if (!mounted) return; // Widget bereits disposed → abbrechen
    setState(() {
      riegenPointer = geladeneRiege;
    });

    if (geladeneRiege == null) {
      log.w('Riege ${widget.riegenNummer} nicht gefunden.');
      return;
    }

    final stationen = await stationRepository.ladeStationenFuerWettkampf(
      istZehnkampf: !geladeneRiege.fuenfKampf,
    );

    // Kinder der Riege + deren Punktesummen laden
    await _ladeKinderMitPunkten(geladeneRiege);

    if (!mounted) return;

    setState(() {
      erlaubteStationen = stationen;
    });
  }

  /// Zeigt die Stationsbeschreibung (PDF) zur gewählten Disziplin an und
  /// lässt den Benutzer die Wahl bestätigen oder abbrechen.
  /// Gibt true zurück, wenn bestätigt wurde, sonst false/null.
  Future<bool?> _bestaetigeDisziplinAuswahl(
    BuildContext context,
    String disziplin,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Verhindert versehentliches Schließen ohne bewusste Wahl
      isDismissible: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Text(
                    'Ist "$disziplin" die richtige Station?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Bestehende PDF-Ansicht der Stationsbeschreibung
                Expanded(
                  child: PdfModal(stationsName: disziplin),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('Abbrechen'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('Bestätigen'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Lädt die Kinder der Riege, ergänzt die erreichten Punkte und
  /// sortiert die Liste nach Vorname für die Anzeige.
  Future<void> _ladeKinderMitPunkten(Riege riege) async {
    final kinder = await kindRepository.ladeKinderDerRiege(riege: riege);
    final punkteSummen =
        await kindRepository.ladePunkteSummenFuerKinder(kinder: kinder);

    for (final kind in kinder) {
      kind.erreichtePunkte = punkteSummen[kind.objectId] ?? 0;
    }

    kinder.sort(
      (a, b) => a.vorname.toLowerCase().compareTo(b.vorname.toLowerCase()),
    );

    if (!mounted) return;
    setState(() {
      riegenKinder = kinder;
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
    // Solange Riege oder Stationen noch nicht geladen sind: Ladeanzeige.
    if (riegenPointer == null || erlaubteStationen == null) {
      return Scaffold(
        appBar: MeineAppBar(titel: 'Sporttag-Wettbewerbe'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Reihenfolge & Auswahl richten sich nach den aus der DB geladenen,
    // bereits nach stationsNummer sortierten Stationen.
    final Map<String, Widget Function()> angeboteneDisziplinen = {
      for (final station in erlaubteStationen!)
        if (disziplinPages.containsKey(station.stationsName))
          station.stationsName: disziplinPages[station.stationsName]!
    };

    const String dieLetzeStation = 'Stadionrunde';
    final List<String> disziplinNamen = angeboteneDisziplinen.keys.toList();

    return Scaffold(
      appBar: MeineAppBar(
        titel: 'Riege ${riegenPointer?.riegenNummer} Sporttag-Wettbewerbe',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Linke Seite: Kinderliste ──────────────────────────
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riegenmitglieder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: riegenKinder.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : ListView.builder(
                            itemCount: riegenKinder.length,
                            itemBuilder: (context, index) {
                              final kind = riegenKinder[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: ListTile(
                                  title: Text(
                                    '${kind.vorname} ${kind.nachname}',
                                  ),
                                  trailing: Text(
                                    '${kind.erreichtePunkte} Pkt.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // ── Rechte Seite: Disziplin-Buttons ───────────────────
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: disziplinNamen.map((disziplin) {
                          final istBesucht =
                              besuchteDisziplinen.contains(disziplin);
                          final istLetzteStation = disziplin == dieLetzeStation;
                          final alleAnderenBesucht =
                              besuchteDisziplinen.length ==
                                  angeboteneDisziplinen.length - 1;
                          final istAktiv = !istBesucht &&
                              (!istLetzteStation || alleAnderenBesucht);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ElevatedButton(
                              onPressed: istAktiv
                                  ? () async {
                                      final bestaetigt =
                                          await _bestaetigeDisziplinAuswahl(
                                        context,
                                        disziplin,
                                      );
                                      if (bestaetigt != true) {
                                        return; // abgebrochen → nichts weiter tun
                                      }
                                      if (!context.mounted){
                                        return; // NEU: Guard gegen async-gap-Warnung
                                      }
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
                              // onPressed: istAktiv
                              // ? () async {
                              //     await Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (context) =>
                              //             angeboteneDisziplinen[
                              //                         disziplin]
                              //                     ?.call() ??
                              //                 const Center(
                              //                     child: Text(
                              //                         'Disziplin nicht gefunden')),
                              //       ),
                              //     );
                              //     setState(() {
                              //       besuchteDisziplinen.add(disziplin);
                              //     });
                              //   }
                              // : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    istBesucht ? Colors.grey : Colors.red,
                              ),
                              child: Text(
                                istBesucht ? '$disziplin (besucht)' : disziplin,
                                style: TextStyle(
                                  color: istBesucht
                                      ? Colors.black45
                                      : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (besuchteDisziplinen.length ==
                      angeboteneDisziplinen.length)
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
          ],
        ),
      ),
    );
  }
}
