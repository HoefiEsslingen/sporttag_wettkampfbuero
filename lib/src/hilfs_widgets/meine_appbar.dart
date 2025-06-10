// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';

import 'hilfe_button.dart';

class MeineAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titel;
  final String? stationsName;

  MeineAppBar({super.key, required this.titel, this.stationsName});
  TextStyle style = const TextStyle(fontWeight: FontWeight.bold);

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
              HelpIconButton(stationsName: stationsName!), // Action nur, wenn stationsName != null
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
