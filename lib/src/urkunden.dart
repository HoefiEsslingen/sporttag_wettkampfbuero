import 'package:flutter/material.dart';
//import 'package:qr_flutter/qr_flutter.dart';
import 'package:sporttag/src/kind_repository.dart';

import 'kind_klasse.dart';
import 'logger.util.dart';
import 'riegen_klasse.dart';
import 'riegen_repository.dart';

class UrkundenDruck extends StatefulWidget {
  const UrkundenDruck({super.key, required this.titel});
  final String? titel;

  /// Aktivität vorbereiten
  @override
  UrkundenDruckState createState() => UrkundenDruckState();
}

class UrkundenDruckState extends State<UrkundenDruck> {
  /***********************************
   * In den Riegen wird geschaut, ob die notwendige Anzahl der Stationen erreicht wurde:
   * - Riegen mit dem Status fuenfKampf = true --> 5 Stationen
   * - Riegen mit dem Status fuenfKampf = false --> 10 Stationen
   * 
   * Bei ausgewerteten Riegen wird das Attribut 'ausgewertet' (in der Datenbank) auf 'true' gesetzt.
   * 
   * Die Kinder aus den auszuwertenden Riegen werden nach Jahrgang und Geschlecht sortiert.
   * Die Kombination Jahrgang und Geschlecht wird in der Drop-Down-Liste angezeigt.
   * 
   * Die Kinder der auswählbaren Jahrgang-Geschlecht-Kombination werden in der ListView angezeigt.
   * 
   */

  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
  final RiegenRepository riegenRepository =
      RiegenRepository(); // Repository-Objekt
  List<Riege> auszuwertendeRiegenListe = [];
  List<Kind> alleAuszuwertendenKinder = [];
  final int riegenAnzahl = 8;
//  List<int> riegenListe = [];
  int? ausgewaehlteRiegenNummer;
  List<Kind> gefilterteKinder = [];
  Map<String, List<Kind>> jahrUgeschlechtMap =
      {}; // Geschlecht + Jahrgang als Key
  String? gruppe; // Gruppe (Jahrgang + Geschlecht) für die DropDown-Auswahl
  String qrCodeUrl =
      ''; //= 'https://gs-gp.eu'; // Platzhalter für die URL des QR-Codes

  // Logger einrichten
  final log = getLogger();

  @override
  void initState() {
    super.initState();
    // lade alle notwendigen Daten für den Urkunden-Druck
    _initialisiereUrkundenDruck();
  }

  Future<void> _initialisiereUrkundenDruck() async {
    await _ladeAuszuwertendeRiegen();
    await _ladeKinderAusAuszuwertendenRiegen();
    _sortiereKinderAusAuszuwertendenRiegen();
    setState(() {}); // UI neu rendern, wenn alle Daten bereit
  }

  Future<void> _ladeAuszuwertendeRiegen() async {
    auszuwertendeRiegenListe =
        await riegenRepository.loadAllAuszuwertendeRiegen();
    log.i(
        'Anzahl der auszuwertenden Riegen: ${auszuwertendeRiegenListe.length} z.B. ${auszuwertendeRiegenListe.map((r) => r.riegenNummer).join(', ')}');
  }

  // Methode in der die Kimnder aus den ausgewählten Riegen gelden,
  // nach dem selben Geschlecht und dem selben Jahrgang gruppiert werden
  // sowie im Anschluss nach erreichter Punktzahl absteigend sortiert werden
  Future<void> _ladeKinderAusAuszuwertendenRiegen() async {
    log.i(
        'Lade Kinder aus den auszuwertenden Riegen: ${auszuwertendeRiegenListe.length} Riegen');
    alleAuszuwertendenKinder = await kindRepository.loadKinderAusRiegen(
        listeVonRiegen: auszuwertendeRiegenListe);
  }

  // Methode, die die Kinder nach Jahrgang und Geschlecht gruppiert und sortiert
  void _sortiereKinderAusAuszuwertendenRiegen() {
    log.i(
        'Anzahl der auszuwertenden Kinder aus allen fertigen Riegen: ${alleAuszuwertendenKinder.length} z.B. ${alleAuszuwertendenKinder.join(', ')}');
    setState(() {
      jahrUgeschlechtMap =
          kindRepository.gruppiereKinder(ausDerListe: alleAuszuwertendenKinder);
      //sortiere nach erreichter Punktzahl in den Gruppen
      jahrUgeschlechtMap.forEach((key, value) {
        value.sort((a, b) => b.erreichtePunkte.compareTo(a.erreichtePunkte));
      });
    });
  }

  Future<bool> _zeigeBestaetigungsDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Urkunden geschrieben?'),
            content: const Text(
                'Wurden für diese Gruppe bereits Urkunden erstellt?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Nein'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Ja'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _riegenAlsAusgewertetSetzen() {
    // Setze alle Riegen in der auszuwertenden Liste auf ausgewertet
    for (var riege in auszuwertendeRiegenListe) {
      riege.ausgewertet = true; // Setze das Attribut 'ausgewertet' auf true
      riegenRepository.saveRiegeToDatabase(riege: riege);
    }
    Navigator.of(context).pop();
    log.i('Alle Riegen wurden als ausgewertet markiert.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel ?? 'Urkunden Druck'),
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 72.0),
          children: [
            // Dropdown zur Auswahl der Riegennummer
            DropdownButton<String>(
              hint: const Text('Wähle eine Gruppe (Jahrgang & Geschlecht)'),
              value: gruppe,
              items: jahrUgeschlechtMap.keys.map((String key) {
                final teile = key.split('_');
                final geschlecht = teile[0] == 'm' ? 'männlich' : 'weiblich';
                final jahrgang = teile[1];
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text('$jahrgang – $geschlecht'),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  gruppe = newValue;
                  gefilterteKinder = jahrUgeschlechtMap[newValue] ?? [];
                });
              },
            ),
            const SizedBox(height: 16.0),
            // Liste der gefilterten Kinder
            ...gefilterteKinder.map(
              (kind) {
                return ListTile(
                  title: Text(
                      '${kind.vorname} ${kind.nachname} ${kind.jahrgang} ${kind.geschlecht}'),
                  subtitle: Text('erreichte Punkte: ${kind.erreichtePunkte}'),
                );
              },
            ),
            const SizedBox(height: 24.0),
            jahrUgeschlechtMap.isNotEmpty
                // Wenn keine Riegen vorhanden sind, zeige eine Schaltfläche an
                ? gefilterteKinder.isEmpty
                    ? const SizedBox()
                    : ElevatedButton.icon(
                        onPressed: gruppe == null
                            ? null
                            : () async {
                                final bestaetigt =
                                    await _zeigeBestaetigungsDialog();
                                if (bestaetigt) {
                                  setState(() {
                                    jahrUgeschlechtMap.remove(gruppe);
                                    gruppe = null;
                                    gefilterteKinder.clear();
                                    jahrUgeschlechtMap.isEmpty
                                        ? _riegenAlsAusgewertetSetzen()
                                        : null;
                                  });
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('Urkunden erstellt?'),
                      )
                : ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Keine Riege zur Auswertung bereit.'),
                  ),
          ],
        ),
      ),
    );
  }
}