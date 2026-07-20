import 'package:flutter/material.dart';

/// Generischer Card-Wrapper für Listeneinträge (z. B. Kinder/Teilnehmer),
/// die je nach Zustand unterschiedlich eingefärbt werden sollen:
/// - ausgewertet  -> gedämpfte Farbe
/// - ausgewählt   -> Hervorhebungsfarbe
/// - neutral      -> Standard-Kartenfarbe
///
/// Kennt selbst keine fachliche Logik (kein Kind, keine Punkte) und kann
/// daher in Sprint, Wettbewerb, Lauf, Weitsprung, ... wiederverwendet werden.
class MeinKartenEintrag extends StatelessWidget {
  /// Hauptinhalt der Karte, z. B. MeinListenEintrag oder ein ListTile
  final Widget child;

  /// Optionaler Inhalt am rechten Rand (Dropdown, Badge, Punkte, ...)
  final Widget? trailing;

  final bool istSelektiert;
  final bool istAusgewertet;

  /// Falls gesetzt, ist die gesamte Karte antippbar (z. B. zum Selektieren)
  final VoidCallback? onTap;

  // Farben sind überschreibbar, fallen sonst auf Theme-Werte zurück,
  // damit alle Widgets automatisch dieselbe Optik bekommen.
  final Color? selektiertFarbe;
  final Color? ausgewertetFarbe;
  final Color? standardFarbe;

  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const MeinKartenEintrag({
    super.key,
    required this.child,
    this.trailing,
    this.istSelektiert = false,
    this.istAusgewertet = false,
    this.onTap,
    this.selektiertFarbe,
    this.ausgewertetFarbe,
    this.standardFarbe,
    this.margin = const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
    this.padding = const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final farbe = istAusgewertet
        ? (ausgewertetFarbe ?? theme.disabledColor.withValues(alpha: 0.15))
        : istSelektiert
            ? (selektiertFarbe ?? theme.colorScheme.primary.withValues(alpha: 0.15))
            : (standardFarbe ?? theme.cardColor);

    final inhalt = Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: child),
          if (trailing != null) Expanded(flex: 1, child: trailing!),
        ],
      ),
    );

    return Card(
      color: farbe,
      margin: margin,
      clipBehavior: Clip.antiAlias, // sauberer InkWell-Ripple innerhalb der Card
      child: onTap != null ? InkWell(onTap: onTap, child: inhalt) : inhalt,
    );
  }
}