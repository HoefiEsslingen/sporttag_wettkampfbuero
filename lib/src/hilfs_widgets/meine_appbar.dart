// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';

import 'hilfe_button.dart';

class MeineAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titel;
  final String? stationsName;
  final String? thema;

  MeineAppBar({super.key, required this.titel, this.stationsName, this.thema});
  TextStyle style = const TextStyle(fontWeight: FontWeight.bold);

HilfeThema hilfeThemaVonString(String? name) {
  switch (name) {
    case 'Sporttag - Anmeldung':
      return HilfeThema.anmeldung;
    case 'Riegen einteilen':
      return HilfeThema.riegeneinteilung;
    case 'Riegen Zuordnung':
      return HilfeThema.riegenzuordnung;
    case 'Urkunden':
      return HilfeThema.auswertung;
    default:
      return HilfeThema.unbekannt;
  }
}

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          titel,
          style: style,
        ),
      ),
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: stationsName != null
          ? [
              HelpIconButton(typ: HilfeTyp.pdf, titel: stationsName!), // Action nur, wenn stationsName != null
            ]
          : thema != null
              ? [
                  HelpIconButton(typ: HilfeTyp.text, thema: hilfeThemaVonString(thema)),
                ]
              : null, // Keine Actions, wenn stationsName null ist
    );
  }

  @override
  Size get preferredSize {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: titel, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final height = painter.height + 20; // Padding oben/unten einberechnen
    if (height > kToolbarHeight) {
      return Size.fromHeight(height);
    }else {
      return const Size.fromHeight(kToolbarHeight);
    }
  }

}
