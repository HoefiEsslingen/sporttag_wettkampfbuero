import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/tools/pdf_modal.dart';
import 'package:sporttag/src/repositories/station_repository.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/pause.dart';
import 'package:sporttag/src/danke_ende.dart';
import 'package:sporttag/src/disziplinen_widgets/hoch_weit_sprung.dart';
import 'package:sporttag/src/disziplinen_widgets/lauf.dart';
import 'package:sporttag/src/disziplinen_widgets/bananen_kartons.dart';
import 'package:sporttag/src/disziplinen_widgets/sprint.dart';
import 'package:sporttag/src/disziplinen_widgets/schlag_wurf.dart';
import 'package:sporttag/src/disziplinen_widgets/dreh_wurf.dart';
import 'package:sporttag/src/disziplinen_widgets/stab_fliegen.dart';
import 'package:sporttag/src/disziplinen_widgets/druck_wurf.dart';
import 'package:sporttag/src/disziplinen_widgets/weit_sprung.dart';
import 'package:sporttag/src/disziplinen_widgets/stadion_runde.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/repositories/kind_repository.dart';
import 'package:sporttag/src/tools/logger.util.dart';
import 'package:sporttag/src/hilfs_widgets/meine_appbar.dart';
import 'package:sporttag/src/repositories/riegen_repository.dart';

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
  Set<String> besuchteDisziplinen = {};
  bool isLoading = true;
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

  // NEU: Verhindert Doppelverarbeitung während eine Disziplin gerade gespeichert wird
  String? _disziplinInBearbeitung;

  @override
  void initState() {
    super.initState();
    // Lade die Riege und die erlaubten Stationen aus der DB
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
    await _ladeBesuchteDisziplinen(
        riege: geladeneRiege); // ← Riege übergeben statt neu laden

    if (!mounted) return;

    setState(() {
      erlaubteStationen = stationen;
    });
  }

  /// Lädt den aktuellen Stand aus der DB beim Start des Screens.
  Future<void> _ladeBesuchteDisziplinen({required Riege riege}) async {
    final absolvierte = await riegenRepository.ladeAbsolvierteStationen(
      riege: riege,
    );

    if (!mounted) return;
    setState(() {
      besuchteDisziplinen = absolvierte.toSet();
      isLoading = false;
    });
  }

  /// Wird nach jeder abgeschlossenen Disziplin aufgerufen.
  Future<void> _disziplinAbschliessen({
    required Riege riege,
    required Station station,
  }) async {
    final ok = await riegenRepository.erhoeheStationszaehler(
      riege: riege,
      station: station,
    );
    if (ok && mounted) {
      setState(() {
        besuchteDisziplinen.add(station.stationsName);
      });
    }
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
                    'Ist "$disziplin" die richtige Station?\n\nDie Wahl kann nicht rückgängig gemacht werden.',
                    style: const TextStyle(
                      fontSize: 20,
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

  @override
  Widget build(BuildContext context) {
    // Solange Riege oder Stationen noch nicht geladen sind: Ladeanzeige.
    if (riegenPointer == null || erlaubteStationen == null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: MeineAppBar(titel: 'Sporttag-Wettbewerbe'),
          body: const Center(child: CircularProgressIndicator()),
        ),
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

    return PopScope(
      // Verhindert versehentliches Schließen ohne bewusste Wahl
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Optional: Hinweis anzeigen, warum "Zurück" nicht funktioniert
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Zurück-Navigation ist auf dieser Seite deaktiviert.'),
          ),
        );
      },
      child: Scaffold(
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
                                return MeinKartenEintrag(
                                  child: ListTile(
                                    title: Text(
                                        '${kind.vorname} ${kind.nachname}'),
                                    trailing: Text(
                                      '${kind.erreichtePunkte} Pkt.',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
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
                            final istLetzteStation =
                                disziplin == dieLetzeStation;
                            final alleAnderenBesucht =
                                besuchteDisziplinen.length ==
                                    angeboteneDisziplinen.length - 1;
                            final istAktiv = !istBesucht; //&&
                            //(!istLetzteStation || alleAnderenBesucht);

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton(
                                onPressed: (istAktiv &&
                                        _disziplinInBearbeitung == null)
                                    ? () async {
                                        // Sofort sperren – noch bevor der Dialog überhaupt öffnet
                                        setState(() => _disziplinInBearbeitung =
                                            disziplin);

                                        try {
                                          final bestaetigt =
                                              await _bestaetigeDisziplinAuswahl(
                                                  context, disziplin);
                                          if (bestaetigt != true) return;
                                          if (!context.mounted) return;

                                          await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PopScope(
                                                  canPop: false,
                                                  child: angeboteneDisziplinen[
                                                              disziplin]
                                                          ?.call() ??
                                                      const Center(
                                                          child: Text(
                                                              'Disziplin nicht gefunden')),
                                                ),
                                              ));

                                          if (!mounted) {
                                            return; // Guard nach zweitem await
                                          }

                                          // Passendes Station-Objekt aus den geladenen Stationen holen
                                          final station =
                                              erlaubteStationen!.firstWhere(
                                            (s) => s.stationsName == disziplin,
                                          );

                                          // ECHTER DB-Write: Zähler + Array in riegenLogging aktualisieren
                                          await _disziplinAbschliessen(
                                              riege: riegenPointer!,
                                              station: station);
                                        } finally {
                                          // Entsperren, egal ob erfolgreich oder nicht
                                          if (mounted) {
                                            setState(() =>
                                                _disziplinInBearbeitung = null);
                                          }
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      istBesucht ? Colors.grey : Colors.red,
                                ),
                                child: Text(
                                  _disziplinInBearbeitung == disziplin
                                      ? 'Wird gespeichert…'
                                      : (istBesucht
                                          ? '$disziplin (besucht)'
                                          : disziplin),
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
//                          _clearState();
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
//                          _saveState();
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
      ),
    );
  }
}
