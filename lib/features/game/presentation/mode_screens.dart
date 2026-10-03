import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../application/game_cubit.dart';
import '../domain/game_modes.dart';
import '../domain/mode_catalog.dart';
import 'game_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key, required this.cubit});

  final GameCubit cubit;

  Future<void> _openGame(
    BuildContext context,
    Future<void> Function() start,
  ) async {
    await start();
    if (!context.mounted) return;
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
      builder: (context, state) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff122b78), Color(0xff4c2174), Color(0xff0d123d)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = math.min(constraints.maxWidth, 620.0);
                return SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 80),
                            const _BrandLockup(),
                            const SizedBox(height: 36),
                            const Text(
                              'Classic mode',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'The endless original. Build your best score.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: PrismColors.muted),
                            ),
                            const SizedBox(height: 26),
                            if (state.hasSavedSession &&
                                state.session.mode == GameMode.classic) ...[
                              _ResumeCard(
                                mode: state.session.mode,
                                onTap: () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => BlocProvider.value(
                                      value: cubit,
                                      child: GameScreen(
                                        onExit: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            _ModeCard(
                              icon: Icons.all_inclusive_rounded,
                              color: PrismColors.cyan,
                              gradient: const [
                                Color(0xff55dfbf),
                                Color(0xff0da87d),
                              ],
                              title: 'Classic',
                              description:
                                  'The endless original. Build your best score.',
                              detail: 'NO LIMIT · REVIVE AVAILABLE',
                              onTap: () =>
                                  _openGame(context, cubit.startClassic),
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
        ),
      ),
    ),
  );
}

class JourneyLevelSelectionScreen extends StatelessWidget {
  const JourneyLevelSelectionScreen({super.key, required this.cubit});

  final GameCubit cubit;

