import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/utils/validators.dart';

void main() {
  group('validateReferenceNumber', () {
    test('rejects an empty reference', () {
      expect(validateReferenceNumber(''), isNotNull);
      expect(validateReferenceNumber(null), isNotNull);
      expect(validateReferenceNumber('   '), isNotNull);
    });

    test('rejects below the 4 character minimum', () {
      expect(validateReferenceNumber('ABC'), contains('at least 4'));
      expect(validateReferenceNumber('A1'), contains('at least 4'));
    });

    test('accepts exactly the minimum and maximum lengths', () {
      expect(validateReferenceNumber('ABCD'), isNull);
      expect(validateReferenceNumber('A234567890123456'), isNull);
      expect('A234567890123456'.length, 16);
    });

    test('rejects above the 16 character maximum', () {
      expect(
        validateReferenceNumber('A2345678901234567'),
        contains('at most 16'),
      );
    });

    test('accepts letters, digits and a mix of both', () {
      expect(validateReferenceNumber('INV2024001'), isNull);
      expect(validateReferenceNumber('12345'), isNull);
      expect(validateReferenceNumber('ABCDEF'), isNull);
      expect(validateReferenceNumber('inv2024001'), isNull);
    });

    test('rejects spaces, symbols and non-ascii characters', () {
      expect(validateReferenceNumber('INV 2024'), isNotNull);
      expect(validateReferenceNumber('INV-2024'), isNotNull);
      expect(validateReferenceNumber('INV/2024'), isNotNull);
      expect(validateReferenceNumber('INV_2024'), isNotNull);
      expect(validateReferenceNumber('INV#2024'), isNotNull);
      expect(validateReferenceNumber('रेफरेंस'), isNotNull);
    });

    test('measures length after trimming surrounding whitespace', () {
      expect(validateReferenceNumber('  ABCD  '), isNull);
      expect(validateReferenceNumber('  ABC  '), contains('at least 4'));
    });
  });

  group('normalizeReferenceNumber', () {
    test('uppercases and trims so one reference has one stored form', () {
      expect(normalizeReferenceNumber(' inv2024001 '), 'INV2024001');
      expect(
        normalizeReferenceNumber('inv001'),
        normalizeReferenceNumber('INV001'),
      );
    });
  });

  group('quantity validators', () {
    test('positive quantity rejects zero, negatives and non-numbers', () {
      expect(validatePositiveQuantity('0'), isNotNull);
      expect(validatePositiveQuantity('-3'), isNotNull);
      expect(validatePositiveQuantity('two'), isNotNull);
      expect(validatePositiveQuantity(''), isNotNull);
      expect(validatePositiveQuantity('1'), isNull);
      expect(validatePositiveQuantity('250'), isNull);
    });

    test('non-negative quantity allows zero but not negatives', () {
      expect(validateNonNegativeQuantity('0'), isNull);
      expect(validateNonNegativeQuantity('-1'), isNotNull);
    });
  });

  group('validateUsername', () {
    test('enforces length and allowed characters', () {
      expect(validateUsername('ab'), isNotNull);
      expect(validateUsername('ravi'), isNull);
      expect(validateUsername('ravi.kumar'), isNull);
      expect(validateUsername('ravi kumar'), isNotNull);
      expect(validateUsername('ravi@kumar'), isNotNull);
    });
  });

  group('password change', () {
    test('a new password still has to clear Firebase\'s six-character floor', () {
      expect(validateNewPassword(''), isNotNull);
      expect(validateNewPassword('short'), isNotNull);
      expect(validateNewPassword('longenough'), isNull);
    });

    test('refuses the current password back as the new one', () {
      expect(
        validateNewPassword('samepass', currentPassword: 'samepass'),
        isNotNull,
      );
      expect(
        validateNewPassword('newpass1', currentPassword: 'samepass'),
        isNull,
      );
    });

    test('an unknown current password does not block the change', () {
      // The current field is optional to the validator so an empty one
      // reports "required" on its own field rather than here.
      expect(validateNewPassword('newpass1', currentPassword: ''), isNull);
      expect(validateNewPassword('newpass1'), isNull);
    });

    test('confirmation must match exactly', () {
      expect(validatePasswordConfirmation('', password: 'newpass1'), isNotNull);
      expect(
        validatePasswordConfirmation('newpass2', password: 'newpass1'),
        isNotNull,
      );
      expect(
        validatePasswordConfirmation('Newpass1', password: 'newpass1'),
        isNotNull,
      );
      expect(
        validatePasswordConfirmation('newpass1', password: 'newpass1'),
        isNull,
      );
    });
  });
}
