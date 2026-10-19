import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../application/game_cubit.dart';
import '../domain/mode_catalog.dart';
import 'first_play_onboarding.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key, required this.cubit});
  final GameCubit cubit;

  Future<void> _play(BuildContext context, int index) async {
    if (index >= journeyLevels.length) return;
    await cubit.startJourneyLevel(journeyLevels[index]);
    if (!context.mounted) return;
    await Navigator.push<void>(context, MaterialPageRoute(
      builder: (routeContext) => FirstPlayGame(
        cubit: cubit, onExit: () => Navigator.pop(routeContext)),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: cartoonBackground(),
      child: SafeArea(child: Column(children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
          const Expanded(child: Text('LEVELS', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white))),
          const SizedBox(width: 48),
        ]),
        Expanded(child: BlocBuilder<GameCubit, GameState>(
          bloc: cubit,
          builder: (context, state) {
            final unlocked = state.progress.journey.unlockedLevel;
            return GridView.builder(
              padding: const EdgeInsets.all(18),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150, mainAxisSpacing: 14, crossAxisSpacing: 14,
                childAspectRatio: .92,
              ),
              itemCount: journeyLevels.length,
              itemBuilder: (context, index) {
                final level = journeyLevels[index];
                final available = level.levelNumber <= unlocked;
                final stars = state.progress.journey.starsFor(level.id);
                return Material(color: Colors.transparent, child: InkWell(
                  onTap: available ? () => _play(context, index) : null,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: available
                        ? const [Color(0xffffe286), Color(0xffff9f48)]
                        : const [Color(0xffaeb9cc), Color(0xff75869d)]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(available ? Icons.star_rounded : Icons.lock_rounded,
                        color: Colors.white, size: 25),
                      Text('${level.levelNumber}', style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                      Text('${level.objective.targetValue} PTS', style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                      if (stars > 0) Text('★' * stars, style: const TextStyle(
                        color: Color(0xffffec76), fontSize: 16)),
                    ]),
                  ),
                ));
              },
            );
          },
        )),
      ])),
    ),
  );
}
