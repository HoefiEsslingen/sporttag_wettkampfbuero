import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';

import 'hilfs_widgets/meine_appbar.dart';
import 'tools/logger.util.dart';
import 'klassen/kind_klasse.dart';
import 'klassen/riegen_klasse.dart';
import 'repositories/kind_repository.dart';
import 'repositories/riegen_repository.dart';

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
  bool               isLoading = true;
  bool               isSaving  = false;
  String?            fehlerMeldung;

  // Für Phase A/B des Speicherns benötigt (siehe SCHRITT 3), wird beim
  // Berechnen des Vorschlags gemerkt und erst beim expliziten Speichern
  // durch den Benutzer verwendet.
  late List<bool>       _bisherigerTyp;
  late Map<String, int> _bisherigeZuordnung;

  final int  riegenAnzahl   = 8;
  final int  aktuellesJahr  = DateTime.now().year;
  final _log = getLogger();

  @override
  void initState() {
    super.initState();
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();
    
    riegenListen = List.generate(riegenAnzahl, (_) => []);
    _ladeUndBerechneVorschlag();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHRITT 1: Daten laden
  //
  // Optimierung (analog zu "Anmeldung Sporttag beschleunigt"):
  //   Unabhängige Lesezugriffe laufen parallel statt sequenziell, und der
  //   bisherige Datenstand wird mitgeladen, damit in SCHRITT 3 nur wirklich
  //   geänderte Datensätze geschrieben werden (Dirty-Tracking).
  //
  // Wichtig: Es wird hier nur noch ein Vorschlag berechnet und angezeigt.
  // Gespeichert wird erst, wenn der Benutzer die Riegenübersicht (ggf. nach
  // manuellen Anpassungen) explizit bestätigt (siehe _speichernUndAbschliessen).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _ladeUndBerechneVorschlag() async {
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

      // Bisherigen Stand merken, um beim Speichern nur Änderungen zu schreiben.
      // ladeKinderAusRiegen() fragt alle Riegen bereits parallel ab.
      final bisherigeKinder = await kindRepository.ladeKinderAusRiegen(
        listeVonRiegen: alleRiegen,
      );
      _bisherigeZuordnung = {
        for (final k in bisherigeKinder) k.objectId: k.riegenNummer,
      };
      _bisherigerTyp = [for (final r in alleRiegen) r.fuenfKampf];

      // SCHRITT 2: Verteilung lokal berechnen (kein DB-Zugriff)
      //   Kinder, die bereits einer Riege zugeordnet sind, bleiben dort.
      //   Nur neue (noch nicht zugeordnete) Kinder werden nach den
      //   gültigen Kriterien in die bestehenden Riegen einsortiert.
      //   Das Ergebnis ist zunächst nur ein Vorschlag – der Benutzer kann
      //   ihn in der Übersicht noch anpassen, bevor gespeichert wird.
      _berechneRiegenEinteilung(_bisherigeZuordnung);

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

  /// Verteilt nur die übergebenen (neuen) Kinder auf die bestehenden Riegen.
  ///
  /// Grundlage ist weiterhin der Greedy-Algorithmus (größte Kohorte zuerst,
  /// jeweils in die zum Kriterium passende Riege mit den aktuell wenigsten
  /// Kindern). Zusätzlich wird vorher geprüft, ob beide Geschlechter
  /// desselben Jahrgangs zusammen in eine Riege passen, ohne deren
  /// Zielgröße wesentlich (mehr als _jahrgangZusammenlegenToleranz Kinder)
  /// zu überschreiten. Ist das der Fall, werden beide Geschlechter als eine
  /// gemeinsame Gruppe behandelt – das vermeidet Altersunterschiede
  /// innerhalb einer Riege, ohne die Größenbalance zu gefährden. Passt es
  /// nicht, bleibt es bei der bisherigen Verteilung nach Kohortengröße.
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

    // Ziel-Riegengröße je Wettkampf-Typ: alle Kinder dieses Typs (bereits
    // zugeordnete + neue) geteilt durch die Anzahl der Riegen dieses Typs.
    // Dient als Referenz dafür, ob das Zusammenlegen beider Geschlechter
    // eines Jahrgangs die Riegengröße "wesentlich" sprengen würde.
    final zielGroesseFuenfkampf = _zielRiegenGroesse(
      passtZuTyp: (alter) => alter <= config.fuenfkampfMaxAlter,
      anzahlRiegenDiesesTyps: fuenfkampfRiegen.length,
    );
    final zielGroesseZehnkampf = _zielRiegenGroesse(
      passtZuTyp: (alter) => alter > config.fuenfkampfMaxAlter,
      anzahlRiegenDiesesTyps: zehnkampfRiegen.length,
    );

    final fuenfkampfGruppenZusammengefasst = _fasseJahrgaengeZusammenWennPassend(
      fuenfkampfGruppen,
      zielGroesseFuenfkampf,
    );
    final zehnkampfGruppenZusammengefasst = _fasseJahrgaengeZusammenWennPassend(
      zehnkampfGruppen,
      zielGroesseZehnkampf,
    );

    _verteileGruppenAufRiegen(fuenfkampfGruppenZusammengefasst, fuenfkampfRiegen);
    _verteileGruppenAufRiegen(zehnkampfGruppenZusammengefasst,  zehnkampfRiegen);
  }

  /// Zielgröße einer Riege dieses Wettkampf-Typs: alle Kinder, deren Alter
  /// laut [passtZuTyp] zu diesem Typ passt (unabhängig davon, ob sie schon
  /// zugeordnet sind oder gerade neu verteilt werden), geteilt durch die
  /// Anzahl der Riegen dieses Typs.
  double _zielRiegenGroesse({
    required bool Function(int alter) passtZuTyp,
    required int anzahlRiegenDiesesTyps,
  }) {
    if (anzahlRiegenDiesesTyps == 0) return 0;
    final anzahlKinder = alleKinder
        .where((k) => passtZuTyp(aktuellesJahr - k.jahrgang))
        .length;
    return anzahlKinder / anzahlRiegenDiesesTyps;
  }

  // Wie viele Kinder eine aus beiden Geschlechtern zusammengelegte
  // Jahrgangsgruppe die Ziel-Riegengröße überschreiten darf, damit die
  // Überschreitung noch als "unwesentlich" gilt.
  static const int _jahrgangZusammenlegenToleranz = 3;

  /// Fasst für jeden Jahrgang die Kohorten beider Geschlechter zu einer
  /// gemeinsamen Gruppe zusammen, sofern das die Ziel-Riegengröße nicht
  /// wesentlich überschreitet (siehe _jahrgangZusammenlegenToleranz). So
  /// bleiben Riegen altersmäßig möglichst homogen (Altersunterschied 0
  /// innerhalb des Jahrgangs), ohne die Größenbalance nennenswert zu
  /// verschlechtern. Passt die Kombination nicht, bleiben die Kohorten
  /// getrennt und werden wie bisher einzeln per Greedy verteilt.
  List<MapEntry<String, List<Kind>>> _fasseJahrgaengeZusammenWennPassend(
    List<MapEntry<String, List<Kind>>> gruppen,
    double zielGroesse,
  ) {
    // Gruppen (Schlüssel "jahrgang_geschlecht") nach Jahrgang bündeln
    final proJahrgang = <String, List<MapEntry<String, List<Kind>>>>{};
    for (final gruppe in gruppen) {
      final jahrgang = gruppe.key.split('_')[0];
      proJahrgang.putIfAbsent(jahrgang, () => []).add(gruppe);
    }

    final ergebnis = <MapEntry<String, List<Kind>>>[];
    for (final entry in proJahrgang.entries) {
      final geschlechterGruppen = entry.value;
      final kombinierteGroesse = geschlechterGruppen
          .fold<int>(0, (summe, g) => summe + g.value.length);

      final passtZusammen = geschlechterGruppen.length > 1 &&
          kombinierteGroesse <= zielGroesse + _jahrgangZusammenlegenToleranz;

      if (passtZusammen) {
        // Beide Geschlechter des Jahrgangs zusammen als eine Gruppe behandeln
        final alleKinderDesJahrgangs = [
          for (final g in geschlechterGruppen) ...g.value,
        ];
        ergebnis.add(MapEntry('${entry.key}_gemischt', alleKinderDesJahrgangs));
      } else {
        ergebnis.addAll(geschlechterGruppen);
      }
    }
    return ergebnis;
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
  // Manuelle Anpassung durch den Benutzer
  //
  // Wird die Riegennummer einer Kohorte (Jahrgang + Geschlecht) in der
  // Übersicht geändert, ziehen alle Kinder dieser Kohorte gemeinsam in die
  // neu eingegebene Riege um – die Kohorte bleibt also auch bei manueller
  // Anpassung ungetrennt.
  // ─────────────────────────────────────────────────────────────────────────
  void _kohorteVerschieben(String kohortenSchluessel, int neueRiegenNummer) {
    final zielIndex = neueRiegenNummer - 1;
    if (zielIndex < 0 || zielIndex >= riegenAnzahl) return;

    bool passtZumSchluessel(Kind k) => '${k.jahrgang}_${k.geschlecht}' == kohortenSchluessel;

    final betroffeneKinder = <Kind>[
      for (final liste in riegenListen) ...liste.where(passtZumSchluessel),
    ];
    if (betroffeneKinder.isEmpty) return;

    setState(() {
      for (final liste in riegenListen) {
        liste.removeWhere(passtZumSchluessel);
      }
      riegenListen[zielIndex].addAll(betroffeneKinder);
      for (final kind in betroffeneKinder) {
        kind.riegenNummer = alleRiegen[zielIndex].riegenNummer;
      }
    });

    _log.i('Kohorte $kohortenSchluessel manuell in Riege $neueRiegenNummer verschoben '
        '(${betroffeneKinder.length} Kind(er)).');

    // Weicher Hinweis, falls die Kohorte in eine Riege des jeweils anderen
    // Wettkampf-Typs verschoben wird. Die Verschiebung wird trotzdem
    // durchgeführt – der Benutzer soll bewusst übersteuern können.
    final jahrgang = int.parse(kohortenSchluessel.split('_')[0]);
    final istFuenfkampfKohorte = (aktuellesJahr - jahrgang) <= 5;
    if (istFuenfkampfKohorte != alleRiegen[zielIndex].fuenfKampf && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Achtung: Kohorte wurde in eine Riege des jeweils anderen '
            'Wettkampf-Typs (Fünf-/Zehnkampf) verschoben.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Speichern nach (ggf. manueller) Bestätigung durch den Benutzer
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _speichernUndAbschliessen() async {
    setState(() => isSaving = true);
    try {
      await _speichereEinteilungInDatenbank(
        bisherigerTyp: _bisherigerTyp,
        bisherigeZuordnung: _bisherigeZuordnung,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _log.e('Speichern der Riegeneinteilung fehlgeschlagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speichern fehlgeschlagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isSaving = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

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
                          onPressed: _ladeUndBerechneVorschlag,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildRiegenUebersicht(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Riegen-Übersicht: erst alle Fünfkampf-Riegen nebeneinander, dann alle
  // Zehnkampf-Riegen nebeneinander. Pro Riege eine Kopfzeile mit der
  // Gesamtgröße sowie je eine Zeile pro Kohorte (Jahrgang + Geschlecht) mit
  // Anzahl und editierbarer Riegennummer.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRiegenUebersicht() {
    final fuenfkampfIndizes = [
      for (int i = 0; i < riegenAnzahl; i++) if (alleRiegen[i].fuenfKampf) i,
    ];
    final zehnkampfIndizes = [
      for (int i = 0; i < riegenAnzahl; i++) if (!alleRiegen[i].fuenfKampf) i,
    ];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Fünfkampf-Riegen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _buildRiegenReihe(fuenfkampfIndizes),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Zehnkampf-Riegen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _buildRiegenReihe(zehnkampfIndizes),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _speichernUndAbschliessen,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Riegeneinteilung speichern & abschließen'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Zielbreite einer Riegen-Karte. Die tatsächliche Breite wird pro Zeile
  // an die verfügbare Bildschirmbreite angepasst (siehe _buildRiegenReihe),
  // dieser Wert dient nur als Richtwert für die Spaltenanzahl.
  static const double _riegenKarteZielBreite = 230;
  static const double _riegenKarteAbstand    = 12;

  Widget _buildRiegenReihe(List<int> riegenIndizes) {
    if (riegenIndizes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('– keine Riegen dieses Typs –'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wie viele Karten passen bei der aktuellen Breite nebeneinander?
          final spaltenAnzahl = ((constraints.maxWidth + _riegenKarteAbstand) /
                  (_riegenKarteZielBreite + _riegenKarteAbstand))
              .floor()
              .clamp(1, riegenIndizes.length);

          // Karten gleichmäßig auf die verfügbare Breite strecken, statt
          // rechts Leerraum zu lassen.
          final kartenBreite = (constraints.maxWidth -
                  (spaltenAnzahl - 1) * _riegenKarteAbstand) /
              spaltenAnzahl;

          return Wrap(
            spacing: _riegenKarteAbstand,
            runSpacing: _riegenKarteAbstand,
            children: riegenIndizes
                .map((i) => _buildRiegenKarte(i, kartenBreite))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildRiegenKarte(int riegenIndex, double breite) {
    final riege  = alleRiegen[riegenIndex];
    final kinder = riegenListen[riegenIndex];

    // Kohorten (Jahrgang + Geschlecht) innerhalb dieser Riege gruppieren
    final kohorten = <String, List<Kind>>{};
    for (final kind in kinder) {
      kohorten.putIfAbsent('${kind.jahrgang}_${kind.geschlecht}', () => []).add(kind);
    }
    final kohortenEintraege = kohorten.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return SizedBox(
      width: breite,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kopfzeile: Riegennummer + Gesamtgröße
              Text(
                'Riege ${riege.riegenNummer}   ·   ${kinder.length} Kind(er)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              if (kohortenEintraege.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('– leer –', style: TextStyle(color: Colors.grey)),
                ),
              // Eine Zeile je Kohorte: Jahrgang, Geschlecht, Anzahl,
              // editierbare Riegennummer
              ...kohortenEintraege.map((entry) {
                final teile      = entry.key.split('_');
                final jahrgang   = teile[0];
                final geschlecht = teile[1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$jahrgang ${geschlecht == 'w' ? '♀' : '♂'}  '
                          '(${entry.value.length})',
                        ),
                      ),
                      SizedBox(
                        width: 68,
                        child: DropdownButtonFormField<int>(
                          initialValue: riege.riegenNummer,
                          isDense: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(riegenAnzahl, (i) => i + 1)
                              .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                              .toList(),
                          onChanged: (neueNummer) {
                            if (neueNummer != null && neueNummer != riege.riegenNummer) {
                              _kohorteVerschieben(entry.key, neueNummer);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
