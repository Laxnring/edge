import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/app.dart';

void main() {
  test('the web shell ignores legacy browser fragments at startup', () {
    // `#ProfileHome` was emitted by an older local preview. It must never be
    // treated as a Flutter named route: this app restores through `_Gate`.
    expect(kBrowserInitialRoute, '/');
  });
}
