import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme.dart';

/// The seven editable SVG tiles are decoded once, then reused by all painters.
/// This app-lifetime cache avoids SVG widgets or decoding inside the game loop.
class BlockSkin extends ChangeNotifier {
  BlockSkin._();

  static final instance = BlockSkin._();
  static const names = [
    'cyan',
    'pink',
    'gold',
    'blue',
    'mint',
    'peach',
    'lilac',
  ];
  final _pictures = <int, PictureInfo>{};
  Future<void>? _loading;

  Future<void> preload() => _loading ??= _load();

  Future<void> _load() async {
    await Future.wait([
      for (var index = 0; index < names.length; index++) _loadTile(index),
    ]);
    notifyListeners();
  }

  Future<void> _loadTile(int index) async {
    try {
      _pictures[index] = await vg.loadPicture(
        SvgAssetLoader('assets/blocks/${names[index]}.svg'),
        null,
      );
    } catch (error) {
      debugPrint('Block skin ${names[index]}: $error');
    }
  }

  void paint(Canvas canvas, Rect rect, int index, {double opacity = 1}) {
    final colorIndex = index % names.length;
    final picture = _pictures[colorIndex];
    canvas.save();
    if (opacity < 1) {
      canvas.saveLayer(
        rect,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    if (picture != null) {
      canvas.translate(rect.left, rect.top);
      canvas.scale(
        rect.width / picture.size.width,
        rect.height / picture.size.height,
      );
      canvas.drawPicture(picture.picture);
    } else {
      // Immediate first-frame rendering while the local SVGs are decoding.
      final color = PrismColors.blockColors[colorIndex];
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, .4)!, color],
          ).createShader(rect),
      );
      final face = rect.deflate(rect.width * .13);
      final bevels = [
        [rect.topLeft, rect.topRight, face.topRight, face.topLeft],
        [rect.topLeft, face.topLeft, face.bottomLeft, rect.bottomLeft],
        [rect.topRight, rect.bottomRight, face.bottomRight, face.topRight],
        [rect.bottomLeft, face.bottomLeft, face.bottomRight, rect.bottomRight],
      ];
      final shades = [
        Colors.white.withValues(alpha: .5),
        Colors.white.withValues(alpha: .25),
        Colors.black.withValues(alpha: .22),
        Colors.black.withValues(alpha: .4),
      ];
      for (var side = 0; side < bevels.length; side++) {
        canvas.drawPath(
          Path()..addPolygon(bevels[side], true),
          Paint()..color = shades[side],
        );
      }
    }
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }
}
