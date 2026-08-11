import 'package:flutter/material.dart';

import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/klassen/riegen_klasse.dart';
import 'package:sporttag/src/klassen/station_klasse.dart';
import 'package:sporttag/src/repositories/kind_repository.dart';
import 'package:sporttag/src/repositories/station_repository.dart';
import 'package:sporttag/src/repositories/riegen_repository.dart';
import 'package:sporttag/src/tools/logger.util.dart';

/// Gemeinsames Grundgerüst für alle Stationen-Widgets (Sprint, Drehwurf,
/// HochWeitSprung, ...).
///
/// Übernimmt:
///  - Repository-Instanzen (Kind/Station/Riege)
///  - Gemeinsamen State (riegenKinder, selectedKinder, kinderZurAnzeige,
///    ausgewerteteKinder, station)
///  - Laden der Kinder/Station + Anzeige-Sortierung
///  - Wiederaufnahme-Check nach Abbruch/Neustart der Web-App: wurde GENAU
///    diese Station für diese Riege laut 'riegenLogging' bereits
///    abgeschlossen?
///  - Eintrag in 'riegenLogging', sobald alle Kinder ausgewertet sind
///
/// Die konkrete Bewertungslogik (StopUhr / Durchgänge / Versuche) liegt in
/// den jeweiligen Auswertungs-Mixins, die zusätzlich auf diesem Mixin
/// aufbauen (siehe stop_uhr_auswertung_mixin.dart etc.).
mixin StationenBasisMixin<T extends StatefulWidget> on State<T> {
  final KindRepository kindRepository = KindRepository();
  final StationRepository stationRepository = StationRepository();
  final RiegenRepository riegenRepository = RiegenRepository();
  final log = getLogger();

  /// Von der konkreten Station in initState() VOR ladeStationsdaten() zu
  /// setzen, z. B. stationsName = "Sprint";
  late String stationsName;

  /// Von der konkreten Station in initState() zu setzen:
  /// riegenPointer = widget.riegenPointer;
  late Riege riegenPointer;

  List<Kind> riegenKinder = [];
  Set<Kind> selectedKinder = {};
  List<Kind> kinderZurAnzeige = []; // Speichert anzuzeigende Teilnehmer
  Set<Kind> ausgewerteteKinder = {}; // Speichert ausgewertete Teilnehmer
  Station? station; // Speichert die Station

  /// Lädt Kinder + Station, prüft den Wiederaufnahme-Fall und baut die
  /// Anzeige-Liste auf. Von der konkreten Station aus initState() heraus
  /// aufzurufen, NACHDEM stationsName und riegenPointer gesetzt wurden.
  Future<void> ladeStationsdaten() async {
    riegenKinder =
        await kindRepository.ladeKinderDerRiege(riege: riegenPointer);
    station = await stationRepository.ladeStationNachName(
        stationsName: stationsName);

    // Exakter Check: wurde GENAU diese Station für diese Riege laut
    // riegenLogging bereits abgeschlossen? (z. B. nach Abbruch/Neustart
    // der Web-App mitten im Wettkampf)
    final bereitsAbgeschlossen =
        await riegenRepository.istStationBereitsProtokolliert(
      riege: riegenPointer,
      station: station!,
    );
    if (bereitsAbgeschlossen) {
      ausgewerteteKinder.addAll(riegenKinder);
    }

    // Hook für Sonderfälle beim Laden (z. B. Stadionrunde: alle Kinder
    // initial als selektiert markieren).
    nachLadenHook();

    if (!mounted) return;
    setState(() {
      kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
          alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
    });
  }

  /// Optionaler Hook, den einzelne Stationen überschreiben können, um nach
  /// dem Laden zusätzlich etwas zu tun (z. B. alle Kinder vorselektieren).
  /// Default: nichts.
  void nachLadenHook() {}

  /// Baut kinderZurAnzeige anhand des aktuellen ausgewerteteKinder-Standes
  /// neu auf. Von den Auswertungs-Mixins innerhalb von setState() genutzt.
  void aktualisiereAnzeigeSortierung() {
    kinderZurAnzeige = kindRepository.zurAnzeigeSortieren(
        alleKinder: riegenKinder, ausgewerteteKinder: ausgewerteteKinder);
  }

  /// Trägt in riegenLogging ein, dass diese Station für die Riege
  /// abgeschlossen ist, sobald ALLE Kinder ausgewertet sind. Idempotent
  /// (erhoeheStationszaehler hat einen eigenen Guard).
  Future<void> markiereStationFallsKomplett() async {
    if (station == null) return;
    if (ausgewerteteKinder.length == riegenKinder.length) {
      final erhoeht = await riegenRepository.erhoeheStationszaehler(
        riege: riegenPointer,
        station: station!,
      );
      if (!erhoeht) {
        log.w('Stationszähler für ${station!.stationsName} war bereits erhöht.');
      }
    }
  }

  /// In dispose() der konkreten Station aufzurufen.
  @mustCallSuper
  void resetStationsdaten() {
    riegenKinder.clear();
    selectedKinder.clear();
    kinderZurAnzeige.clear();
    ausgewerteteKinder.clear();
  }
}
