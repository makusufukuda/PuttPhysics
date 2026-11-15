class BallSearchRoi {
  const BallSearchRoi._();

  static double margin({
    required bool movementStarted,
    required bool movementPending,
    required int missedFrames,
  }) {
    if (!movementStarted && !movementPending && missedFrames == 0) {
      return 250.0;
    }
    return 400.0 + missedFrames * 150.0;
  }
}
