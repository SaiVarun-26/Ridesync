import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns a rendered ride card into a PNG and opens the system share sheet
/// with it.
///
/// The image is written to its own folder in the app's temporary directory,
/// which is emptied before each share, so old cards never pile up.
abstract final class RideCardSharer {
  static const String _folder = 'ride_cards';

  /// Shares the card painted by [boundary] for ride [code]. Returns whether
  /// the share sheet opened; throws if the image could not be made.
  static Future<bool> share({
    required RenderRepaintBoundary boundary,
    required String code,
    required double pixelRatio,
    String? text,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? bytes;
    try {
      bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
    if (bytes == null) throw StateError('The ride card could not be drawn.');

    final base = await getTemporaryDirectory();
    final folder = Directory('${base.path}${Platform.pathSeparator}$_folder');
    if (folder.existsSync()) await folder.delete(recursive: true);
    await folder.create(recursive: true);
    final safeCode = code.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final file = File(
      '${folder.path}${Platform.pathSeparator}ridesync_$safeCode.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }
}
