import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'logger.util.dart';
import 'station_repository.dart';

class PdfModal extends StatefulWidget {
  final String stationsName;
  const PdfModal({super.key, required this.stationsName});

  @override
  PdfModalState createState() => PdfModalState();
}

class PdfModalState extends State<PdfModal> {
  final log = getLogger();
  final StationRepository stationRepository = StationRepository();
  String? pdfUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfUrl(widget.stationsName);
  }

  Future<void> _loadPdfUrl(String stationsName) async {
    try {
      final station = await stationRepository.ladeStationNachName(
        stationsName: stationsName,
      );

      if (station == null || station.beschreibungUrl == null) {
        throw Exception('Keine PDF-Beschreibung für $stationsName gefunden.');
      }

      if (!mounted) return;
      setState(() {
        pdfUrl = station.beschreibungUrl;
        isLoading = false;
      });
    } catch (e) {
      log.e('Fehler beim Laden der PDF-URL: $e');
      if (!mounted) return;
      _showErrorDialog('Fehler', 'PDF konnte nicht geladen werden.');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Zeigt einen Fehlerdialog an
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfIframe(String url) {
    final viewId = 'pdf-view-${url.hashCode}';
    // Diese Methode funktioniert nur, wenn der PDF-Viewer im Browser die #toolbar=0-Syntax unterstützt.
    // Bei PDFs von Back4App (Parse File URL) wird der Browser-eigene Viewer verwendet – 
    // Chrome unterstützt diese Parameter, Safari z. T. nicht.
    final cleanedUrl = '$url#toolbar=0&navpanes=0&scrollbar=0';

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final iframe = web.HTMLIFrameElement()
        // ..src = url
        // Menü-Leiste ausblenden - Chrome unterstützt diese Parameter, Safari z. T. nicht.
        ..src = cleanedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
    // return HtmlElementView(viewType: viewId);
    return HtmlElementView(viewType: viewId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('PDF: ${widget.stationsName}'),
          IconButton(
            icon: const Icon(Icons.close, size: 28, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Stack(
          children: [
            // PDF-Anzeige oder Ladeanzeige
            Positioned.fill(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : pdfUrl != null
                      ? _buildPdfIframe(pdfUrl!)
                      : const Center(
                          child: Text('PDF konnte nicht geladen werden')),
            ),
          ],
        ),
      ),
    );
  }
}