  Future<void> _openLevel(BuildContext context, JourneyLevel level) async {
    await cubit.startJourneyLevel(level);
    if (!context.mounted) return;
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
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 58,
          leading: Padding(
            padding: const EdgeInsets.all(6),
            child: _HeaderCloseButton(onTap: () => Navigator.of(context).pop()),
          ),
          title: const Text('Journey'),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff101f63), Color(0xff3b1e71), Color(0xff10123d)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = math.min(constraints.maxWidth, 760.0);
              final columns = constraints.maxWidth >= 600 ? 4 : 3;
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    itemCount: journeyLevels.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: .92,
                    ),
                    itemBuilder: (context, index) {
                      final level = journeyLevels[index];
                      final progress = state.progress.journey;
                      final unlocked = progress.isUnlocked(level);
                      final stars = progress.starsFor(level.id);
                      return _LevelCard(
                        level: level,
                        unlocked: unlocked,
                        stars: stars,
                        onTap: unlocked
                            ? () => _openLevel(context, level)
                            : null,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class DailyChallengeOverviewScreen extends StatelessWidget {
  const DailyChallengeOverviewScreen({super.key, required this.cubit});

  final GameCubit cubit;

  Future<void> _start(BuildContext context, DailyChallenge challenge) async {
    await cubit.startDailyChallenge(challenge);
    if (!context.mounted) return;
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
        final challenge = dailyChallengeFor(DateTime.now().toUtc());
        final progress = state.progress.daily;
        final completed = progress.isCompleted(challenge.dateKey);
        final currentStreak = progress.currentStreakFor(challenge.dateKey);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 58,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: _HeaderCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            title: const Text('Daily Challenge'),
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff101f63),
                  Color(0xff3b1e71),
                  Color(0xff10123d),
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = math.min(constraints.maxWidth, 620.0);
                return SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.today_rounded,
                              color: PrismColors.pink,
                              size: 42,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              challenge.dateKey,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: PrismColors.muted,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              challenge.objective.description(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              completed
                                  ? 'Completed · best ${progress.bestScoreFor(challenge.dateKey)}'
                                  : 'Offline-ready and the same for every player today.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: PrismColors.muted),
                            ),
                            const SizedBox(height: 26),
                            _StatPanel(
                              children: [
                                _Stat(
                                  label: 'CURRENT STREAK',
                                  value: '$currentStreak',
                                ),
                                _Stat(
                                  label: 'LONGEST',
                                  value: '${progress.longestStreak}',
                                ),
                                _Stat(
                                  label: 'MOVES',
                                  value: '${challenge.moveLimit ?? '∞'}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: () => _start(context, challenge),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  completed ? 'PLAY AGAIN' : 'START TODAY',
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'RECENT DAYS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _DailyHistory(progress: progress),
                            const SizedBox(height: 18),
                            const Text(
                              'The board and pieces are derived from the UTC date and a versioned local seed. No connection is required.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PrismColors.muted,
                                fontSize: 12,
                              ),
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
        );
      },
    ),
  );
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final wordPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xffef3e46),
          Color(0xffff8d2d),
          Color(0xffffd238),
          Color(0xff43d548),
          Color(0xff28b9ed),
        ],
        stops: [0, .23, .46, .7, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 220, 40));

    return Semantics(
      label: 'Blockora',
      child: SizedBox(
        width: 220,
        height: 82,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BLOCKORA',
                  style: TextStyle(
                    foreground: wordPaint,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    height: .9,
                    shadows: const [
                      Shadow(
                        color: Color(0xaa030a31),
                        offset: Offset(3, 4),
                        blurRadius: 0,
                      ),
                      Shadow(
                        color: Color(0x66ffffff),
                        offset: Offset(-1, -1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 24,
              child: Transform.rotate(
                angle: .15,
                child: const Icon(
                  Icons.star_rounded,
                  color: PrismColors.yellow,
                  size: 25,
                  shadows: [
                    Shadow(
                      color: PrismColors.orange,
                      blurRadius: 8,
                      offset: Offset(1, 3),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 0,
              child: Transform.rotate(
                angle: .15,
                child: const Icon(
                  Icons.star_rounded,
                  color: PrismColors.yellow,
                  size: 25,
                  shadows: [
                    Shadow(
                      color: PrismColors.orange,
                      blurRadius: 8,
                      offset: Offset(1, 3),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 0,
              child: Transform.rotate(
                angle: .15,
                child: const Icon(
                  Icons.star_rounded,
                  color: PrismColors.yellow,
                  size: 25,
                  shadows: [
                    Shadow(
                      color: PrismColors.orange,
                      blurRadius: 8,
                      offset: Offset(1, 3),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 24,
              child: Transform.rotate(
                angle: .15,
                child: const Icon(
                  Icons.star_rounded,
                  color: PrismColors.yellow,
                  size: 25,
                  shadows: [
                    Shadow(
                      color: PrismColors.orange,
                      blurRadius: 8,
                      offset: Offset(1, 3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCloseButton extends StatefulWidget {
  const _HeaderCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HeaderCloseButton> createState() => _HeaderCloseButtonState();
}

class _HeaderCloseButtonState extends State<_HeaderCloseButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back to mode selection',
    child: Tooltip(
      message: 'Back to mode selection',
      child: AnimatedScale(
        scale: _pressed ? .9 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffff79c9), Color(0xff9e429f)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: .25)),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.pink.withValues(alpha: .3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              splashColor: Colors.white.withValues(alpha: .25),
              highlightColor: Colors.white.withValues(alpha: .12),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.mode, required this.onTap});

  final GameMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _CompactGameButton(
    icon: Icons.play_arrow_rounded,
    accent: PrismColors.cyan,
    gradient: const [Color(0xff6475c8), Color(0xff313773)],
    title: 'Resume ${mode.label}',
    description: 'Your active board is saved locally.',
    detail: 'SAVED LOCALLY',
    onTap: onTap,
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.gradient,
    required this.title,
    required this.description,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final String title;
  final String description;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _CompactGameButton(
    icon: icon,
    accent: color,
    gradient: gradient,
    title: title,
    description: description,
    detail: detail,
    onTap: onTap,
  );
}

class _CompactGameButton extends StatefulWidget {
  const _CompactGameButton({
    required this.icon,
    required this.accent,
    required this.gradient,
    required this.title,
    required this.description,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final List<Color> gradient;
  final String title;
  final String description;
  final String detail;
  final VoidCallback onTap;

  @override
  State<_CompactGameButton> createState() => _CompactGameButtonState();
}

class _CompactGameButtonState extends State<_CompactGameButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.description}. ${widget.detail}',
      child: AnimatedScale(
        scale: _pressed ? .965 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            height: 78,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradient,
              ),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: .22)),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: .24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: .24),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              splashColor: Colors.white.withValues(alpha: .22),
              highlightColor: Colors.white.withValues(alpha: .1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .2),
                        ),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 27),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 29,
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final JourneyLevel level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: unlocked ? 1 : .46,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 7),
        decoration: prismPanel(radius: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? Icons.bolt_rounded : Icons.lock_rounded,
              color: unlocked ? PrismColors.yellow : PrismColors.muted,
              size: 21,
            ),
            const SizedBox(height: 6),
            Text(
              '${level.levelNumber}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${'★' * stars}${'☆' * (3 - stars)}',
              style: const TextStyle(
                color: PrismColors.yellow,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              level.objective.type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: PrismColors.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatPanel extends StatelessWidget {
  const _StatPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: prismPanel(radius: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: PrismColors.ink,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: PrismColors.muted,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    ],
  );
}

class _DailyHistory extends StatelessWidget {
  const _DailyHistory({required this.progress});

  final DailyProgress progress;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toUtc();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var offset = 6; offset >= 0; offset--)
          Builder(
            builder: (context) {
              final date = today.subtract(Duration(days: offset));
              final key = utcDateKey(date);
              final done = progress.isCompleted(key);
              return Column(
                children: [
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
                    style: const TextStyle(
                      color: PrismColors.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    done ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: done ? PrismColors.green : Colors.white24,
                    size: 23,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
