import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../../features/game/domain/mode_catalog.dart';

/// Reads cached/activated values even if the network fetch fails.
class RemoteLevels {
  static Future<void> load() async {
    try {
      final config = FirebaseRemoteConfig.instance;
      // Advertising bootstrap already initializes Firebase and fetches Remote Config.
      final json = config.getString('blockora_levels_json');
      if (json.trim().isNotEmpty) applyLevelsJson(json);
    } catch (_) {
      // Offline: the default score-level catalog remains playable.
    }
  }
}
