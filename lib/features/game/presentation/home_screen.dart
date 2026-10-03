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

  Future<void> _openClassic(BuildContext context) async {
    await cubit.startClassic();
    if (!context.mounted) return;
    await _openCurrentGame(context);
  }

  Future<void> _openCurrentGame(BuildContext context) async {
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
        final bestScore = state.progress.classic.bestScore;

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff0a1749),
                  Color(0xff1c1958),
                  Color(0xff421d68),
                  Color(0xff0a1035),
                ],
                stops: [0, .34, .68, 1],
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: -120,
                  right: -90,
                  child: _GlowOrb(
                    size: 300,
                    color: PrismColors.violet,
                    opacity: .15,
                  ),
                ),
                const Positioned(
                  top: 210,
                  left: -130,
                  child: _GlowOrb(
                    size: 290,
                    color: PrismColors.cyan,
                    opacity: .10,
                  ),
                ),
                const Positioned(
                  bottom: -150,
                  right: -110,
                  child: _GlowOrb(
                    size: 330,
                    color: PrismColors.pink,
                    opacity: .09,
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(constraints.maxWidth, 560.0);
                      final compact = constraints.maxHeight < 720;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Center(
                          child: SizedBox(
                            width: width,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                22,
                                compact ? 20 : 32,
                                22,
                                28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _TopBar(bestScore: bestScore),
                                  SizedBox(height: compact ? 30 : 44),
                                  const _HeroSection(),
                                  SizedBox(height: compact ? 26 : 38),
                                  if (canResume) ...[
                                    _ResumeRunCard(
                                      score: state.score,
                                      onTap: () => _openCurrentGame(context),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  _ClassicPlayCard(
                                    bestScore: bestScore,
                                    onTap: () => _openClassic(context),
                                  ),
                                  const SizedBox(height: 22),
                                  const _FeatureStrip(),
                                  const SizedBox(height: 24),
                                  const _FooterNote(),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.bestScore});

  final int bestScore;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PrismColors.cyan, PrismColors.violet],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
          boxShadow: [
            BoxShadow(
              color: PrismColors.cyan.withValues(alpha: .18),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(
          Icons.grid_view_rounded,
          color: PrismColors.midnight,
          size: 25,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BLOCKORA',
              style: TextStyle(
                color: PrismColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'COLOR PUZZLE',
              style: TextStyle(
                color: PrismColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: PrismColors.yellow,
              size: 17,
            ),
            const SizedBox(width: 7),
            Text(
              '$bestScore',
              style: const TextStyle(
                color: PrismColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: PrismColors.cyan.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: PrismColors.cyan.withValues(alpha: .18)),
        ),
        child: const Text(
          'ENDLESS PUZZLE · NO TIMER',
          style: TextStyle(
            color: PrismColors.cyan,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Think ahead.\nMake space.',
        style: TextStyle(
          color: PrismColors.ink,
          fontSize: 42,
          height: .98,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.4,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Place colorful shapes, clear complete lines, and keep the board alive as long as you can.',
        style: TextStyle(
          color: PrismColors.ink.withValues(alpha: .62),
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _ResumeRunCard extends StatefulWidget {
  const _ResumeRunCard({required this.score, required this.onTap});

  final int score;
  final VoidCallback onTap;

  @override
  State<_ResumeRunCard> createState() => _ResumeRunCardState();
}

class _ResumeRunCardState extends State<_ResumeRunCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .985 : 1,
    duration: const Duration(milliseconds: 90),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PrismColors.cyan.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: PrismColors.cyan,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue your run',
                        style: TextStyle(
                          color: PrismColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Current score · ${widget.score}',
                        style: const TextStyle(
                          color: PrismColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: PrismColors.ink,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ClassicPlayCard extends StatefulWidget {
  const _ClassicPlayCard({required this.bestScore, required this.onTap});

  final int bestScore;
  final VoidCallback onTap;

  @override
  State<_ClassicPlayCard> createState() => _ClassicPlayCardState();
}

class _ClassicPlayCardState extends State<_ClassicPlayCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(28));

    return Semantics(
      button: true,
      label: 'Play Classic mode',
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: const Duration(milliseconds: 95),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff65e5c0), Color(0xff25b994)],
              ),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: .26)),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.green.withValues(alpha: .24),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: .22),
                  blurRadius: 8,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              splashColor: Colors.white.withValues(alpha: .22),
              highlightColor: Colors.white.withValues(alpha: .08),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: PrismColors.midnight.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .20),
                        ),
                      ),
                      child: const Icon(
                        Icons.all_inclusive_rounded,
                        color: Colors.white,
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PLAY CLASSIC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.bestScore > 0
                                ? 'Best score ${widget.bestScore} · beat your record'
                                : 'Endless play · build your first record',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .065)),
    ),
    child: const Row(
      children: [
        Expanded(
          child: _MiniFeature(
            icon: Icons.timer_off_rounded,
            title: 'NO TIMER',
          ),
        ),
        _TinyDivider(),
        Expanded(
          child: _MiniFeature(
            icon: Icons.wifi_off_rounded,
            title: 'OFFLINE',
          ),
        ),
        _TinyDivider(),
        Expanded(
          child: _MiniFeature(
            icon: Icons.favorite_rounded,
            title: 'REVIVE',
          ),
        ),
      ],
    ),
  );
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 15, color: PrismColors.muted),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: PrismColors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ),
    ],
  );
}

class _TinyDivider extends StatelessWidget {
  const _TinyDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    color: Colors.white.withValues(alpha: .07),
  );
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) => Text(
    'Drag shapes onto the board · complete rows and columns · keep going.',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: PrismColors.muted.withValues(alpha: .72),
      fontSize: 10,
      height: 1.4,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    ),
  );
}
