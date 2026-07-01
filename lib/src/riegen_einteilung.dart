import 'package:flutter/material.dart';

import 'hilfs_widgets/meine_appbar.dart';
import 'tools/logger.util.dart';
import 'klassen/kind_klasse.dart';
import 'klassen/riegen_klasse.dart';
import 'tools/kind_repository.dart';
import 'tools/riegen_repository.dart';

class RiegenEinteilung extends StatefulWidget {
  const RiegenEinteilung({super.key, required this.titel});
  final String? titel;

  @override
  RiegenEinteilungState createState() => RiegenEinteilungState();
}

class RiegenEinteilungState extends State<RiegenEinteilung> {
  final KindRepository   kindRepository   = KindRepository();
  final RiegenRepository riegenRepository = RiegenRepository();

  List<Kind>         alleKinder   = [];
  List<Riege>        alleRiegen   = [];
  List<List<Kind>>   riegenListen = [];  // Index 0 = Riege 1, etc.
  List<Kind>         gefilterteKinder = [];
  int?               ausgewaehlteRiegenNummer;
  bool               isLoading = true;
  String?            fehlerMeldung;

  final int  riegenAnzahl   = 8;
  final int  aktuellesJahr  = DateTime.now().year;
  final _log = getLogger();

  @override
  void initState() {
    super.initState();
    riegenListen = List.generate(riegenAnzahl, (_) => []);
    _riegenEinteilenUndSpeichern();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 1: Daten laden
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _riegenEinteilenUndSpeichern() async {
    setState(() { isLoading = true; fehlerMeldung = null; });

    try {
      // Angemeldete Kinder laden
      alleKinder  = await kindRepository.ladeAngemeldeteKinder();
      // Riegen-Objekte laden (die objectIDs werden für Pointer benötigt)
      alleRiegen  = await riegenRepository.ladeAlleRiegen();

      if (alleRiegen.length < riegenAnzahl) {
        throw Exception(
          'Zu wenige Riegen in der Datenbank (${alleRiegen.length}/$riegenAnzahl). '
          'Bitte zuerst die 8 Riegen-Datensätze anlegen.',
        );
      }

      // SCHRITT 2: Verteilung lokal berechnen (kein DB-Zugriff)
      _berechneRiegenEinteilung();

      // SCHRITT 3: Ergebnisse in DB speichern (mit Fehlerbehandlung)
      await _speichereEinteilungInDatenbank();

    } catch (e) {
      _log.e('Riegeneinteilung fehlgeschlagen: $e');
      setState(() { fehlerMeldung = e.toString(); });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 2: Einteilung lokal berechnen (reine Logik, kein DB-Zugriff)
  // ─────────────────────────────────────────────────────────────────────────
  void _berechneRiegenEinteilung() {
    // Kinder nach Jahrgang + Geschlecht gruppieren
    final Map<String, List<Kind>> gruppenMap = {};
    for (final kind in alleKinder) {
      final key = '${kind.jahrgang}_${kind.geschlecht}';
      (gruppenMap[key] ??= []).add(kind);
    }

    // Gruppen absteigend nach Schlüssel sortieren
    final sortiertGruppen = (gruppenMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)));

    // In Fünf- und Zehnkampf aufteilen
    final fuenfkampfGruppen = <MapEntry<String, List<Kind>>>[];
    final zehnkampfGruppen  = <MapEntry<String, List<Kind>>>[];
    int anzFuenfkampfKinder = 0;

    for (final entry in sortiertGruppen) {
      final jahrgang = int.parse(entry.key.split('_')[0]);
      final alter    = aktuellesJahr - jahrgang;

      if (alter >= 3 && alter <= 5) {
        fuenfkampfGruppen.add(entry);
        anzFuenfkampfKinder += entry.value.length;
      } else if (alter >= 6) {
        zehnkampfGruppen.add(entry);
      }
    }

    // Riegenanzahl für Fünfkampf berechnen
    final anteil             = anzFuenfkampfKinder / alleKinder.length;
    final anzRiegenFuenfkampf = (riegenAnzahl * anteil).round();

    // Riegen-Typ im lokalen Riegen-Objekt setzen
    for (int i = 0; i < riegenAnzahl; i++) {
      alleRiegen[i].fuenfKampf = (i < anzRiegenFuenfkampf);
    }

    // Kinder auf Riegen verteilen
    riegenListen = List.generate(riegenAnzahl, (_) => []);
    _verteileGruppenAufRiegen(fuenfkampfGruppen, riegenListen.sublist(0, anzRiegenFuenfkampf));
    _verteileGruppenAufRiegen(zehnkampfGruppen,  riegenListen.sublist(anzRiegenFuenfkampf));

    // Riegennummer an Kind-Objekte weitergeben (transienter Wert)
    for (int i = 0; i < riegenListen.length; i++) {
      for (final kind in riegenListen[i]) {
        kind.riegenNummer = alleRiegen[i].riegenNummer;
      }
    }
  }

  void _verteileGruppenAufRiegen(
    List<MapEntry<String, List<Kind>>> gruppen,
    List<List<Kind>> zielRiegen,
  ) {
    if (zielRiegen.isEmpty) return;
    // Größte Gruppe zuerst (Greedy-Algorithmus)
    gruppen.sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final entry in gruppen) {
      // Riege mit wenigsten Kindern wählen
      final riege = zielRiegen.reduce(
        (r1, r2) => r1.length <= r2.length ? r1 : r2,
      );
      riege.addAll(entry.value);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 3: Datenbank schreiben
  //
  // ACID – Atomicity:
  //   Erst werden alle Riegen-Typen gesetzt (Phase A), dann erst die
  //   Kinderzuordnungen (Phase B). Beide Phasen werden mit await abgewartet.
  //   Fehler in Phase A verhindern, dass Phase B gestartet wird.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _speichereEinteilungInDatenbank() async {
    // Phase A: Riegen-Art setzen
    _log.i('Phase A: Riegen-Arten speichern…');
    int fehlerPhaseA = 0;
    for (int i = 0; i < riegenAnzahl; i++) {
      final ok = await riegenRepository.setzeRiegenArt(
        riegenObjectId: alleRiegen[i].objectId,
        fuenfKampf:     alleRiegen[i].fuenfKampf,
      );
      if (!ok) fehlerPhaseA++;
    }

    if (fehlerPhaseA > 0) {
      throw Exception(
        'Phase A: $fehlerPhaseA Riegen konnten nicht gesetzt werden. '
        'Bitte Verbindung prüfen und erneut versuchen.',
      );
    }

    // Phase B: Kinderzuordnungen schreiben
    _log.i('Phase B: Kinderzuordnungen speichern…');
    int fehlerPhaseB = 0;
    for (int riegenIdx = 0; riegenIdx < riegenListen.length; riegenIdx++) {
      final riege  = alleRiegen[riegenIdx];
      final kinder = riegenListen[riegenIdx];

      for (int pos = 0; pos < kinder.length; pos++) {
        final ok = await kindRepository.weiseKindRiegeZu(
          kind:     kinder[pos],
          riege:    riege,
          position: pos + 1,
        );
        if (!ok) fehlerPhaseB++;
      }
    }

    if (fehlerPhaseB > 0) {
      // UI-Warnung, aber kein harter Fehler – Phase A war erfolgreich
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fehlerPhaseB Kinderzuordnungen fehlgeschlagen. Bitte nochmals speichern.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } else {
      _log.i('Riegeneinteilung vollständig gespeichert.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────
  void _filterKinderNachRiege(int riegenNummer) {
    setState(() {
      gefilterteKinder = alleKinder
          .where((k) => k.riegenNummer == riegenNummer)
          .toList()
        ..sort((a, b) {
          final jv = b.jahrgang.compareTo(a.jahrgang);
          return jv != 0 ? jv : b.geschlecht.compareTo(a.geschlecht);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(
        titel: widget.titel ?? 'Riegen Einteilung',
        thema: 'Riegen Einteilung',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : fehlerMeldung != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(fehlerMeldung!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _riegenEinteilenUndSpeichern,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButton<int>(
                        hint: const Text('Wähle eine Riege'),
                        value: ausgewaehlteRiegenNummer,
                        items: List.generate(riegenAnzahl, (i) => i + 1)
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                    'Riege $n  (${alleRiegen.length > n - 1 && alleRiegen[n - 1].fuenfKampf ? "Fünfkampf" : "Zehnkampf"})',
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => ausgewaehlteRiegenNummer = v);
                          if (v != null) _filterKinderNachRiege(v);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: gefilterteKinder.length,
                        itemBuilder: (_, i) {
                          final kind = gefilterteKinder[i];
                          return ListTile(
                            title: Text('${kind.vorname} ${kind.nachname} '
                                '${kind.jahrgang} ${kind.geschlecht}'),
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Riegeneinteilung abschließen',
                        style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
    );
  }
}
