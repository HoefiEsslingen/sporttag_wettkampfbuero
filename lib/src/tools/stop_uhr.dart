import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/hilfs_widgets/rueck_sprung_button.dart';

import '../hilfs_widgets/meine_appbar.dart';

import 'logger.util.dart';
import 'teilnehmer_liste.dart';
import 'teilnehmerliste_verschiebbar.dart';

class MyStopUhr extends StatefulWidget {
  const MyStopUhr({
    super.key,
    required this.teilNehmer,
    required this.rufendeStation, // 0: Timer, 1: Stoppuhr, 2: Rundenmodus
    required this.auswertenDerWerte,
  });

  final List<Kind> teilNehmer;
  final String rufendeStation; // Name der Station, die die Uhr aufruft
  final Function(Map<Kind, int>) auswertenDerWerte;

  @override
  State<MyStopUhr> createState() => _MyStopUhrState();
}

class _MyStopUhrState extends State<MyStopUhr> {
  final log = getLogger();

  // Initialisiere die Übergabeparameter
  get teilNehmer => widget.teilNehmer;
  get rufendeStation =>
      widget.rufendeStation; // Name der Station, die die Uhr aufruft
  get auswertenDerWerte => widget.auswertenDerWerte;

  late Stopwatch stopwatch;
  late Timer t;
  late int timerZeit;
  Duration aenderungsIntervall = const Duration(milliseconds: 100);
  Duration timerDuration = const Duration(seconds: 30);
  Duration remainingTime = Duration.zero;

  final Map<Kind, int> _werte = {};
  bool alleGestoppt = false;
  bool isBlinking = false;
  double opacity = 1.0;
  int modus = -1;

  @override
  void initState() {
    super.initState();
    stopwatch = Stopwatch();

    // legt aufgrund der rufenden Station den Modus fest
    switch (rufendeStation) {
      case 'Sprint':
        modus = 0; // Timer-Modus
        timerZeit = 10; // Zeit in Sekunden
        break;
      case '30sec-Lauf':
        modus = 2; // Rundenzähler im Timer-Modus
        timerZeit = 30; // Zeit in Sekunden
        break;
      case 'Bananenkartons':
      case 'Stadionrunde':
        modus = 1; // StopUhr-Modus
        break;
    }

    if (modus == 0 || modus == 2) {
      timerDuration = Duration(seconds: timerZeit);
      remainingTime = timerDuration;

      // Start Blinken bei 2 Sek
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (remainingTime.inSeconds <= 2) {
          setState(() {
            opacity = opacity == 1.0 ? 0.5 : 1.0;
          });
        }
      });
    }

    // UI-Aktualisierung
    t = Timer.periodic(aenderungsIntervall, (timer) {
      setState(() {
        if (modus == 0 || modus == 2) {
          _updateTimer();
        } else {
          _updateStopwatch();
        }
      });
    });
  }

  void _updateTimer() {
    if (remainingTime > Duration.zero && stopwatch.isRunning) {
      remainingTime -= aenderungsIntervall;
      // Überprüfe, ob die Zeit abgelaufen ist
      if (remainingTime <= Duration.zero) {
        stopwatch.stop();
        remainingTime = Duration.zero;
        if (_werte.length <= teilNehmer.length) {
          // Timer ist abgelaufen, aber nicht alle Teilnehmer wurden gestoppt
          // Das kann beim Sprint passieren, wenn ein Teilnehmer nicht innnerhalb der 10 sec im Ziel ist
          for (var kind in teilNehmer) {
            if (!_werte.containsKey(kind)) {
              _werte[kind] = -1; // Teilnehmer mit -1 Zeit hinzufügen
            }
          }
        }
        alleGestoppt = true;
        t.cancel();
      }
    }
  }

  void _updateStopwatch() {
    // kein direkter Effekt – Werte werden bei Buttondruck geholt
  }

