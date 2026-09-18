bool isBleStale(DateTime? lastDataAt, {required DateTime now}) {
  if (lastDataAt == null) return true;
  final age = now.difference(lastDataAt).inSeconds;
  return age > 30;
}
