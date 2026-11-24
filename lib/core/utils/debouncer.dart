import 'dart:async';
import 'dart:ui' show VoidCallback;

class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void run(VoidCallback fn) {
    _t?.cancel();
    _t = Timer(delay, fn);
  }

  void dispose() => _t?.cancel();
}
