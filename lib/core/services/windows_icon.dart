import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Turns the icon picked in PackFoundry into a Windows `.ico`.
///
/// Inno Setup and the Flutter runner resource both need an `.ico`, while
/// projects usually keep a large PNG. Windows Vista and later read PNG-encoded
/// icon entries, so the image is only resized, never converted to BMP.
class WindowsIcon {
  const WindowsIcon();

  static const sizes = [16, 24, 32, 48, 64, 128, 256];

  /// Writes an `.ico` made from [source] to [destination]. Returns false when
  /// the source cannot be used, e.g. an SVG that Flutter cannot decode.
  Future<bool> write({required File source, required File destination}) async {
    if (!source.existsSync()) {
      return false;
    }
    final lower = source.path.toLowerCase();
    if (lower.endsWith('.ico')) {
      await destination.parent.create(recursive: true);
      await source.copy(destination.path);
      return true;
    }
    if (lower.endsWith('.svg')) {
      return false;
    }

    final bytes = await source.readAsBytes();
    final entries = <Uint8List>[];
    for (final size in sizes) {
      final png = await _resizedPng(bytes, size);
      if (png != null) {
        entries.add(png);
      }
    }
    if (entries.isEmpty) {
      return false;
    }

    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(encode(entries));
    return true;
  }

  /// Packs PNG images into an ICO container; sizes are read from each PNG
  /// header.
  static Uint8List encode(List<Uint8List> pngImages) {
    final header = BytesBuilder();
    final data = BytesBuilder();
    final count = pngImages.length;
    header.add(_uint16(0));
    header.add(_uint16(1));
    header.add(_uint16(count));
    var offset = 6 + 16 * count;
    for (final png in pngImages) {
      final (width, height) = _pngSize(png);
      header.addByte(width >= 256 ? 0 : width);
      header.addByte(height >= 256 ? 0 : height);
      header.addByte(0);
      header.addByte(0);
      header.add(_uint16(1));
      header.add(_uint16(32));
      header.add(_uint32(png.length));
      header.add(_uint32(offset));
      offset += png.length;
      data.add(png);
    }
    return (header..add(data.takeBytes())).takeBytes();
  }

  Future<Uint8List?> _resizedPng(Uint8List bytes, int size) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size,
        targetHeight: size,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return data?.buffer.asUint8List();
    } on Object {
      return null;
    }
  }

  static (int, int) _pngSize(Uint8List png) {
    if (png.length < 24) {
      return (256, 256);
    }
    final view = ByteData.sublistView(png);
    return (view.getUint32(16), view.getUint32(20));
  }

  static Uint8List _uint16(int value) =>
      (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();

  static Uint8List _uint32(int value) =>
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
}
