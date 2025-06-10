import 'package:flutter/material.dart';
import 'kind_klasse.dart'; // Import der Kind-Klasse
import 'kind_repository.dart'; // Import der KindRepository-Klasse

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

  @override
  void initState() {
    super.initState();
    _ladeKinder();

    focusJahrgang = FocusNode();
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
//     kinder.insert(0, ParseObject('Kind')
      kinderListe.insert(
          0,
          Kind(
            vorname: '',
            nachname: '',
            jahrgang: '',
            geschlecht: '',
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
          IconButton(icon: const Icon(Icons.undo), onPressed: undoChanges),
          IconButton(
              icon: const Icon(Icons.save), onPressed: _speichereAenderungen),
          IconButton(icon: const Icon(Icons.add), onPressed: addNewKind),
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
                            TextFormField(
                              initialValue: kind.geschlecht,
                              decoration: const InputDecoration(
                                  hintText: 'Geschlecht eingeben'),
                              onChanged: (value) {
                                kind.geschlecht = value;
                              },
                            ),
                            TextFormField(
                              focusNode: focusJahrgang,
                              initialValue: kind.jahrgang,
                              decoration: const InputDecoration(
                                  hintText: 'Jahrgang eingeben'),
                              onChanged: (value) {
                                kind.jahrgang = value;
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        )
                      : Text(
                          '${kind.vorname} ${kind.nachname} - ${kind.geschlecht} - ${kind.jahrgang}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: kind.bezahlt,
                        onChanged: (value) {
                          setState(() {
                            kind.bezahlt = value;
                            focusJahrgang.requestFocus();
                          });
                        },
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
    );
  }
}
