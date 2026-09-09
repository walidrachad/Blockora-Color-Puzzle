enum ClearAudioTier { one, two, three }

ClearAudioTier tierForCompletedLines(int completedLines) {
  if (completedLines <= 1) return ClearAudioTier.one;
  if (completedLines == 2) return ClearAudioTier.two;
  return ClearAudioTier.three;
}

String clearAudioAssetForLines(int completedLines) =>
    switch (tierForCompletedLines(completedLines)) {
      ClearAudioTier.one => 'audio/mixkit-video-game-treasure-2066.wav',
      ClearAudioTier.two =>
        'audio/mixkit-player-recharging-in-video-game-2041.wav',
      ClearAudioTier.three => 'audio/blockora_clear_3.wav',
    };
