import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff101d5f),
                  Color(0xff28165f),
                  Color(0xff0b1035),
                ],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: _ArcadeBackdrop()),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = math.min(constraints.maxWidth, 560.0);
                      final compact = constraints.maxHeight < 720;

                      return Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: contentWidth,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                compact ? 14 : 22,
                                20,
                                24,
                              ),
                              child: Column(
                                children: [
                                  _HudBar(best: best),
                                  SizedBox(height: compact ? 16 : 24),
                                  const _GameLogo(),
                                  SizedBox(height: compact ? 14 : 22),
                                  const _PuzzlePreview(),
                                  SizedBox(height: compact ? 18 : 26),
                                  if (canResume) ...[
                                    _ResumeButton(
                                      score: state.score,
                                      onTap: () => _openGame(context),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _PlayButton(
                                    best: best,
                                    onTap: () => _startClassic(context),
                                  ),
                                  const SizedBox(height: 18),
                                  const _GameBadges(),
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

class _HudBar extends StatelessWidget {
  const _HudBar({required this.best});

  final int best;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff09123c).withValues(alpha: .75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: PrismColors.cyan, size: 17),
            SizedBox(width: 5),
            Text(
              'CLASSIC',
              style: TextStyle(
                color: PrismColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff553d86), Color(0xff2a2c70)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PrismColors.yellow.withValues(alpha: .35)),
          boxShadow: [
            BoxShadow(
              color: PrismColors.yellow.withValues(alpha: .12),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: PrismColors.yellow, size: 17),
            const SizedBox(width: 6),
            Text(
              '$best',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _GameLogo extends StatelessWidget {
  const _GameLogo();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned(
        top: 8,
        child: Text(
          'BLOCKORA',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: const Color(0xff09123c).withValues(alpha: .95),
          ),
        ),
      ),
      const Text(
        'BLOCKORA',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white,
          shadows: [
            Shadow(color: PrismColors.cyan, blurRadius: 10),
            Shadow(color: PrismColors.violet, blurRadius: 16),
          ],
        ),
      ),
      const Positioned(
        top: -8,
        right: 26,
        child: Icon(Icons.star_rounded,
            color: PrismColors.yellow, size: 24),
      ),
      const Positioned(
        bottom: -4,
        left: 34,
        child: Icon(Icons.auto_awesome_rounded,
            color: PrismColors.pink, size: 18),
      ),
    ],
  );
}

class _PuzzlePreview extends StatelessWidget {
  const _PuzzlePreview();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff0a1239).withValues(alpha: .82),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: .10)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .30),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: PrismColors.violet.withValues(alpha: .10),
          blurRadius: 30,
        ),
      ],
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MAKE SPACE',
              style: TextStyle(
                color: PrismColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              '∞',
              style: TextStyle(
                color: PrismColors.cyan,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1.75,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff08112f),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            padding: const EdgeInsets.all(12),
            child: const _MiniBoard(),
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          'Place shapes · complete lines · keep the board alive',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: PrismColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _MiniBoard extends StatelessWidget {
  const _MiniBoard();

  @override
  Widget build(BuildContext context) {
    const filled = <int, Color>{
      2: PrismColors.cyan,
      3: PrismColors.cyan,
      7: PrismColors.pink,
      8: PrismColors.pink,
      9: PrismColors.pink,
      14: PrismColors.yellow,
      19: PrismColors.green,
      20: PrismColors.green,
      25: PrismColors.violet,
      26: PrismColors.violet,
      27: PrismColors.violet,
      31: PrismColors.orange,
      32: PrismColors.orange,
      37: PrismColors.cyan,
      38: PrismColors.cyan,
      39: PrismColors.cyan,
      40: PrismColors.cyan,
    };

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final color = filled[index];
        return Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(5),
            boxShadow: color == null
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: .20),
                      blurRadius: 5,
                    ),
                  ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.best, required this.onTap});

  final int best;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .95 : 1,
    duration: const Duration(milliseconds: 90),
    curve: Curves.easeOut,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        height: 82,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffffd45d), Color(0xffff8a4f)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .38)),
          boxShadow: [
            BoxShadow(
              color: PrismColors.orange.withValues(alpha: .38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 6,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          splashColor: Colors.white.withValues(alpha: .25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xff6c2b24),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAY NOW',
                        style: TextStyle(
                          color: Color(0xff512124),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.best > 0
                            ? 'Beat your best: ${widget.best}'
                            : 'Start your first run',
                        style: TextStyle(
                          color: const Color(0xff512124).withValues(alpha: .72),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xff512124),
                  size: 34,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResumeButton extends StatefulWidget {
  const _ResumeButton({required this.score, required this.onTap});

  final int score;
  final VoidCallback onTap;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .97 : 1,
    duration: const Duration(milliseconds: 90),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff6f58c9), Color(0xff433a9a)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
              color: PrismColors.violet.withValues(alpha: .20),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.restore_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'CONTINUE RUN  ·  ${widget.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 21),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GameBadges extends StatelessWidget {
  const _GameBadges();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(
        child: _GameBadge(
          icon: Icons.timer_off_rounded,
          text: 'NO TIMER',
          color: PrismColors.cyan,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: _GameBadge(
          icon: Icons.favorite_rounded,
          text: 'REVIVE',
          color: PrismColors.pink,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: _GameBadge(
          icon: Icons.wifi_off_rounded,
          text: 'OFFLINE',
          color: PrismColors.green,
        ),
      ),
    ],
  );
}

class _GameBadge extends StatelessWidget {
  const _GameBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: const Color(0xff0b143f).withValues(alpha: .75),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 5),
        Text(
          text,
          style: const TextStyle(
            color: PrismColors.ink,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ],
    ),
  );
}

class _ArcadeBackdrop extends StatelessWidget {
  const _ArcadeBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: const [
        Positioned(top: 90, left: 24, child: _FloatingTile(color: PrismColors.cyan, angle: -.16)),
        Positioned(top: 160, right: 26, child: _FloatingTile(color: PrismColors.pink, angle: .18)),
        Positioned(bottom: 150, left: 28, child: _FloatingTile(color: PrismColors.yellow, angle: .12)),
        Positioned(bottom: 92, right: 34, child: _FloatingTile(color: PrismColors.green, angle: -.13)),
      ],
    ),
  );
}

class _FloatingTile extends StatelessWidget {
  const _FloatingTile({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .08), blurRadius: 16),
        ],
      ),
    ),
  );
}
