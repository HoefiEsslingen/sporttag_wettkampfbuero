import 'package:flutter/material.dart';
import '../tools/pdf_modal.dart';

class HelpIconButton extends StatelessWidget {
  final String stationsName;

  const HelpIconButton({super.key, required this.stationsName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline), // ?-Icon
      tooltip: 'Zeige Informationen',
      onPressed: () {
        // Öffnet das modale Fenster
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => PdfModal(stationsName: stationsName),
        );
      },
    );
  }
}