// Funktion zum Starten und Stoppen der Stoppuhr auskommentiert
  void handleStartStop() {
    if (!stopwatch.isRunning) {
      stopwatch.start();
      if (modus != 1) remainingTime = timerDuration;
    } else {
      // Stoppuhr stoppen ist auskommentiert, da die Stoppuhr nur bei Button-Druck gestoppt werden soll
      // stopwatch.stop();
    }
  }

  // Funktion zum Stoppen der Stoppuhr für einen Teilnehmer
  // wird aufgerufen, wenn der Teilnehmer auf den Button drückt
  void _stopForKind(Kind kind) {
    if (_werte.containsKey(kind)) return;

    setState(() {
      // in der Map _werte wird der Teilnehmer mit der Zeit gespeichert
      // im Modus 0 (Timer für Sprint) wird die Rest-Zeit verbleibend von den 10 sec gespeichert
      // sonst (Modus 1: Stoppuhr) wird die Zeit gespeichert, die seit dem Start der Stoppuhr vergangen ist
      _werte[kind] = (modus == 0)
          ? remainingTime.inMilliseconds
          : stopwatch.elapsed.inMilliseconds;

      if (_werte.length == teilNehmer.length) {
        alleGestoppt = true;
        t.cancel();
      }
    });
  }

  void _setRunden(Kind kind, int runden) {
    setState(() {
      _werte[kind] = runden;
      log.i('Runden für ${kind.vorname} ${kind.nachname}: $runden');
    });
  }

  Color getUhrFarbe() {
    if (modus == 1) return Colors.white;
    if (remainingTime.inSeconds > 2) return Colors.green;
    if (remainingTime.inSeconds > 0) return Colors.orange;
    return Colors.red;
  }

  // Funktion zum Formatieren der Zeit
  String returnFormattedText() {
    final duration =
        (modus == 0 || modus == 2) ? remainingTime : stopwatch.elapsed;
    final milli = duration.inMilliseconds;

    if (modus == 1 && duration.inSeconds >= 60) {
      // Minutenanzeige ab 60 Sekunden im Stoppuhrmodus
      final minutes = (milli ~/ 60000).toString().padLeft(2, "0");
      final seconds = ((milli ~/ 1000) % 60).toString().padLeft(2, "0");
      return "$minutes:$seconds";
    } else {
      // Standardanzeige: Sekunden.Zehntelsekunde
      final seconds = ((milli ~/ 1000) % 60).toString().padLeft(2, "0");
      final tenths = ((milli ~/ 100) % 10).toString();
      return "$seconds.$tenths";
    }
  }

  @override
  void dispose() {
    t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRunning = stopwatch.isRunning;
    return Scaffold(
      appBar: MeineAppBar(
        titel: 'Klick die Uhr zum Start.',
      ),
      body: Column(
        children: [
          // Hier wird die Uhr angezeigt
          CupertinoButton(
            onPressed: !isRunning
                ? handleStartStop
                : null, // StoppUhr selbst soll nicht ausgeschaltet werden können
            padding: EdgeInsets.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: remainingTime.inSeconds <= 2 ? opacity : 1.0,
              child: Container(
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: getUhrFarbe(),
                  border: Border.all(color: Colors.blue, width: 4),
                ),
                child: Text(
                  returnFormattedText(),
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // Abstandshalter
          const SizedBox(height: 10),
          // Hier wird der Modus angezeigt
          Text(
            (modus == 2)
                // Rundenzähler-Modus
                ? 'Plus/Minus für halbe Runden – solange Uhr läuft'
                : 'Stoppe individuell pro Teilnehmer',
          ),
          // Liste der an dieser Runde teilnehmenden Kinder
          Expanded(
            child: rufendeStation == 'Stadionrunde'
                // Stadion-Runde: Teilnehmer können verschoben werden
                ? TeilnehmerVerschiebbar(
                    teilNehmer: teilNehmer,
                    kindMitWerten: _werte,
                    isRunning: isRunning,
                    modus: modus,
                    onValueChanged: (modus == 2)
                        // Runden-Modus: Plus/Minus-Buttons
                        ? _setRunden
                        // Timer- oder Stoppuhr-Modus: Stoppe den Teilnehmer
                        : (kind, _) => _stopForKind(kind),
                  )
                : TeilnehmerListe(
                    teilNehmer: teilNehmer,
                    kindMitWerten: _werte,
                    isRunning: isRunning,
                    modus: modus,
                    onValueChanged: (modus == 2)
                        // Runden-Modus: Plus/Minus-Buttons
                        ? _setRunden
                        // Timer- oder Stoppuhr-Modus: Stoppe den Teilnehmer
                        : (kind, _) => _stopForKind(kind),
                  ),
          ),
          // Hier wird ein Button angezeigt, um diese Runde zu beenden
          // als Stoppuhr --> Ende wenn alle gestoppt sind
          // als Timer --> Ende wenn alle vor Ablauf des Timers gestoppt sind oder der Timer abgelaufen ist
          if (alleGestoppt)
            ZurueckButton(
              label: 'Zurück und auswerten',
              auswertenDerErgebnisse: () {
                log.i('Rückgabe: ${_werte.length} Einträge');
                auswertenDerWerte(_werte);
              },
            ),
        ],
      ),
    );
  }
}
