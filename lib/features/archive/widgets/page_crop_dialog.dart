import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Manual crop of one page. No automatic edge detection: the user decides.
///
/// `crop_your_image` is pure Dart, so the same dialog runs on iOS, Android
/// and the web with no native configuration.
class PageCropDialog extends StatefulWidget {
  const PageCropDialog({super.key, required this.bytes});

  final Uint8List bytes;

  /// Returns the cropped bytes, or null when the user cancels.
  static Future<Uint8List?> show(BuildContext context, Uint8List bytes) =>
      showDialog<Uint8List>(
        context: context,
        builder: (_) => PageCropDialog(bytes: bytes),
      );

  @override
  State<PageCropDialog> createState() => _PageCropDialogState();
}

class _PageCropDialogState extends State<PageCropDialog> {
  final CropController _controller = CropController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: size.width > 900 ? 820 : size.width,
        height: size.height * 0.82,
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: <Widget>[
              Expanded(
                child: Text(context.l10n.t('archiveCropPage'),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: context.l10n.t('commonClose'),
                onPressed: _busy ? null : () => context.pop(),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          Expanded(
            child: Crop(
              image: widget.bytes,
              controller: _controller,
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              onCropped: (CropResult result) {
                if (!mounted) return;
                switch (result) {
                  case CropSuccess(croppedImage: final Uint8List cropped):
                    context.pop(cropped);
                  case CropFailure():
                    setState(() => _busy = false);
                }
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: Text(context.l10n.t('commonCancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _busy = true);
                          _controller.crop();
                        },
                  child: Text(context.l10n.t('archiveCropConfirm')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
