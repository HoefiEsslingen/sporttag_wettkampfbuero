import 'package:flutter/material.dart';
import 'package:sporttag/src/klassen/kind_klasse.dart';

class TeilnehmerVerschiebbar extends StatefulWidget {
  final List<Kind> teilNehmer;
  final Map<Kind, int> kindMitWerten;
  final bool isRunning;
  final int modus;
  final void Function(Kind kind, int value) onValueChanged;

  const TeilnehmerVerschiebbar({
    super.key,
    required this.teilNehmer,
    required this.kindMitWerten,
    required this.isRunning,
    // modus: 0 = Timer, 1 = StoppUhr, 2 = RundenModus
    required this.modus,
    required this.onValueChanged,
  });

  @override
  State<TeilnehmerVerschiebbar> createState() => _TeilnehmerVerschiebbarState();
}

class _TeilnehmerVerschiebbarState extends State<TeilnehmerVerschiebbar> {
  late List<Kind> _teilnehmer;
  final Map<Kind, int> _rundenMap = {};

  @override
  void initState() {
    super.initState();
    _teilnehmer = List.from(widget.teilNehmer);
    for (final kind in _teilnehmer) {
      _rundenMap[kind] = widget.kindMitWerten[kind] ?? 1;
    }
  }

  void _increment(Kind kind) {
    if (!widget.isRunning) return;
    setState(() {
      _rundenMap[kind] = _rundenMap[kind]! + 1;
      widget.onValueChanged(kind, _rundenMap[kind]!);
    });
  }

  void _decrement(Kind kind) {
    if (!widget.isRunning) return;
    if ((_rundenMap[kind] ?? 1) > 1) {
      setState(() {
        _rundenMap[kind] = _rundenMap[kind]! - 1;
        widget.onValueChanged(kind, _rundenMap[kind]!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      itemCount: _teilnehmer.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final Kind movedKind = _teilnehmer.removeAt(oldIndex);
          _teilnehmer.insert(newIndex, movedKind);
        });
      },
      itemBuilder: (context, index) {
        final kind = _teilnehmer[index];
        final wert = widget.kindMitWerten[kind];

      return Container(
          key: ValueKey(kind),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Name
              Expanded(
                flex: 3,
                child: Text(
                  '${kind.vorname} ${kind.nachname}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              // Mittelbereich: Button oder Rundensteuerung
              Expanded(
                flex: 4,
                child: Center(
                  child: widget.modus == 2
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: widget.isRunning
                                  ? () => _decrement(kind)
                                  : null,
                            ),
                            Text(
                              '${_rundenMap[kind] ?? 1}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: widget.isRunning
                                  ? () => _increment(kind)
                                  : null,
                            ),
                          ],
                        )
                      : wert != null
                          ? const Icon(Icons.check, color: Colors.green)
                          : widget.isRunning
                              ? ElevatedButton(
                                  onPressed: () =>
                                      widget.onValueChanged(kind, 0),
                                  child: Text(kind.vorname),
                                )
                              : const SizedBox.shrink(),
                ),
              ),
              // Reorder Icon ganz rechts
              const Icon(Icons.drag_handle),
            ],
          ),
        );

/*********************************************************************
 * auskommentiert für eine andere Positionierung der Icons
        return ListTile(
          key: ValueKey(kind),
          title: Text('${kind.vorname} ${kind.nachname}'),
          subtitle: widget.modus == 2
              ? null
              : wert != null
                  ? Text(
                      'Gestoppte Zeit: ${(wert / 1000).toStringAsFixed(1)} Sekunden')
                  : null,
          trailing: widget.modus == 2
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed:
                          widget.isRunning ? () => _decrement(kind) : null,
                    ),
                    Text(
                      '${_rundenMap[kind] ?? 1}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed:
                          widget.isRunning ? () => _increment(kind) : null,
                    ),
                  ],
                )
              : wert != null
                  ? const Icon(Icons.check, color: Colors.green)
                  : widget.isRunning
                      ? ElevatedButton(
                          onPressed: () => widget.onValueChanged(kind, 0),
                          child: Text(kind.vorname),
                        )
                      : null,
        );
*********************************************************************/
      },
    );
  }
}