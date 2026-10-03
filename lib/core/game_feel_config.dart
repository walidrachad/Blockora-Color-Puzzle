import 'package:flutter/foundation.dart';

/// Central timing budget for the tactile layer. Domain rules intentionally do
/// not depend on this file; only widgets and orchestration use these values.
@immutable
class GameFeelConfig {
  const GameFeelConfig._();

  static const pickup = Duration(milliseconds: 85);
  static const scoreCounter = Duration(milliseconds: 420);
  static const validSnap = Duration(milliseconds: 80);
  static const invalidReturn = Duration(milliseconds: 140);
  static const placementBounce = Duration(milliseconds: 105);
  static const clearTotal = Duration(milliseconds: 580);
  static const particleImpact = Duration(milliseconds: 390);
  static const floatingScore = Duration(milliseconds: 850);
  static const praise = Duration(milliseconds: 760);
  static const combo = Duration(milliseconds: 130);
  static const heartPulse = Duration(milliseconds: 360);
  static const batchEntrance = Duration(milliseconds: 150);
  static const overlayEntrance = Duration(milliseconds: 210);
  static const reviveEssential = Duration(milliseconds: 420);
  static const continueWindow = Duration(seconds: 5);
  static const gameOverInterstitialDelay = Duration(seconds: 2);
  static const splashEntrance = Duration(milliseconds: 720);
  static const splashHold = Duration(milliseconds: 680);
}
