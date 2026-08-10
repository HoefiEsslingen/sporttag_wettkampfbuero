import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sporttag/src/mixins/anmeldung/kind_pruef_ergebnis.dart';
import 'package:sporttag/src/tools/sporttag_config.dart';
import 'package:sporttag/src/hilfs_widgets/hilfe_button.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart'; // Import der Kind-Klasse
import 'package:sporttag/src/repositories/kind_repository.dart'; // Import der KindRepository-Klasse
// Import der Hilfsklassen für die Anmeldung
import 'package:sporttag/src/tools/anmeldung/geschlecht_optionen.dart';
import 'package:sporttag/src/tools/anmeldung/jahrgangs_helper.dart';
import 'package:sporttag/src/tools/anmeldung/kind_validator.dart';
import 'package:sporttag/src/mixins/anmeldung/duplikat_pruefung_mixin.dart';
import 'package:sporttag/src/mixins/anmeldung/anmelde_sperre_mixin.dart';

class AnmeldenSporttag extends StatefulWidget {
  const AnmeldenSporttag({super.key, required this.titel});
  final String? titel;

  @override
  AnmeldenSporttagState createState() => AnmeldenSporttagState();
}

class AnmeldenSporttagState extends State<AnmeldenSporttag>
    with
        DuplikatPruefungMixin<AnmeldenSporttag>,
        AnmeldeSperreMixin<AnmeldenSporttag> {
  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
  List<Kind> kinderListe = []; // Liste der Kinder
  bool isLoading = true; // Ladeindikator
  late SporttagConfig config;

  List<bool> editStates = [];
  final TextEditingController vornameController = TextEditingController();
  final TextEditingController nachnameController = TextEditingController();
  final TextEditingController geschlechtController = TextEditingController();
  final TextEditingController jahrgangController = TextEditingController();
  late FocusNode focusJahrgang;
  late String _geschlecht;
  late List<int> _jahrgangListe;
  late int _jahrgang;
  //Editier-Felder in ein Form-Widget mit GlobalKey<FormState> einbetten
  final Map<int, GlobalKey<FormState>> _formKeys = {};

  @override
  void initState() {
    super.initState();
    _ladeKinder();
    // Zugriff über context.read, da initState synchron ist
    config = context.read<SporttagConfig>();

    _geschlecht = GeschlechtOptionen.standard;
    _jahrgangListe = JahrgangsHelper.zulaessigeJahrgaenge(config);
    _jahrgang = _jahrgangListe.first;
    focusJahrgang = FocusNode();
  }

  @override
  void dispose() {
    focusJahrgang.dispose();
    super.dispose();
  }

  GlobalKey<FormState> _formKeyFuer(int index) {
    return _formKeys.putIfAbsent(index, () => GlobalKey<FormState>());
  }

  // Methode, um alle Kinder aus der Datenbank zu laden
  Future<void> _ladeKinder() async {
    setState(() {
      isLoading = true; // Ladezustand aktivieren
    });

    kinderListe = await kindRepository
        .ladeAlleKinder(); // Alle Kinder aus der Datenbank laden

    // Kinderliste aufsteigend nach Nachnamen
    kinderListe.sort((a, b) => a.nachname.compareTo(b.nachname));
    // Synchronisiere editStates mit kinderListe
    editStates = List<bool>.generate(kinderListe.length, (index) => false);

    setState(() {
      isLoading = false; // Ladezustand deaktivieren
    });
  }

  void addNewKind() {
    setState(() {
      kinderListe.insert(
          0,
          Kind(
            vorname: '',
            nachname: '',
            jahrgang: _jahrgang,
            geschlecht: _geschlecht,
            erreichtePunkte: 0,
            riegenNummer: 0,
            bezahlt: true,
          ));
      editStates.insert(0, true); // Set new entry to be editable
    });
  }

  // Methode, um Änderungen an den Kindern zu speichern
  Future<void> _speichereAenderungen() async {
    final zuSpeichern =
        kinderListe.where((k) => k.mussGespeichertWerden).toList();

    if (zuSpeichern.isEmpty) {
      return;
    }

    for (final kind in zuSpeichern) {
      final ergebnis = await pruefeKindVorSpeichern(kind, kinderListe);
      if (!context.mounted) return;

      switch (ergebnis) {
        case KindPruefErgebnis.gueltig:
          continue; // nächstes Kind prüfen

        case KindPruefErgebnis.namensfehler:
          // Fehlerdialog wurde bereits gezeigt; im Editiermodus bleiben,
          // Kind NICHT entfernen, da der Nutzer korrigieren soll.
          return;

        case KindPruefErgebnis.duplikatAbgelehnt:
          // wie bisher: neues Kind entfernen, bestehendes im Editiermodus belassen
          setState(() {
            if (kind.istNeu) {
              final index = kinderListe.indexOf(kind);
              if (index != -1) {
                kinderListe.removeAt(index);
                editStates.removeAt(index);
              }
            }
          });
          return;
      }
    }

    // Speichern jetzt über Mixin gesperrt statt eigenem showDialog:
    await fuehreGesperrtAus(() async {
      final fehlgeschlagen =
          await kindRepository.saveKinderListe(kinder: zuSpeichern);
      setState(() {
        for (final k in zuSpeichern) {
          if (!fehlgeschlagen.contains(k)) k.markiereAlsGespeichert();
        }
      });
      await _ladeKinder();

      if (fehlgeschlagen.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${fehlgeschlagen.length} Kind(er) konnten nicht gespeichert werden.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void undoChanges() {
    // alten DAtenbestand wieder anzeigen
    _ladeKinder();
  }

  @override
  Widget build(BuildContext context) {
    return sperrbaresPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.titel!),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                tooltip: "Neues Kind anmelden",
                icon: const Icon(Icons.add),
                onPressed: addNewKind),
            IconButton(
                tooltip: "Änderung rückgängig machen",
                icon: const Icon(Icons.undo),
                onPressed: undoChanges),
            IconButton(
                tooltip: "Änderungen speichern",
                icon: const Icon(Icons.save),
                onPressed: _speichereAenderungen),
            IconButton(
              tooltip: "Anmeldung beenden",
              icon: const Icon(Icons.cancel),
              onPressed: () async {
                await _speichereAenderungen(); // NEU: await ergänzt
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const HelpIconButton(
                typ: HilfeTyp.text, thema: HilfeThema.anmeldung),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: kinderListe.length,
                itemBuilder: (context, index) {
                  final kind = kinderListe[index];
                  bool isEditable =
                      editStates[index]; // Check if the entry is editable
                  return ListTile(
                    title: isEditable
                        ? Form(
                            key: _formKeyFuer(index),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                TextFormField(
                                  autofocus: true,
                                  initialValue: kind.vorname,
                                  decoration: const InputDecoration(
                                    hintText: 'Vorname eingeben',
                                    errorStyle: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  validator: KindValidator.validiereVorname,
                                  onChanged: (value) {
                                    kind.vorname = value;
                                  },
                                ),
                                TextFormField(
                                  initialValue: kind.nachname,
                                  decoration: const InputDecoration(
                                    hintText: 'Nachname eingeben',
                                    errorStyle: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  validator: KindValidator.validiereNachname,
                                  onChanged: (value) {
                                    kind.nachname = value;
                                  },
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: kind.geschlecht.isNotEmpty
                                      ? kind.geschlecht
                                      : _geschlecht,
                                  onChanged: (newValue) => setState(
                                      () => kind.geschlecht = newValue!),
                                  items: [
                                    for (String i in GeschlechtOptionen.alle)
                                      DropdownMenuItem(
                                        value: i,
                                        child: Text(i),
                                      )
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Geschlecht',
                                    filled: true,
                                  ),
                                ),
                                // Auswahl-Menü für den Jahrgang
                                DropdownButtonFormField<int>(
                                  initialValue: kind.jahrgang != 0
                                      ? kind.jahrgang
                                      : _jahrgang,
                                  // initialValue: _jahrgang,
                                  onChanged: (newValue) =>
                                      setState(() => kind.jahrgang = newValue!),
                                  items: [
                                    for (int i in _jahrgangListe)
                                      DropdownMenuItem(
                                        value: i,
                                        child: Text('$i'),
                                      )
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Jahrgang',
                                    filled: true,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          )
                        : Text(
                            '${kind.vorname} ${kind.nachname} - ${kind.geschlecht} - ${kind.jahrgang}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Wurde Startgebühr bezahlt',
                          child: Switch(
                            value: kind.bezahlt,
                            activeThumbColor: Colors.green,
                            inactiveThumbColor: Colors.red,
                            onChanged: (value) {
                              setState(() {
                                kind.bezahlt = value;
                                focusJahrgang.requestFocus();
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(isEditable ? Icons.check : Icons.edit),
                          onPressed: () async {
                            if (isEditable) {
                              // 1. Namens-Validierung
                              final formKey = _formKeyFuer(index);
                              final formGueltig =
                                  formKey.currentState?.validate() ?? false;
                              if (!formGueltig) {
                                return; // im Editiermodus bleiben, Fehler werden inline angezeigt
                              }

                              // 2. Duplikat-Prüfung
                              final bestaetigt =
                                  await pruefeAufDuplikat(kind, kinderListe);
                              if (!context.mounted) return;

                              if (!bestaetigt) {
                                // Anmeldemodus ohne Speichern beenden:
                                // Kind aus der Liste entfernen, falls es neu war,
                                // sonst Editiermodus einfach verlassen ohne Änderung zu übernehmen
                                setState(() {
                                  if (kind.istNeu) {
                                    kinderListe.removeAt(index);
                                    editStates.removeAt(index);
                                  } else {
                                    editStates[index] =
                                        false; // Editiermodus verlassen
                                  }
                                });
                                return;
                              }
                              // bei Bestätigung: normal fortfahren, beide Einträge bleiben bestehen
                            }
                            setState(() {
                              editStates[index] = !editStates[index];
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
