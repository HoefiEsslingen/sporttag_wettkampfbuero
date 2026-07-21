import 'package:sporttag/src/repositories/riegen_repository.dart';

import 'hilfs_widgets/meine_appbar.dart';
import 'klassen/riegen_klasse.dart';
import 'tools/logger.util.dart';
import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';
import 'package:sporttag/src/repositories/kind_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RiegenZuordnung extends StatefulWidget {
  const RiegenZuordnung({super.key, required this.titel});
  final String? titel;

  /// Aktivität vorbereiten
  @override
  RiegenZuordnungState createState() => RiegenZuordnungState();
}

class RiegenZuordnungState extends State<RiegenZuordnung> {
  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
  final RiegenRepository riegeRepository = RiegenRepository();
  List<Riege> alleRiegen = []; // Liste aller Riegen
  final int riegenAnzahl = 8;
  List<int> riegenListe = [];
  int? ausgewaehlteRiegenNummer;
  Riege? ausgewaehlteRiege; // vollständiges Riege-Objekt der aktuellen Auswahl
  List<Kind> gefilterteKinder = [];
 // Jahrgänge der Kinder der ausgewählten Riege
  List<int> jahrgaengeInRiege = [];
  String? wettbewerb;
  String qrCodeUrl =
      ''; //= 'https://gs-gp.eu'; // Platzhalter für die URL des QR-Codes
  // Logger einrichten
  final log = getLogger();

  @override
  void initState() {
    super.initState();
    riegenListe = List.generate(riegenAnzahl, (index) => index + 1);
    // Lädt die Riegen aus der Datenbank
    ladeRiegen();
  }

  Future<void> ladeRiegen() async {
    alleRiegen = await riegeRepository.ladeAlleRiegen();
  }

  // Methode für die Anzeige der einzelnen Riege
  Future<void> _filterKinderNachRiege(Riege riege) async {
    // Lädt gezielt nur die Kinder dieser Riege (über kinderDerRiege),
    // statt alle Kinder zu laden und clientseitig zu filtern.
    final kinderDerRiege =
        await kindRepository.ladeKinderDerRiege(riege: riege);
    if (!mounted) return; // Widget bereits disposed → abbrechen
    setState(() {
      gefilterteKinder = kinderDerRiege
        // sortiert die Kinder nach Geschlecht unnerhalb des gleichen Jahrgangs
        ..sort((a, b) {
          int jahrgangsVergleich = b.jahrgang.compareTo(a.jahrgang);
          if (jahrgangsVergleich != 0) {
            // gleicher Jahrgang
            return jahrgangsVergleich;
          }
          return b.geschlecht.compareTo(a.geschlecht);
        });
      // ermittelt die (eindeutigen) Jahrgänge der Riege für die Untertitel-Anzeige
      jahrgaengeInRiege = gefilterteKinder
          .map((kind) => kind.jahrgang)
          .toSet()
          .toList()
        ..sort();
    });
  }

  String _updateQrCodeUrl() {
    if (ausgewaehlteRiegenNummer != null) {
        // Wettbewerb wird weiterhin lokal benötigt, um im Button unten die
      // Anzahl der Disziplinen (5 bzw. 10) anzuzeigen. In die QR-URL selbst
      // muss er nicht mehr aufgenommen werden, da die Ziel-App diese
      // Information bereits aus der Datenbank lädt.
      wettbewerb = ausgewaehlteRiege!.fuenfKampf ? 'Fuenfkampf' : 'Zehnkampf';
      qrCodeUrl =
          'https://hoefiesslingen.github.io/#/wettkampf/$ausgewaehlteRiegenNummer'; //?wettbewerb=$wettbewerb';
    } else {
      qrCodeUrl = '';
    }
    return qrCodeUrl;
  }

  void _entferneRiegeAusDropDownListe() {
    if (ausgewaehlteRiegenNummer != null) {
      setState(() {
        riegenListe.remove(
            ausgewaehlteRiegenNummer); // Entfernt die ausgewählte Riege aus der Liste
        ausgewaehlteRiegenNummer = null; // Setzt die Auswahl zurück
        gefilterteKinder.clear(); // Löscht die Liste der angezeigten Kinder
        jahrgaengeInRiege.clear(); // Löscht die Jahrgangs-Übersicht
        qrCodeUrl =
            ''; // Kommentar entfernen, wenn Qr-Code generiert werden kann
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeineAppBar(titel: widget.titel ?? 'Riegen Zuordnung', thema: 'Riegen Zuordnung'),
      body: Center(
        child: Column(
          children: [
            Padding(
              // ein Widget, um leeren Raum um ein inneres Widget zu schaffen
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButton<int>(
                    hint: const Text('Wähle eine Riege'),
                    value: ausgewaehlteRiegenNummer,
                    items: riegenListe.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('Riege $value'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      // Passendes Riege-Objekt zur gewählten Riegennummer
                      // einmalig ermitteln und für die weitere Verwendung speichern.
                      Riege? riege;
                      if (newValue != null) {
                        for (final r in alleRiegen) {
                          if (r.riegenNummer == newValue) {
                            riege = r;
                            break;
                          }
                        }
                        if (riege == null) {
                          log.w(
                              'Riege $newValue wurde in alleRiegen nicht gefunden.');
                        }
                      }
                      setState(() {
                        ausgewaehlteRiegenNummer = newValue;
                        ausgewaehlteRiege = riege;
                      });
                      if (riege != null) {
                        _filterKinderNachRiege(riege);
                        // Aktualisiert die URL des QR-Codes
                        _updateQrCodeUrl();
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Linke Spalte: Übersicht der Riege vor der Freigabe
                    // Titel = Riegennummer, Untertitel = Jahrgänge, darunter Name/Vorname der Kinder
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (ausgewaehlteRiegenNummer != null)
                            Card(
                              child: ListTile(
                                title: Text(
                                  'Riege $ausgewaehlteRiegenNummer',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${jahrgaengeInRiege.isEmpty ? 'Keine Jahrgänge' : 'Jahrgänge: ${jahrgaengeInRiege.join(', ')}'}\n'
                                  'Anzahl Kinder: ${gefilterteKinder.length}',
                                ),
                                isThreeLine: true,
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: gefilterteKinder.length,
                              itemBuilder: (context, index) {
                                final kind = gefilterteKinder[index];
                                return ListTile(
                                  title: Text(
                                      '${index + 1}. ${kind.nachname} ${kind.vorname}'),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rechte Spalte: QR-Code
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (ausgewaehlteRiegenNummer != null) ...[
                            QrImageView(
                              data:
                                  _updateQrCodeUrl(), // hier muss eine Methode hin, die einen QR-Code generiert abhängig von der Riege
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                _entferneRiegeAusDropDownListe();
                                if (riegenListe.isEmpty) {
                                  Navigator.pop(context, false);
                                }
                              },
                              child: Text(
                                "Riege Nr. ${ausgewaehlteRiegenNummer ?? ''}\n${wettbewerb == "Fuenfkampf" ? 5 : 10} Disziplinen",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
