import 'package:flutter/material.dart';
//import 'package:sporttag/src/hilfs_widgets/beschreibung_button.dart';
import 'hilfs_widgets/hilfe_button.dart';
import 'klassen/kind_klasse.dart'; // Import der Kind-Klasse
import 'tools/kind_repository.dart'; // Import der KindRepository-Klasse

class AnmeldenSporttag extends StatefulWidget {
  const AnmeldenSporttag({super.key, required this.titel});
  final String? titel;

  @override
  AnmeldenSporttagState createState() => AnmeldenSporttagState();
}

class AnmeldenSporttagState extends State<AnmeldenSporttag> {
  final KindRepository kindRepository = KindRepository(); // Repository-Objekt
  List<Kind> kinderListe = []; // Liste der Kinder
  bool isLoading = true; // Ladeindikator

//  List<ParseObject> kinder = [];
  List<bool> editStates = [];
  final TextEditingController vornameController = TextEditingController();
  final TextEditingController nachnameController = TextEditingController();
  final TextEditingController geschlechtController = TextEditingController();
  final TextEditingController jahrgangController = TextEditingController();
  late FocusNode focusJahrgang;
  static const List<String> _geschlechtListe = ['w', 'm'];
  late String _geschlecht;
  late List<int> _jahrgangListe;
  late int _jahrgang;

  @override
  void initState() {
    super.initState();
    _ladeKinder();

    _geschlecht = _geschlechtListe.first;
    _jahrgang = _zulaessigeJahrgaenge().first;
    focusJahrgang = FocusNode();
  }

  _zulaessigeJahrgaenge() {
    // Die Logik um die zulässigen Jahrgänge zu bestimmen:
    // basierend auf dem aktuellen Datum und dem festegelegten minAlter bzw. maxAlter
    // wird die Liste der zulässigen Jahrgänge erstellt.
    int currentYear = DateTime.now().year;
    int maxAlter = 14; // Maximales Alter für die Anmeldung
    int minAlter = 3; // Minimales Alter für die Anmeldung
    _jahrgangListe = [];
    for (int i = minAlter; i <= maxAlter; i++) {
      _jahrgangListe.add(currentYear - i);
    }
    _jahrgangListe
        .sort((a, b) => b.compareTo(a)); // Jahrgänge absteigend sortieren
    return _jahrgangListe;
  }

  @override
  void dispose() {
    focusJahrgang.dispose();
    super.dispose();
  }

  // Methode, um alle Kinder aus der Datenbank zu laden
  Future<void> _ladeKinder() async {
    setState(() {
      isLoading = true; // Ladezustand aktivieren
    });

    kinderListe = await kindRepository
        .loadAllKinder(); // Alle Kinder aus der Datenbank laden

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
            jahrgang: '',
            geschlecht: '',
            erreichtePunkte: 0,
            riegenNummer: 0,
            bezahlt: true,
          ));
      editStates.insert(0, true); // Set new entry to be editable
    });
  }

  // Methode, um Änderungen an den Kindern zu speichern
  Future<void> _speichereAenderungen() async {
    await kindRepository
        .saveKinderListeToDatabase(kinderListe); // Änderungen speichern
    _ladeKinder();
  }

  void undoChanges() {
    // alten DAtenbestand wieder anzeigen
    _ladeKinder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: () {
              _speichereAenderungen();
              Navigator.of(context).pop();
            },
          ),
          const HelpIconButton(
              typ: HilfeTyp.text,
              thema: HilfeThema.anmeldung),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Expanded(
              child: ListView.builder(
                itemCount: kinderListe.length,
                itemBuilder: (context, index) {
                  final kind = kinderListe[index];
                  bool isEditable =
                      editStates[index]; // Check if the entry is editable
                  return ListTile(
                    title: isEditable
                        ? Column(
                            children: [
                              const SizedBox(height: 20),
                              TextFormField(
                                autofocus: true,
                                initialValue: kind.vorname,
                                decoration: const InputDecoration(
                                    hintText: 'Vorname eingeben'),
                                onChanged: (value) {
                                  kind.vorname = value;
                                },
                              ),
                              TextFormField(
                                initialValue: kind.nachname,
                                decoration: const InputDecoration(
                                    hintText: 'Nachname eingeben'),
                                onChanged: (value) {
                                  kind.nachname = value;
                                },
                              ),
                              DropdownButtonFormField<String>(
                                value: _geschlecht,
                                onChanged: (newValue) =>
                                    setState(() => kind.geschlecht = newValue!),
                                items: [
                                  for (String i in _geschlechtListe)
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
                                value: _jahrgang,
                                onChanged: (newValue) => setState(
                                    () => kind.jahrgang = '${newValue!}'),
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
                            activeColor: Colors.green,
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
                          onPressed: () {
                            setState(() {
                              editStates[index] =
                                  !editStates[index]; // Toggle edit mode
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
