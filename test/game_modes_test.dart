import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/core/audio/line_clear_audio.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/domain/game_modes.dart';
import 'package:prism_puzzle/features/game/domain/mode_catalog.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/piece_generator.dart';

void main() {
  test('Journey catalog contains 30 data-driven, deterministic levels', () {
    expect(journeyLevels, hasLength(30));
    expect(journeyLevels.map((level) => level.id).toSet(), hasLength(30));
    expect(journeyLevels.first.levelNumber, 1);
    expect(journeyLevels.last.levelNumber, 30);
    expect(
      journeyLevels.map((level) => level.objective.type).toSet(),
      containsAll(JourneyObjectiveType.values),
    );
    expect(journeyLevels[0].toJson(), journeyLevels[0].toJson());
  });

  test('Journey completion awards stars and unlocks the next level', () {
    final level = journeyLevels.first;
    final progress = const JourneyProgress().recordCompletion(
      level,
      score: level.starThresholds.three,
      moves: 1,
      lines: 0,
      coloredCells: 0,
    );
    expect(progress.starsFor(level.id), 3);
    expect(progress.isUnlocked(journeyLevels[1]), isTrue);
    expect(progress.bestScores[level.id], level.starThresholds.three);
  });

  test('Daily challenge is identical for a UTC date and versioned', () {
    final date = DateTime.utc(2026, 9, 3, 23, 45);
    final sameDay = dailyChallengeFor(date);
    final localEquivalent = dailyChallengeFor(DateTime.utc(2026, 9, 3, 1, 45));
    final otherVersion = dailyChallengeFor(date, configurationVersion: 'v2');
    expect(sameDay, localEquivalent);
    expect(sameDay.dateKey, '2026-09-03');
    expect(otherVersion, isNot(sameDay));
  });

  test('Daily streak is consecutive and rejects backward clock awards', () {
    var progress = const DailyProgress().recordCompletion('2026-09-01', 10);
    progress = progress.recordCompletion('2026-09-02', 20);
    expect(progress.currentStreak, 2);
    expect(progress.longestStreak, 2);
    final backwards = progress.recordCompletion('2026-08-31', 999);
    expect(backwards, progress);
    final gap = progress.recordCompletion('2026-09-04', 30);
    expect(gap.currentStreak, 1);
    expect(gap.longestStreak, 2);
  });

  test('session and mode progress survive the save schema', () {
    final challenge = dailyChallengeFor(DateTime.utc(2026, 9, 3));
    final saved = SavedGame(
      board: challenge.initialBoard,
      pieces: [PieceLibrary.byId['dot'], null, null],
      score: 12,
      best: 12,
      combo: 1,
      generatorState: 99,
      reviveUsed: false,
      session: GameSession(
        mode: GameMode.dailyChallenge,
        dailyChallenge: challenge,
        journeyObjective: challenge.objective,
        movesUsed: 2,
      ),
      progress: const ModeProgressSnapshot(),
      hasSavedSession: true,
    );
    final restored = SavedGame.fromJson(saved.toJson());
    expect(restored.session.mode, GameMode.dailyChallenge);
    expect(restored.session.dailyChallenge, challenge);
    expect(restored.session.movesUsed, 2);
    expect(restored.hasSavedSession, isTrue);
  });

  test('allowed piece generation remains deterministic', () {
    final first = PieceGenerator(
      seed: 42,
    ).nextBatch(allowedPieceIds: const ['dot', 'duo_h']);
    final second = PieceGenerator(
      seed: 42,
    ).nextBatch(allowedPieceIds: const ['dot', 'duo_h']);
    expect(first, second);
    expect(
      first.every((piece) => piece.id == 'dot' || piece.id == 'duo_h'),
      isTrue,
    );
  });

  test('line clear audio maps one placement to one tier', () {
    expect(tierForCompletedLines(1), ClearAudioTier.one);
    expect(tierForCompletedLines(2), ClearAudioTier.two);
    expect(tierForCompletedLines(3), ClearAudioTier.three);
    expect(tierForCompletedLines(8), ClearAudioTier.three);
    expect(
      clearAudioAssetForLines(2),
      'audio/mixkit-player-recharging-in-video-game-2041.wav',
    );
  });
}
