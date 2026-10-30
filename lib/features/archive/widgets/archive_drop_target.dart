import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Drag-and-drop over the archive list.
///
/// `desktop_drop` covers web and desktop only: on iOS and Android the
/// widget disappears and the child is returned untouched. The dropped
/// bytes go through exactly the same path as the upload sheet, so
/// `ImagePipeline` and `document-ingest` validate type, size and magic
/// bytes in both cases.
class ArchiveDropTarget extends StatefulWidget {
  const ArchiveDropTarget({super.key, required this.child, required this.onFiles});

  final Widget child;
  final ValueChanged<List<DroppedFile>> onFiles;

  /// True only where the package has a platform implementation.
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  State<ArchiveDropTarget> createState() => _ArchiveDropTargetState();
}

class _ArchiveDropTargetState extends State<ArchiveDropTarget> {
  bool _hovering = false;

  Future<void> _onDone(DropDoneDetails details) async {
    setState(() => _hovering = false);
    final List<DroppedFile> files = <DroppedFile>[];
    for (final DropItem item in details.files) {
      final Uint8List bytes = await item.readAsBytes();
      files.add(DroppedFile(name: item.name, bytes: bytes));
    }
    if (files.isNotEmpty) widget.onFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    if (!ArchiveDropTarget.isSupported) return widget.child;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: _onDone,
      child: Stack(children: <Widget>[
        widget.child,
        if (_hovering)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                child: Center(
                  child: Text(context.l10n.t('archiveDropActive'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
