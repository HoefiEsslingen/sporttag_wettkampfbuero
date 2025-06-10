import 'package:flutter/material.dart';
import '../klassen/kind_klasse.dart';

//class MeinListenEintrag extends StatefulWidget {
class MeinListenEintrag extends StatelessWidget {
  final Kind kind;
  final bool istAusgewertet;
  final bool istSelektiert;
  final int? erreichtePunkte;
  final Function(Kind, bool) onSelectionChanged; // Callback hinzufügen

  const MeinListenEintrag({
    super.key,
    required this.kind,
    required this.istAusgewertet,
    required this.istSelektiert,
    this.erreichtePunkte,
    required this.onSelectionChanged, // Callback initialisieren
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: kind.geschlecht == 'w'
          ? const Icon(
              Icons.woman,
              color: Colors.pink,
              size: 45.0,
            ) // Icon(Icons.child_care, color: Colors.pink)
          : const Icon(
              Icons.man_outlined,
              color: Colors.blueAccent,
              size: 45.0,
            ), //Icons.child_care, color: Colors.blue),
      title: Text(
        '${kind.jahrgang} ${kind.vorname} ${kind.nachname}',
        style: istAusgewertet
            ? TextStyle(
                fontSize: 18,
                fontStyle: istAusgewertet ? FontStyle.italic : FontStyle.normal,
                color: istAusgewertet ? Colors.amber : Colors.black,
              )
            : Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (erreichtePunkte != null)
            Text('An dieser Station wurden $erreichtePunkte Punkte erzielt.'),
            Text(              
              'bisherige Gesamtpunktzahl: ${kind.erreichtePunkte}',
              style: TextStyle(
                fontStyle: istAusgewertet ? FontStyle.italic : FontStyle.normal,
                color: istAusgewertet ? Colors.amber : Colors.black,
              ),
            ),
        ],
      ),
      onTap: istAusgewertet
          // 'istAusgewertet' ist true, daher keine Aktion
          ? null
          // ein noch nicht ausgertetes Kind wurde selektiert, daher wird die Callback-Funktion 'onSelectionChanged' aufgerufen
          : () => onSelectionChanged(kind, !istSelektiert),
      selected: istSelektiert,
      selectedTileColor: Colors.blue[100],
    );
  }
}
