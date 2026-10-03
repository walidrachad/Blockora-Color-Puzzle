import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/cartoon_ui.dart';
import 'app/theme.dart';
import 'app/localization.dart';
import 'core/ads/ads_bootstrap.dart';
import 'core/ads/consent.dart';
import 'core/audio/game_audio_service.dart';
import 'core/frame_stats_probe.dart';
import 'core/game_feel_config.dart';
import 'core/services/services.dart';
import 'features/game/application/game_cubit.dart';
import 'features/game/presentation/cartoon_game_shell.dart';
import 'features/game/presentation/cartoon_home_screen.dart';
import 'features/game/presentation/combo_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStatsProbe.install();
  final preferences = await SharedPreferences.getInstance();
  final storage = SharedPreferencesStorage(preferences);
  final consent = GoogleConsentService();
  final ads = GoogleAdsService(consent: consent);
  final audio = LocalGameAudioService();
  final gameCubit = GameCubit(storage: storage, ads: ads, audio: audio);
  await gameCubit.initialize();
  unawaited(audio.preload());
  unawaited(ComboLottieCache.preload());
  runApp(PrismPopApp(gameCubit: gameCubit));
  unawaited(
    AdvertisingBootstrap(ads: ads, consent: consent).start().then((startup) {
      return gameCubit.applyAdsConfiguration(
        startup.config,
        canRequestAds: startup.consent.canRequestAds,
      );
    }),
  );
}

class PrismPopApp extends StatelessWidget {
  const PrismPopApp({super.key, required this.gameCubit});

  final GameCubit gameCubit;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Blockora',
    debugShowCheckedModeBanner: false,
    theme: prismTheme(),
    localizationsDelegates: const [PrismLocalizationsDelegate()],
    supportedLocales: const [Locale('en')],
    home: _SplashGate(gameCubit: gameCubit),
  );
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.gameCubit});

  final GameCubit gameCubit;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GameFeelConfig.splashEntrance,
    )..forward();
    _timer = Timer(GameFeelConfig.splashHold, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return CartoonHomeScreen(cubit: widget.gameCubit);
    return Scaffold(
      body: DecoratedBox(
        decoration: cartoonBackground(),
        child: Stack(
          children: [
            const Positioned(
              left: -20,
              top: 120,
              child: _SplashBlock(color: Color(0xff54c8ed), angle: -.18),
            ),
            const Positioned(
              right: -12,
              top: 220,
              child: _SplashBlock(color: Color(0xff9bd528), angle: .15),
            ),
            const Positioned(
              left: 32,
              bottom: 110,
              child: _SplashBlock(color: Color(0xffffd43e), angle: .10),
            ),
            Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOut,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: .82, end: 1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 102,
                        height: 102,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xffb8e62d), Color(0xff68a40e)],
                          ),
                          borderRadius: BorderRadius.circular(31),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .65),
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 9,
                              offset: Offset(5, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'BLOCKORA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: Color(0xffef3f8f),
                              offset: Offset(0, 4),
                            ),
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 4,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const CartoonRibbon(
                        text: 'COLOR PUZZLE',
                        width: 230,
                      ),
                      const SizedBox(height: 22),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBlock extends StatelessWidget {
  const _SplashBlock({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .45), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 7,
            offset: Offset(5, 7),
          ),
        ],
      ),
    ),
  );
}

class GameScreenWithCubit extends StatelessWidget {
  const GameScreenWithCubit({super.key, required this.cubit, this.onExit});

  final GameCubit cubit;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => CartoonGameShell(
    cubit: cubit,
    onExit: onExit,
  );
}
