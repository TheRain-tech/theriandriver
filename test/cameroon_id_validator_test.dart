import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/core/utils/validators.dart';

void main() {
  const validator = CameroonIdValidator();

  test('accepts common Cameroon ID formats and normalizes punctuation', () {
    expect(validator.isValid('123 456 789'), isTrue);
    expect(validator.isValid('CM-123456789'), isTrue);
    expect(validator.normalize('cm-123 456 789'), 'CM123456789');
  });

  test('rejects only empty or obviously malformed ID values', () {
    expect(validator.isValid(''), isFalse);
    expect(validator.isValid('12@34'), isFalse);
    expect(validator.call('CM-123456789'), isNull);
  });
}
