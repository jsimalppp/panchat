import 'package:flutter_test/flutter_test.dart';
import 'package:panchat/core/utils/format.dart';

void main() {
  test('username validation matches the database check', () {
    expect(isValidUsername('panda_01'), isTrue);
    expect(isValidUsername('ab'), isFalse);
    expect(isValidUsername('Panda'), isFalse);
    expect(isValidUsername('a b c'), isFalse);
  });

  test('search query is sanitized', () {
    expect(sanitizeUsernameQuery('@Pan-da!'), 'panda');
  });
}
