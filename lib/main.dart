import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/theme.dart';
import 'app/localization.dart';
import 'core/ads/ads_bootstrap.dart';
import 'core/ads/consent.dart';
import 'core/audio/game_audio_service.dart';
import 'core/frame_stats_probe.dart';
import 'core/game_feel_config.dart';
import 'core/services/services.dart';
import 'features/game/application/game_cubit.dart';
import 'features/game/presentation/combo_overlay.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/game/presentation/mode_screens.dart';

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
    if (_ready) return ModeSelectionScreen(cubit: widget.gameCubit);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff122b78), Color(0xff4c2174), Color(0xff0d123d)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [PrismColors.cyan, PrismColors.violet],
                    ),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: [
                      BoxShadow(
                        color: PrismColors.cyan.withValues(alpha: .32),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: PrismColors.midnight,
                    size: 43,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BLOCKORA',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find your next bright move',
                  style: TextStyle(color: PrismColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PrismColors.yellow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameScreenWithCubit extends StatelessWidget {
  const GameScreenWithCubit({super.key, required this.cubit, this.onExit});

  final GameCubit cubit;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: cubit,
    child: GameScreen(onExit: onExit),
  );
}
