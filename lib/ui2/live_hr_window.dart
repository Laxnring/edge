/// Pure range selection for timestamped foreground HR samples.
///
/// Keeping this outside the widget makes the important promise testable: a
/// range is based on elapsed time, not on an assumed sample frequency.
List<int> selectLiveHrWindow(
  List<({int at, int hr})> samples, {
  required DateTime now,
  required Duration window,
}) {
  final nowMs = now.millisecondsSinceEpoch;
  final minMs = nowMs - window.inMilliseconds;
  return [
    for (final sample in samples)
      if (sample.at >= minMs && sample.at <= nowMs) sample.hr,
  ];
}
