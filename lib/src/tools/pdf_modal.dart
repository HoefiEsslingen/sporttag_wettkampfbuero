import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'logger.util.dart';

class PdfModal extends StatefulWidget {
  final String stationsName;

  const PdfModal({super.key, required this.stationsName});

  @override
  PdfModalState createState() => PdfModalState();
}

class PdfModalState extends State<PdfModal> {
  final log = getLogger();
  String? pdfUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfUrl(widget.stationsName);
  }

  /// Lädt die PDF-URL aus der Back4App-Datenbank
  Future<void> _loadPdfUrl(String stationsName) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://parseapi.back4app.com/classes/Station?where=${Uri.encodeComponent(jsonEncode({
            "StationsName": stationsName
          }))}',
        ),
        headers: {
          'X-Parse-Application-Id': 'WLgenML3TwDSZ80DBWggNnJaNePhJ3RQgzdCvvv0',
          'X-Parse-REST-API-Key': 'J2d7lGWvOXMpyMe5NzOhWpmON7uheSNwQFxnHv5B',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final results = jsonResponse['results'] as List?;
        if (results != null && results.isNotEmpty) {
          setState(() {
            pdfUrl = results.first['Beschreibung']?['url'];
            isLoading = false;
          });
        } else {
          throw Exception('Keine Ergebnisse für $stationsName gefunden.');
        }
      } else {
        throw Exception('Fehler beim Abrufen der Daten: ${response.statusCode}');
      }
    } catch (e) {
      log.e('Fehler beim Laden der PDF-URL: $e');
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kopfzeile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PDF: ${widget.stationsName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black,),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          // Inhalt: Ladeanzeige oder PDF-Anzeige
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : pdfUrl != null
                    ? SfPdfViewer.network(
                        pdfUrl!,
                        onDocumentLoaded: (details) {
                          log.i('PDF geladen: Seitenanzahl: ${details.document.pages.count}');
                        },
                        onDocumentLoadFailed: (details) {
                          log.e('Fehler beim Laden des PDFs: ${details.error}');
                          _showErrorDialog(details.error, details.description);
                        },
                      )
                    : const Center(child: Text('PDF konnte nicht geladen werden')),
          ),
        ],
      ),
    );
  }
}
