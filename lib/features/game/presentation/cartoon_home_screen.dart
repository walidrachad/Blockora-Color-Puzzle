import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../application/game_cubit.dart';
import '../domain/game_modes.dart';
import 'cartoon_game_shell.dart';

class CartoonHomeScreen extends StatelessWidget {
  const CartoonHomeScreen({super.key, required this.cubit});

  final GameCubit cubit;

  Future<void> _openGame(BuildContext context, {required bool fresh}) async {
    if (fresh) await cubit.startClassic();
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CartoonGameShell(
          cubit: cubit,
          onExit: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _showBestScore(BuildContext context, int best) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .42),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 34),
              child: CartoonPanel(
                padding: const EdgeInsets.fromLTRB(22, 50, 22, 22),
                radius: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xffffe46a), CartoonColors.orange],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .7),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 43,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: CartoonColors.paperWarm,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xffe5b77f),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'YOUR BEST',
                            style: TextStyle(
                              color: CartoonColors.textSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$best',
                            style: const TextStyle(
                              color: CartoonColors.text,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlossyGameButton(
                      label: 'CLOSE',
                      icon: Icons.check_rounded,
                      onTap: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
            ),
            const CartoonRibbon(
              text: 'BEST SCORE',
              icon: Icons.star_rounded,
              width: 250,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: cubit,
    child: BlocBuilder<GameCubit, GameState>(
      builder: (context, state) {
        final canResume =
            state.hasSavedSession && state.session.mode == GameMode.classic;
        final best = state.progress.classic.bestScore;

        return Scaffold(
          body: DecoratedBox(
            decoration: cartoonBackground(),
            child: Stack(
              children: [
                const Positioned.fill(child: _FloatingBlocks()),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(constraints.maxWidth, 600.0);
                      final compact = constraints.maxHeight < 720;
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Center(
                          child: SizedBox(
                            width: width,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                18,
                                compact ? 10 : 16,
                                18,
                                24,
                              ),
                              child: Column(
                                children: [
                                  _CornerMenu(
                                    musicEnabled: state.preferences.music,
                                    onToggleMusic: () => cubit.updatePreferences(
                                      state.preferences.copyWith(
                                        music: !state.preferences.music,
                                      ),
                                    ),
                                    onShowBestScore: () =>
                                        _showBestScore(context, best),
                                  ),
                                  SizedBox(height: compact ? 10 : 16),
                                  const _Logo(),
                                  SizedBox(height: compact ? 8 : 14),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 34),
                                        child: CartoonPanel(
                                          padding: const EdgeInsets.fromLTRB(
                                            18,
                                            46,
                                            18,
                                            20,
                                          ),
                                          child: Column(
                                            children: [
                                              const _Stars(),
                                              const SizedBox(height: 8),
                                              const _BoardPreview(),
                                              const SizedBox(height: 14),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CartoonScoreCard(
                                                    label: 'BEST SCORE',
                                                    value: '$best',
                                                    icon: Icons
                                                        .emoji_events_rounded,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  const CartoonScoreCard(
                                                    label: 'MODE',
                                                    value: '∞',
                                                    icon: Icons
                                                        .all_inclusive_rounded,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              if (canResume) ...[
                                                GlossyGameButton(
                                                  label:
                                                      'CONTINUE  ${state.score}',
                                                  icon: Icons
                                                      .restore_rounded,
                                                  green: false,
                                                  onTap: () => _openGame(
                                                    context,
                                                    fresh: false,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                              GlossyGameButton(
                                                label: 'PLAY',
                                                icon:
                                                    Icons.play_arrow_rounded,
                                                onTap: () => _openGame(
                                                  context,
                                                  fresh: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const CartoonRibbon(
                                        text: 'CLASSIC MODE',
                                        icon: Icons.star_rounded,
                                        width: 280,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _Badge(
                                        icon: Icons.timer_off_rounded,
                                        text: 'NO TIMER',
                                      ),
                                      SizedBox(width: 8),
                                      _Badge(
                                        icon: Icons.favorite_rounded,
                                        text: 'REVIVE',
                                      ),
                                      SizedBox(width: 8),
                                      _Badge(
                                        icon: Icons.wifi_off_rounded,
                                        text: 'OFFLINE',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _CornerMenu extends StatelessWidget {
  const _CornerMenu({
    required this.musicEnabled,
    required this.onToggleMusic,
    required this.onShowBestScore,
  });

  final bool musicEnabled;
  final VoidCallback onToggleMusic;
  final VoidCallback onShowBestScore;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      RoundGameButton(
        icon: musicEnabled
            ? Icons.music_note_rounded
            : Icons.music_off_rounded,
        onTap: onToggleMusic,
        tooltip: musicEnabled ? 'Turn music off' : 'Turn music on',
        showShadow: false,
      ),
      const SizedBox(width: 9),
      RoundGameButton(
        icon: Icons.emoji_events_rounded,
        onTap: onShowBestScore,
        tooltip: 'Best score',
        showShadow: false,
      ),
    ],
  );
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Transform.translate(
        offset: const Offset(0, 5),
        child: const Text(
          'BLOCKORA',
          style: TextStyle(
            color: Color(0xff70422f),
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      const Text(
        'BLOCKORA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          shadows: [
            Shadow(color: CartoonColors.ribbon, blurRadius: 2),
            Shadow(color: Color(0x55000000), blurRadius: 5),
          ],
        ),
      ),
      const Positioned(
        right: 18,
        top: -7,
        child: Icon(
          Icons.star_rounded,
          color: CartoonColors.yellow,
          size: 28,
        ),
      ),
    ],
  );
}

class _Stars extends StatelessWidget {
  const _Stars();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 36),
      Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 48),
      Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 36),
    ],
  );
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview();

  @override
  Widget build(BuildContext context) {
    const filled = <int, Color>{
      1: Color(0xffef5752),
      2: Color(0xffef5752),
      8: Color(0xff54c8ed),
      9: Color(0xff54c8ed),
      10: Color(0xff54c8ed),
      16: Color(0xff9bd528),
      22: Color(0xffffd43e),
      23: Color(0xffffd43e),
      29: Color(0xff9d76d8),
      30: Color(0xff9d76d8),
      31: Color(0xff9d76d8),
      35: Color(0xff58cfa2),
      36: Color(0xff58cfa2),
      37: Color(0xff58cfa2),
      38: Color(0xff58cfa2),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CartoonColors.paperWarm,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffedc99c), width: 2),
      ),
      child: AspectRatio(
        aspectRatio: 1.55,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
          ),
          itemBuilder: (context, index) {
            final color = filled[index];
            return Container(
              decoration: BoxDecoration(
                color: color ?? const Color(0xffffddb2),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: color == null
                      ? const Color(0xffedc38f)
                      : Colors.white.withValues(alpha: .45),
                ),
                boxShadow: color == null
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 2,
                          offset: Offset(0, 3),
                        ),
                      ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .30),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _FloatingBlocks extends StatelessWidget {
  const _FloatingBlocks();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: const [
        Positioned(
          left: -18,
          top: 110,
          child: _ToyBlock(color: Color(0xff54c8ed), angle: -.16),
        ),
        Positioned(
          right: -16,
          top: 190,
          child: _ToyBlock(color: Color(0xff9bd528), angle: .15),
        ),
        Positioned(
          left: -8,
          bottom: 100,
          child: _ToyBlock(color: Color(0xffffd43e), angle: .12),
        ),
        Positioned(
          right: 14,
          bottom: 62,
          child: _ToyBlock(color: Color(0xffef5752), angle: -.12),
        ),
      ],
    ),
  );
}

class _ToyBlock extends StatelessWidget {
  const _ToyBlock({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .42), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(4, 6),
          ),
        ],
      ),
    ),
  );
}
