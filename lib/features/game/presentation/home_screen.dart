import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../../../app/theme.dart';
import '../application/game_cubit.dart';
import '../domain/game_modes.dart';
import 'game_screen.dart';

class BlockoraHomeScreen extends StatelessWidget {
  const BlockoraHomeScreen({super.key, required this.cubit});

  final GameCubit cubit;

  Future<void> _startClassic(BuildContext context) async {
    await cubit.startClassic();
    if (!context.mounted) return;
    await _openGame(context);
  }

  Future<void> _openGame(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: GameScreen(onExit: () => Navigator.pop(context)),
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
                const Positioned.fill(child: _HomeDecor()),
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
                                compact ? 12 : 18,
                                18,
                                24,
                              ),
                              child: Column(
                                children: [
                                  _TopGameBar(
                                    onHome: () {},
                                    onSound: () {},
                                  ),
                                  SizedBox(height: compact ? 12 : 18),
                                  const _BlockoraLogo(),
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
                                            48,
                                            18,
                                            20,
                                          ),
                                          child: Column(
                                            children: [
                                              const _ThreeStars(),
                                              const SizedBox(height: 8),
                                              const _MiniPuzzleBoard(),
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CartoonScoreCard(
                                                    label: 'BEST',
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
                                              const SizedBox(height: 18),
                                              if (canResume) ...[
                                                GlossyGameButton(
                                                  label:
                                                      'CONTINUE  ${state.score}',
                                                  icon: Icons
                                                      .restore_rounded,
                                                  green: false,
                                                  onTap: () =>
                                                      _openGame(context),
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                              GlossyGameButton(
                                                label: 'PLAY',
                                                icon:
                                                    Icons.play_arrow_rounded,
                                                onTap: () =>
                                                    _startClassic(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const CartoonRibbon(
                                        text: 'CLASSIC MODE',
                                        icon: Icons.star_rounded,
                                        width: 270,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const _BottomHints(),
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

class _TopGameBar extends StatelessWidget {
  const _TopGameBar({required this.onHome, required this.onSound});

  final VoidCallback onHome;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      RoundGameButton(
        icon: Icons.home_rounded,
        onTap: onHome,
        tooltip: 'Home',
      ),
      const SizedBox(width: 10),
      RoundGameButton(
        icon: Icons.music_note_rounded,
        onTap: onSound,
        tooltip: 'Sound',
      ),
      const SizedBox(width: 10),
      RoundGameButton(
        icon: Icons.emoji_events_rounded,
        onTap: () {},
        tooltip: 'Best score',
      ),
    ],
  );
}

class _BlockoraLogo extends StatelessWidget {
  const _BlockoraLogo();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    );
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(0, 5),
          child: const Text(
            'BLOCKORA',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Color(0xff70422f),
            ),
          ),
        ),
        const Text(
          'BLOCKORA',
          style: TextStyle(
            color: Colors.white,
            shadows: [
              Shadow(color: Color(0xffee3f8f), blurRadius: 2),
              Shadow(color: Color(0x55000000), blurRadius: 6),
            ],
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const Positioned(
          top: -8,
          right: 20,
          child: Icon(
            Icons.star_rounded,
            color: CartoonColors.yellow,
            size: 28,
          ),
        ),
        const Positioned(
          left: 14,
          bottom: -7,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: PrismColors.cyan,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _ThreeStars extends StatelessWidget {
  const _ThreeStars();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 37),
      SizedBox(width: 2),
      Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 49),
      SizedBox(width: 2),
      Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 37),
    ],
  );
}

class _MiniPuzzleBoard extends StatelessWidget {
  const _MiniPuzzleBoard();

  @override
  Widget build(BuildContext context) {
    const filled = <int, Color>{
      1: Color(0xffef5752),
      2: Color(0xffef5752),
      8: Color(0xff56b6ee),
      9: Color(0xff56b6ee),
      10: Color(0xff56b6ee),
      16: Color(0xff9bd528),
      22: Color(0xffffc842),
      23: Color(0xffffc842),
      29: Color(0xffaa74da),
      30: Color(0xffaa74da),
      31: Color(0xffaa74da),
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
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
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
                      : Colors.white.withValues(alpha: .38),
                ),
                boxShadow: color == null
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .15),
                          blurRadius: 2,
                          offset: const Offset(0, 3),
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

class _BottomHints extends StatelessWidget {
  const _BottomHints();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _HintChip(icon: Icons.timer_off_rounded, text: 'NO TIMER'),
      const SizedBox(width: 8),
      _HintChip(icon: Icons.favorite_rounded, text: 'REVIVE'),
      const SizedBox(width: 8),
      _HintChip(icon: Icons.wifi_off_rounded, text: 'OFFLINE'),
    ],
  );
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .30),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    ),
  );
}

class _HomeDecor extends StatelessWidget {
  const _HomeDecor();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          top: 100,
          left: -22,
          child: Transform.rotate(
            angle: -.15,
            child: const _DecorBlock(color: Color(0xff56b6ee), size: 64),
          ),
        ),
        Positioned(
          top: 180,
          right: -18,
          child: Transform.rotate(
            angle: .16,
            child: const _DecorBlock(color: Color(0xff9bd528), size: 58),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -12,
          child: Transform.rotate(
            angle: .12,
            child: const _DecorBlock(color: Color(0xffffc842), size: 54),
          ),
        ),
        Positioned(
          bottom: 70,
          right: 10,
          child: Transform.rotate(
            angle: -.12,
            child: const _DecorBlock(color: Color(0xffef5752), size: 46),
          ),
        ),
      ],
    ),
  );
}

class _DecorBlock extends StatelessWidget {
  const _DecorBlock({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(size * .25),
      border: Border.all(color: Colors.white.withValues(alpha: .35), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 6,
          offset: Offset(4, 6),
        ),
      ],
    ),
  );
}
