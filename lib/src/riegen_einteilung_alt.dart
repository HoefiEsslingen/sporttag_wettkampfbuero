import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';

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
  late SporttagConfig config;

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
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();

    riegenListen = List.generate(riegenAnzahl, (_) => []);
    _riegenEinteilenUndSpeichern();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 1: Daten laden
  //
  // Optimierung (analog zu "Anmeldung Sporttag beschleunigt"):
  //   Unabhängige Lesezugriffe laufen parallel statt sequenziell, und der
  //   bisherige Datenstand wird mitgeladen, damit in SCHRITT 3 nur wirklich
  //   geänderte Datensätze geschrieben werden (Dirty-Tracking).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _riegenEinteilenUndSpeichern() async {
    setState(() { isLoading = true; fehlerMeldung = null; });

    try {
      // Angemeldete Kinder und Riegen-Objekte sind voneinander unabhängig
      // → parallel laden statt nacheinander zu warten.
      final kinderFuture = kindRepository.ladeAngemeldeteKinder();
      final riegenFuture = riegenRepository.ladeAlleRiegen();
      alleKinder  = await kinderFuture;
      alleRiegen  = await riegenFuture;

      if (alleRiegen.length < riegenAnzahl) {
        throw Exception(
          'Zu wenige Riegen in der Datenbank (${alleRiegen.length}/$riegenAnzahl). '
          'Bitte zuerst die 8 Riegen-Datensätze anlegen.',
        );
      }

      // Bisherigen Stand merken, um in SCHRITT 3 nur Änderungen zu schreiben.
      // ladeKinderAusRiegen() fragt alle Riegen bereits parallel ab.
      final bisherigeKinder = await kindRepository.ladeKinderAusRiegen(
        listeVonRiegen: alleRiegen,
      );
      final bisherigeZuordnung = {
        for (final k in bisherigeKinder) k.objectId: k.riegenNummer,
      };
      final bisherigerTyp = [for (final r in alleRiegen) r.fuenfKampf];

      // SCHRITT 2: Verteilung lokal berechnen (kein DB-Zugriff)
      //   Kinder, die bereits einer Riege zugeordnet sind, bleiben dort.
      //   Nur neue (noch nicht zugeordnete) Kinder werden nach den
      //   gültigen Kriterien in die bestehenden Riegen einsortiert.
      _berechneRiegenEinteilung(bisherigeZuordnung);

      // SCHRITT 3: nur geänderte Ergebnisse in DB speichern (mit Fehlerbehandlung)
      await _speichereEinteilungInDatenbank(
        bisherigerTyp: bisherigerTyp,
        bisherigeZuordnung: bisherigeZuordnung,
      );

    } catch (e) {
      _log.e('Riegeneinteilung fehlgeschlagen: $e');
      setState(() { fehlerMeldung = e.toString(); });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 2: Einteilung lokal berechnen (reine Logik, kein DB-Zugriff)
  //
  // Verhalten:
  //   Kinder, die laut bisherigeZuordnung bereits einer Riege angehören,
  //   bleiben in dieser Riege – die Riegen-Einteilung wird bei Nachmeldungen
  //   also nicht mehr komplett neu gewürfelt. Nur Kinder ohne bisherige
  //   Zuordnung ("neue Kinder") werden nach den gültigen Kriterien
  //   (Alter → Fünf-/Zehnkampf, danach kleinste Riege zuerst) auf die
  //   bestehenden Riegen verteilt.
  //
  //   Sind noch gar keine Kinder zugeordnet (bisherigeZuordnung leer,
  //   z. B. beim allerersten Aufruf), werden die Riegen-Typen wie bisher
  //   frisch aus dem Anteil an Fünfkampf-Kindern berechnet.
  // ─────────────────────────────────────────────────────────────────────────
  void _berechneRiegenEinteilung(Map<String, int> bisherigeZuordnung) {
    // Riege-Index anhand der Riegennummer nachschlagen (unabhängig von der
    // Sortierreihenfolge von alleRiegen).
    final indexNachRiegenNummer = {
      for (int i = 0; i < alleRiegen.length; i++) alleRiegen[i].riegenNummer: i,
    };

    riegenListen = List.generate(riegenAnzahl, (_) => []);

    // Kinder aufteilen: bereits zugeordnete (bleiben in ihrer Riege) vs. neue
    final bereitsZugeordnete = <Kind>[];
    final neueKinder = <Kind>[];
    for (final kind in alleKinder) {
      final vorherigeNummer = bisherigeZuordnung[kind.objectId];
      if (vorherigeNummer != null && indexNachRiegenNummer.containsKey(vorherigeNummer)) {
        bereitsZugeordnete.add(kind);
      } else {
        neueKinder.add(kind);
      }
    }

    if (bereitsZugeordnete.isEmpty) {
      // Noch keine Riegen-Einteilung vorhanden → Riegen-Typen frisch berechnen.
      _berechneUndSetzeRiegenTypen();
    }
    // Sonst: bestehende Riegen-Typen (alleRiegen[i].fuenfKampf) bleiben
    // unangetastet – die Riegen bestehen bleiben.

    // Für jedes bereits zugeordnete Kind zunächst die Riege ermitteln, die
    // laut DB aktuell für dieses Kind gilt.
    final riegeIdxProKind = <String, int>{
      for (final kind in bereitsZugeordnete)
        kind.objectId: indexNachRiegenNummer[bisherigeZuordnung[kind.objectId]]!,
    };

    // Selbstheilung: Ist eine Kohorte (Jahrgang + Geschlecht) unter den
    // bereits zugeordneten Kindern auf mehrere Riegen verteilt – etwa weil
    // die Zuordnung aus einem früheren Lauf vor dieser Kohorten-Regel stammt
    // oder manuell in riegen_zuordnung.dart verschoben wurde –, wird das
    // hier korrigiert: die Minderheit zieht zur Riege der Mehrheit um.
    final kohortenGruppen = <String, List<Kind>>{};
    for (final kind in bereitsZugeordnete) {
      kohortenGruppen.putIfAbsent('${kind.jahrgang}_${kind.geschlecht}', () => []).add(kind);
    }

    int korrigierteKinder = 0;
    for (final kohorte in kohortenGruppen.values) {
      final kinderProRiege = <int, List<Kind>>{};
      for (final kind in kohorte) {
        kinderProRiege.putIfAbsent(riegeIdxProKind[kind.objectId]!, () => []).add(kind);
      }
      if (kinderProRiege.length <= 1) continue; // Kohorte bereits konsistent

      final mehrheitsRiege = kinderProRiege.entries
          .reduce((a, b) => a.value.length >= b.value.length ? a : b)
          .key;

      for (final entry in kinderProRiege.entries) {
        if (entry.key == mehrheitsRiege) continue;
        for (final kind in entry.value) {
          riegeIdxProKind[kind.objectId] = mehrheitsRiege;
          korrigierteKinder++;
        }
      }
    }

    if (korrigierteKinder > 0) {
      _log.w(
        '$korrigierteKinder Kind(er) wegen kohorten-inkonsistenter '
        'Alt-Zuordnung in die Riege ihrer Jahrgang-Geschlecht-Kohorte verschoben.',
      );
    }

    // Bereits zugeordnete (ggf. korrigierte) Kinder einsortieren
    for (final kind in bereitsZugeordnete) {
      riegenListen[riegeIdxProKind[kind.objectId]!].add(kind);
    }

    // Kohorten (Jahrgang + Geschlecht), die bereits einer Riege angehören,
    // ermitteln. Kinder derselben Kohorte gehören immer in dieselbe Riege
    // ("gleicher Jahrgang + gleiches Geschlecht bleibt zusammen") – auch
    // wenn sie erst später (z. B. als Geschwister) nachgemeldet werden.
    final riegenIndexNachKohorte = <String, int>{};
    for (int i = 0; i < riegenListen.length; i++) {
      for (final kind in riegenListen[i]) {
        riegenIndexNachKohorte['${kind.jahrgang}_${kind.geschlecht}'] = i;
      }
    }

    // Neue Kinder aufteilen: solche mit bereits bekannter Kohorte werden
    // direkt dorthin gelegt, nur wirklich neue Kohorten durchlaufen den
    // Verteil-Algorithmus.
    final neueKinderBekannteKohorte = <Kind>[];
    final neueKinderNeueKohorte     = <Kind>[];
    for (final kind in neueKinder) {
      final kohorte  = '${kind.jahrgang}_${kind.geschlecht}';
      final riegeIdx = riegenIndexNachKohorte[kohorte];
      if (riegeIdx != null) {
        riegenListen[riegeIdx].add(kind);
        neueKinderBekannteKohorte.add(kind);
      } else {
        neueKinderNeueKohorte.add(kind);
      }
    }

    _log.i(
      '${bereitsZugeordnete.length} Kind(er) behalten ihre Riege, '
      '${neueKinderBekannteKohorte.length} neue(s) Kind(er) folgen ihrer '
      'bereits eingeteilten Kohorte, ${neueKinderNeueKohorte.length} '
      'Kind(er) aus neuen Kohorten werden frisch zugeteilt.',
    );

    // Nur wirklich neue Kohorten nach den gültigen Kriterien den bestehenden
    // Riegen zuteilen (Kohorten mit bereits eingeteilten Mitgliedern wurden
    // oben schon direkt zugeordnet und bleiben somit ungetrennt).
    _verteileNeueKinderAufBestehendeRiegen(neueKinderNeueKohorte);

    // Riegennummer an alle Kind-Objekte weitergeben (transienter Wert für UI-Filter)
    for (int i = 0; i < riegenListen.length; i++) {
      for (final kind in riegenListen[i]) {
        kind.riegenNummer = alleRiegen[i].riegenNummer;
      }
    }
  }

  /// Berechnet den Anteil Fünfkampf- vs. Zehnkampf-Kinder anhand des Alters
  /// und setzt den Riegen-Typ entsprechend. Wird nur bei der allerersten
  /// Einteilung aufgerufen (noch keine Riege enthält Kinder).
  void _berechneUndSetzeRiegenTypen() {
    final Map<String, List<Kind>> gruppenMap = {};
    for (final kind in alleKinder) {
      final key = '${kind.jahrgang}_${kind.geschlecht}';
      (gruppenMap[key] ??= []).add(kind);
    }

    int anzFuenfkampfKinder = 0;
    for (final entry in gruppenMap.entries) {
      final jahrgang = int.parse(entry.key.split('_')[0]);
      final alter    = aktuellesJahr - jahrgang;
      if (alter <= config.fuenfkampfMaxAlter) {
        anzFuenfkampfKinder += entry.value.length;
      }
    }

    final anteil = alleKinder.isEmpty ? 0.0 : anzFuenfkampfKinder / alleKinder.length;
    final anzRiegenFuenfkampf = (riegenAnzahl * anteil).round();

    for (int i = 0; i < riegenAnzahl; i++) {
      alleRiegen[i].fuenfKampf = (i < anzRiegenFuenfkampf);
    }
  }

  /// Verteilt nur die übergebenen (neuen) Kinder auf die bestehenden Riegen –
  /// gruppiert nach Jahrgang + Geschlecht, größte Gruppe zuerst, jeweils in
  /// die zum Kriterium passende Riege mit den aktuell wenigsten Kindern.
  void _verteileNeueKinderAufBestehendeRiegen(List<Kind> neueKinder) {
    if (neueKinder.isEmpty) return;

    // Kinder nach Jahrgang + Geschlecht gruppieren
    final Map<String, List<Kind>> gruppenMap = {};
    for (final kind in neueKinder) {
      final key = '${kind.jahrgang}_${kind.geschlecht}';
      (gruppenMap[key] ??= []).add(kind);
    }

    // Gruppen absteigend nach Schlüssel sortieren
    final sortiertGruppen = (gruppenMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)));

    // In Fünf- und Zehnkampf aufteilen (Kinder < 3 Jahre bleiben wie bisher
    // unberücksichtigt)
    final fuenfkampfGruppen = <MapEntry<String, List<Kind>>>[];
    final zehnkampfGruppen  = <MapEntry<String, List<Kind>>>[];

    for (final entry in sortiertGruppen) {
      final jahrgang = int.parse(entry.key.split('_')[0]);
      final alter    = aktuellesJahr - jahrgang;

      if (alter <= config.fuenfkampfMaxAlter) {
        fuenfkampfGruppen.add(entry);
      } else if (alter > config.fuenfkampfMaxAlter) {
        zehnkampfGruppen.add(entry);
      }
    }

    // Nur die bestehenden Riegen des jeweiligen Typs als Ziel zulassen –
    // die Riegen-Typen selbst werden hier nicht verändert.
    final fuenfkampfRiegen = [
      for (int i = 0; i < riegenAnzahl; i++)
        if (alleRiegen[i].fuenfKampf) riegenListen[i],
    ];
    final zehnkampfRiegen = [
      for (int i = 0; i < riegenAnzahl; i++)
        if (!alleRiegen[i].fuenfKampf) riegenListen[i],
    ];

    if (fuenfkampfGruppen.isNotEmpty && fuenfkampfRiegen.isEmpty) {
      _log.w('Neue Fünfkampf-Kinder vorhanden, aber keine Fünfkampf-Riege existiert.');
    }
    if (zehnkampfGruppen.isNotEmpty && zehnkampfRiegen.isEmpty) {
      _log.w('Neue Zehnkampf-Kinder vorhanden, aber keine Zehnkampf-Riege existiert.');
    }

    _verteileGruppenAufRiegen(fuenfkampfGruppen, fuenfkampfRiegen);
    _verteileGruppenAufRiegen(zehnkampfGruppen,  zehnkampfRiegen);
  }

  // Riegen gelten als "gleich klein" (und damit für den Alters-Tie-Break
  // gleichwertig), solange sie höchstens so viele Kinder mehr haben wie
  // hier angegeben. 0 = Alter spielt nie eine Rolle, reines Greedy nach Größe.
  static const int _riegenGroessenToleranz = 1;

  void _verteileGruppenAufRiegen(
    List<MapEntry<String, List<Kind>>> gruppen,
    List<List<Kind>> zielRiegen,
  ) {
    if (zielRiegen.isEmpty) return;
    // Größte Gruppe zuerst (beste Balance, Greedy-Algorithmus)
    gruppen.sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in gruppen) {
      final gruppenAlter = aktuellesJahr - int.parse(entry.key.split('_')[0]);

      // Gleichgroße Riegen haben Vorrang: erst die kleinstmögliche(n) Riege(n)
      // ermitteln, …
      final minAnzahl = zielRiegen
          .map((r) => r.length)
          .reduce((a, b) => a < b ? a : b);
      final kandidaten = zielRiegen
          .where((r) => r.length <= minAnzahl + _riegenGroessenToleranz)
          .toList();

      // … und nur bei mehreren (fast) gleich kleinen Riegen zusätzlich nach
      // Altersnähe entscheiden, damit ähnliche Jahrgänge zusammenrutschen,
      // ohne die Größenbalance zu verschlechtern.
      final riege = kandidaten.length == 1
          ? kandidaten.first
          : kandidaten.reduce((r1, r2) =>
              _altersAbstandZurGruppe(r1, gruppenAlter) <=
                      _altersAbstandZurGruppe(r2, gruppenAlter)
                  ? r1
                  : r2);

      riege.addAll(entry.value);
    }
  }

  /// Altersabstand einer Riege zum Alter einer neuen Gruppe. Eine noch leere
  /// Riege hat kein eigenes Durchschnittsalter und wird neutral behandelt
  /// (Abstand 0 – kein Malus gegenüber altersmäßig passenden Riegen).
  double _altersAbstandZurGruppe(List<Kind> riege, int gruppenAlter) {
    if (riege.isEmpty) return 0;
    final durchschnittsAlter = riege
            .map((k) => aktuellesJahr - k.jahrgang)
            .reduce((a, b) => a + b) /
        riege.length;
    return (durchschnittsAlter - gruppenAlter).abs();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 3: Datenbank schreiben
  //
  // ACID – Atomicity:
  //   Erst werden alle Riegen-Typen gesetzt (Phase A), dann erst die
  //   Kinderzuordnungen (Phase B). Beide Phasen werden mit await abgewartet.
  //   Fehler in Phase A verhindern, dass Phase B gestartet wird.
  //
  // Optimierung (analog zu "Anmeldung Sporttag beschleunigt"):
  //   1. Nur Datensätze schreiben, die sich gegenüber dem bisherigen Stand
  //      tatsächlich geändert haben (Dirty-Tracking statt Blind-Speichern).
  //   2. Die verbleibenden, voneinander unabhängigen Schreibzugriffe
  //      innerhalb einer Phase laufen parallel via Future.wait statt
  //      sequenziell in einer await-Schleife (wie in
  //      KindRepository.ladeKinderAusRiegen bereits etabliert).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _speichereEinteilungInDatenbank({
    required List<bool> bisherigerTyp,
    required Map<String, int> bisherigeZuordnung,
  }) async {
    // Phase A: nur geänderte Riegen-Arten setzen
    final geaenderteRiegen = [
      for (int i = 0; i < riegenAnzahl; i++)
        if (alleRiegen[i].fuenfKampf != bisherigerTyp[i]) i,
    ];

    if (geaenderteRiegen.isEmpty) {
      _log.i('Phase A: keine Änderungen an den Riegen-Arten.');
    } else {
      _log.i('Phase A: ${geaenderteRiegen.length} Riegen-Art(en) geändert, werden gespeichert…');
      final ergebnisseA = await Future.wait(
        geaenderteRiegen.map((i) => riegenRepository.setzeRiegenArt(
              riegenObjectId: alleRiegen[i].objectId,
              fuenfKampf:     alleRiegen[i].fuenfKampf,
            )),
      );
      final fehlerPhaseA = ergebnisseA.where((ok) => !ok).length;

      if (fehlerPhaseA > 0) {
        throw Exception(
          'Phase A: $fehlerPhaseA Riegen konnten nicht gesetzt werden. '
          'Bitte Verbindung prüfen und erneut versuchen.',
        );
      }
    }

    // Phase B: nur geänderte Kinderzuordnungen schreiben
    final zuSpeichernde = <(Kind, Riege, int)>[];
    for (int riegenIdx = 0; riegenIdx < riegenListen.length; riegenIdx++) {
      final riege  = alleRiegen[riegenIdx];
      final kinder = riegenListen[riegenIdx];

      for (int pos = 0; pos < kinder.length; pos++) {
        final kind = kinder[pos];
        if (bisherigeZuordnung[kind.objectId] != riege.riegenNummer) {
          zuSpeichernde.add((kind, riege, pos + 1));
        }
      }
    }

    if (zuSpeichernde.isEmpty) {
      _log.i('Phase B: keine Änderungen an den Kinderzuordnungen.');
      _log.i('Riegeneinteilung vollständig gespeichert (keine Schreibzugriffe nötig).');
      return;
    }

    _log.i('Phase B: ${zuSpeichernde.length} Kinderzuordnung(en) geändert, werden gespeichert…');
    final ergebnisseB = await Future.wait(
      zuSpeichernde.map((z) => kindRepository.aktualisiereRiegenZuordnung(
            kind:         z.$1,
            neueRiege:    z.$2,
            neuePosition: z.$3,
          )),
    );
    final fehlerPhaseB = ergebnisseB.where((ok) => !ok).length;

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
