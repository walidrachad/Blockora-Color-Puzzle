# Editable block skins

Edit the seven SVGs in this folder to change the block artwork everywhere:
tray pieces, dragged pieces, occupied board cells, and line-clear animations.
All 27 piece definitions are assembled from these tiles; the SVGs do not change
their occupied cells or hit targets.

The color order is cyan, pink, gold, blue, mint, peach, lilac. Each asset has a
100 × 100 viewBox. Keep that square viewBox and leave a small inset for the
rounded edge. Named `candy` and `icing` gradients control the body and shine;
the bottom rectangle is the soft extrusion/shadow. Colors and paths are
editable in a text editor, Figma, or Inkscape.

Use self-contained paths, gradients and presentation attributes; avoid linked
images, scripts, CSS, or SVG filters. Rendering uses flutter_svg:
https://pub.dev/packages/flutter_svg

After editing, fully restart the app: decoded pictures are cached for the app
lifetime so gameplay never parses SVGs on each frame. If an asset cannot load,
the painter displays a rounded fallback tile and logs the load failure.

Motion timing lives in `lib/core/game_feel_config.dart` and the turn listener
in `lib/features/game/presentation/game_screen.dart`. Line clears last 580 ms
for one line, up to 790 ms for four or more. System reduced-motion mode uses
a 120 ms fade with no particles or sweep.
