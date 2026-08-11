import 'package:flutter/material.dart';
import 'package:sporttag/src/hilfs_widgets/mein_karten_eintrag.dart';
import 'package:sporttag/src/hilfs_widgets/mein_listen_eintrag.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';

/// Baut für ein einzelnes [Kind] den optionalen, stationsspezifischen
/// Trailing-Inhalt der Karte (z. B. die Hütchen-Auswahl beim Sprint).
/// Disziplinen ohne eigenen Trailing-Inhalt übergeben einfach `null` als
/// [DisziplinKinderListe.trailingBuilder] oder lassen den Builder `null`
/// zurückgeben.
typedef KindTrailingBuilder = Widget? Function(BuildContext context, Kind kind);

/// Modularisierte Darstellung der Kinder-Liste als Card-Einträge.
///
/// Kapselt das Zusammenspiel aus [MeinKartenEintrag] (Card-Rahmen inkl.
/// Selektions-/Auswertungs-Optik) und [MeinListenEintrag] (Name + Punkte),
/// das bisher pro Disziplin einzeln im `ListView.builder` stand (siehe
/// ursprüngliches Sprint-Widget). Jede Disziplin bindet diese Liste ein und
/// hängt über [trailingBuilder] ihre eigene, stationsspezifische Eingabe
/// (Dropdown, TextField, Buttons, ...) in die Karte ein – ohne die
/// Card-/List-Logik zu duplizieren.
class DisziplinKinderListe extends StatelessWidget {
  /// Die aktuell anzuzeigenden Kinder (bereits stationsspezifisch gefiltert,
  /// z. B. via `_kinderFuerAnzeige` in der jeweiligen Disziplin-Klasse).
  final List<Kind> kinder;

  final Set<Kind> selectedKinder;
  final Set<Kind> ausgewerteteKinder;

  /// Bereits erzielte Punkte/Zeiten je Kind, sofern vorhanden.
  final Map<Kind, int> kinderMitZeiten;

  /// Wird aufgerufen, wenn der Nutzer ein Kind selektiert/deselektiert.
  /// Disziplinen, die nach dem Testlauf keine Änderung der Teilnehmerliste
  /// mehr erlauben, können hier früh zurückkehren
  /// (siehe Sprint: `if (!testLauf) return;`).
  final void Function(Kind kind, bool istSelektiert) onSelectionChanged;

  /// Liefert optional den stationsspezifischen Trailing-Inhalt einer Karte.
  /// Wird nur aufgerufen, wenn das Kind selektiert und noch nicht
  /// ausgewertet ist; alle weiteren Bedingungen entscheidet die jeweilige
  /// Disziplin selbst innerhalb des Builders.
  final KindTrailingBuilder? trailingBuilder;

  const DisziplinKinderListe({
    super.key,
    required this.kinder,
    required this.selectedKinder,
    required this.ausgewerteteKinder,
    required this.kinderMitZeiten,
    required this.onSelectionChanged,
    this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: kinder.length,
      itemBuilder: (context, index) {
        final kind = kinder[index];
        final zeit = kinderMitZeiten[kind];
        final istAusgewertet = ausgewerteteKinder.contains(kind);
        final istSelektiert = selectedKinder.contains(kind);

        final trailing = (istSelektiert && !istAusgewertet)
            ? trailingBuilder?.call(context, kind)
            : null;

        return MeinKartenEintrag(
          istSelektiert: istSelektiert,
          istAusgewertet: istAusgewertet,
          trailing: trailing,
          child: MeinListenEintrag(
            kind: kind,
            istAusgewertet: istAusgewertet,
            istSelektiert: istSelektiert,
            erreichtePunkte: zeit,
            onSelectionChanged: onSelectionChanged,
          ),
        );
      },
    );
  }
}
