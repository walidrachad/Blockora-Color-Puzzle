import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/game/application/game_cubit.dart';

/// First-party gameplay telemetry; no personal identifiers or ad unit IDs.
class GameAnalytics {
  GameAnalytics._();
  static final GameAnalytics instance = GameAnalytics._();
  FirebaseAnalytics? _client;

  Future<void> initialize() async {
    try {
      _client = FirebaseAnalytics.instance;
      await _client!.setAnalyticsCollectionEnabled(!kDebugMode);
    } catch (error) {
      debugPrint('Analytics unavailable: $error');
    }
  }

  void event(String name, [Map<String, Object>? parameters]) {
    final client = _client;
    if (client == null || kDebugMode) return;
    unawaited(_safeLog(client, name, parameters));
  }

  Future<void> _safeLog(
    FirebaseAnalytics client,
    String name,
    Map<String, Object>? parameters,
  ) async {
    try {
      await client.logEvent(name: name, parameters: parameters);
    } catch (error) {
      debugPrint('Analytics event failed ($name): $error');
    }
  }
}

/// Observes the actual game state transitions (not widget rebuilds).
/// A single turn ID is logged once even if several UI state updates occur.
class GameAnalyticsObserver extends BlocObserver {
  final Map<GameCubit, DateTime> _started = {};
  final Map<GameCubit, int> _lastTurnId = {};

  String _mode(GameState state) => state.session.mode.name;

  Map<String, Object> _common(GameState state) => {
    'game_mode': _mode(state),
    'score': state.score,
    'best_score': state.best,
    'moves': state.session.movesUsed,
    'lines_cleared': state.session.linesCleared,
    'combo': state.combo,
    'revive_count': state.reviveCount,
  };

  void _start(GameCubit cubit, GameState state) {
    _started[cubit] = DateTime.now();
    _lastTurnId.remove(cubit);
    GameAnalytics.instance.event('game_start', {'game_mode': _mode(state)});
  }

  int _duration(GameCubit cubit) =>
      DateTime.now().difference(_started[cubit] ?? DateTime.now()).inSeconds;

  void _finish(GameCubit cubit, GameState state, String outcome) {
    GameAnalytics.instance.event('game_end', {
      ..._common(state),
      'outcome': outcome,
      'duration_seconds': _duration(cubit),
    });
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (bloc is! GameCubit ||
        change.currentState is! GameState ||
        change.nextState is! GameState) return;
    final before = change.currentState as GameState;
    final after = change.nextState as GameState;

    // Fresh run: initial score zero and turn counter reset, including restart.
    if (after.hasSavedSession &&
        after.status == GameStatus.playing &&
        after.score == 0 &&
        after.session.movesUsed == 0 &&
        (before.status != GameStatus.playing ||
         before.score != 0 ||
         before.session.movesUsed != 0 ||
         !before.hasSavedSession)) {
      _start(bloc, after);
    }

    final turn = after.turn;
    if (turn != null && turn.id != _lastTurnId[bloc] &&
        after.session.movesUsed > before.session.movesUsed) {
      _lastTurnId[bloc] = turn.id;
      GameAnalytics.instance.event('piece_placed', {
        'game_mode': _mode(after),
        'piece_cells': turn.placedCells.length,
        'points': turn.points,
        'score': after.score,
        'move_number': after.session.movesUsed,
        'lines': turn.lines,
      });
      if (turn.lines > 0) {
        GameAnalytics.instance.event('line_clear', {
          'game_mode': _mode(after),
          'lines': turn.lines,
          'points': turn.points,
          'combo': after.combo,
          'score': after.score,
        });
      }
      if (after.combo >= 2 && after.combo > before.combo) {
        GameAnalytics.instance.event('combo_reached', {
          'game_mode': _mode(after),
          'combo': after.combo,
          'score': after.score,
        });
      }
    }

    if (before.status != GameStatus.continuePrompt &&
        after.status == GameStatus.continuePrompt) {
      GameAnalytics.instance.event('revive_offered', _common(after));
    }
    if (before.status != GameStatus.adLoading &&
        after.status == GameStatus.adLoading) {
      GameAnalytics.instance.event('rewarded_revive_requested', _common(after));
    }
    if (after.reviveCount > before.reviveCount) {
      GameAnalytics.instance.event('revive_success', _common(after));
    }
    if (before.status == GameStatus.adLoading &&
        after.status == GameStatus.continuePrompt) {
      GameAnalytics.instance.event('rewarded_revive_failed', {
        'game_mode': _mode(after),
        'reason': after.adMessage ?? 'unknown',
      });
    }
    if (before.status != after.status &&
        after.status == GameStatus.results) {
      _finish(bloc, after, 'game_over');
    }
    if (before.status != after.status &&
        (after.status == GameStatus.modeSuccess ||
         after.status == GameStatus.modeFailure)) {
      _finish(bloc, after,
          after.status == GameStatus.modeSuccess ? 'win' : 'loss');
    }
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    if (bloc is GameCubit) {
      _started.remove(bloc);
      _lastTurnId.remove(bloc);
    }
    super.onClose(bloc);
  }
}
