import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../application/game_cubit.dart';
import '../domain/game_modes.dart';
import '../domain/mode_catalog.dart';
import 'cartoon_gameplay_screen.dart';

class CartoonGameShell extends StatelessWidget {
  const CartoonGameShell({super.key, required this.cubit, this.onExit});

  final GameCubit cubit;
  final VoidCallback? onExit;

  static const _backgroundColors = [
    Color(0xffcf728b),
    Color(0xff529fdb),
    Color(0xff55b993),
    Color(0xffa77bce),
    Color(0xffe49a63),
    Color(0xffd7b647),
    Color(0xff4bb8c9),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        const Positioned(
          left: -20,
          top: 90,
          child: _CornerToy(color: Color(0xff54c8ed), angle: -.14),
        ),
        const Positioned(
          right: -18,
          top: 180,
          child: _CornerToy(color: Color(0xff9bd528), angle: .14),
        ),
        SafeArea(
          child: BlocProvider.value(
            value: cubit,
            child: Stack(children: [
              CartoonGameplayScreenV3(onExit: onExit),
              BlocBuilder<GameCubit, GameState>(builder: (context, state) {
                if (state.session.mode != GameMode.journey) return const SizedBox.shrink();
                final level = journeyLevelById(state.session.journeyLevelId ?? 'journey_01');
                return Positioned(left: 72, right: 72, top: 0,
                  child: IgnorePointer(child: _LevelBar(level: level.levelNumber,
                    score: state.score, target: level.objective.targetValue)));
              }),
            ]),
          ),
        ),
      ],
    );
    return Scaffold(
      body: BlocSelector<GameCubit, GameState, int>(
        bloc: cubit,
        selector: (state) => state.score ~/ 1000,
        builder: (context, milestone) {
          final tint = _backgroundColors[milestone % _backgroundColors.length];
          return AnimatedContainer(
            key: const ValueKey('score-background'),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 650),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    tint.withValues(alpha: .18),
                    CartoonColors.paper,
                  ),
                  Color.alphaBlend(
                    tint.withValues(alpha: .28),
                    CartoonColors.paper,
                  ),
                ],
              ),
            ),
            child: content,
          );
        },
      ),
    );
  }
}

class _CornerToy extends StatelessWidget {
  const _CornerToy({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .4), width: 2),
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

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level, required this.score, required this.target});
  final int level;
  final int score;
  final int target;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xeefcf2df),
      borderRadius: BorderRadius.circular(14)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('LEVEL $level     $score / $target', maxLines: 1,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (score / target).clamp(0.0, 1.0)),
        duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero : const Duration(milliseconds: 480),
        builder: (_, value, __) => LinearProgressIndicator(value: value,
          minHeight: 9, borderRadius: BorderRadius.circular(9),
          backgroundColor: const Color(0xffcbd6e7),
          color: value >= 1 ? const Color(0xffffc92b) : const Color(0xff54bf69)),
      ),
    ]),
  );
}
