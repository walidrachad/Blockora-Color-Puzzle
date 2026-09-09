import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../app/theme.dart';

class ComboAssets {
  static const all = <String>[
    'assets/lottie/combo_2.json',
    'assets/lottie/combo_3.json',
    'assets/lottie/combo_4.json',
    'assets/lottie/combo_5.json',
    'assets/lottie/combo_epic.json',
  ];

  static String forCombo(int combo) {
    if (combo <= 2) return all[0];
    if (combo == 3) return all[1];
    if (combo == 4) return all[2];
    if (combo == 5) return all[3];
    return all[4];
  }
}

class ComboLottieCache {
  static final Map<String, Future<LottieComposition?>> _cache = {};

  static Future<LottieComposition?> load(String asset) {
    return _cache.putIfAbsent(asset, () async {
      try {
        return await AssetLottie(asset, backgroundLoading: true).load();
      } catch (_) {
        return null;
      }
    });
  }

  static Future<void> preload() async {
    await Future.wait(ComboAssets.all.map(load));
  }
}

class ComboOverlay extends StatefulWidget {
  const ComboOverlay({super.key, required this.combo, required this.eventId});

  final int combo;
  final int eventId;

  @override
  State<ComboOverlay> createState() => _ComboOverlayState();
}

class _ComboOverlayState extends State<ComboOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<LottieComposition?> _composition;
  bool _visible = true;
  bool _started = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _visible = false);
      }
    });
    // The fallback must also finish if the asset bundle is slow or a platform
    // renderer cannot create a composition.
    _hideTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _visible = false);
    });
    _composition = ComboLottieCache.load(ComboAssets.forCombo(widget.combo));
  }

  void _start(LottieComposition? composition) {
    if (_started) return;
    _started = true;
    _controller.duration =
        composition?.duration ?? const Duration(milliseconds: 420);
    if (_controller.duration == Duration.zero) {
      _controller.duration = const Duration(milliseconds: 420);
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_controller.duration!, () {
      if (mounted) setState(() => _visible = false);
    });
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox.expand(
          child: Center(
            child: FutureBuilder<LottieComposition?>(
              future: _composition,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  _start(snapshot.data);
                }
                final text = Text(
                  'COMBO x${widget.combo}',
                  style: TextStyle(
                    color: PrismColors.yellow,
                    fontSize: reducedMotion ? 18 : 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: const [
                      Shadow(color: PrismColors.orange, blurRadius: 14),
                    ],
                  ),
                );
                if (reducedMotion || snapshot.data == null) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Opacity(
                      opacity: 1 - _controller.value,
                      child: Transform.scale(
                        scale: .9 + _controller.value * .15,
                        child: child,
                      ),
                    ),
                    child: text,
                  );
                }
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Lottie(
                          composition: snapshot.data!,
                          controller: _controller,
                          animate: false,
                          repeat: false,
                          fit: BoxFit.contain,
                          renderCache: RenderCache.raster,
                        ),
                        child!,
                      ],
                    ),
                  ),
                  child: text,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
