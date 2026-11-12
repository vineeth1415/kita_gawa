import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/utils/business_date.dart';

void main() {
  group('businessDateOf', () {
    test('formats as zero-padded YYYY-MM-DD', () {
      expect(businessDateOf(DateTime(2026, 1, 5)), '2026-01-05');
      expect(businessDateOf(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('uses the local calendar day, not UTC', () {
      // The database region is nam5, which stamps UTC. A movement recorded at
      // 09:00 in India is 03:30 UTC the same day, but one recorded at 02:00
      // local is still 20:30 UTC on the PREVIOUS day. Filing by UTC would put
      // that second movement on the wrong report, so business dates are
      // always derived from local wall-clock time.
      final earlyMorning = DateTime(2026, 3, 15, 2, 0);
      expect(businessDateOf(earlyMorning), '2026-03-15');
      expect(
        businessDateOf(earlyMorning.toUtc()),
        isNot(equals(businessDateOf(earlyMorning))),
        reason:
            'this test only means something where local time is not UTC; '
            'if it fails, the machine is on UTC and the distinction is moot',
        skip: DateTime.now().timeZoneOffset == Duration.zero,
      );
    });

    test('rolls over exactly at local midnight', () {
      expect(businessDateOf(DateTime(2026, 3, 15, 23, 59, 59)), '2026-03-15');
      expect(businessDateOf(DateTime(2026, 3, 16, 0, 0, 0)), '2026-03-16');
    });

    test('handles a leap day', () {
      expect(businessDateOf(DateTime(2028, 2, 29)), '2028-02-29');
    });
  });

  group('parseBusinessDate', () {
    test('round-trips through formatting', () {
      const date = '2026-07-04';
      expect(businessDateOf(parseBusinessDate(date)), date);
    });

    test('returns local midnight', () {
      final parsed = parseBusinessDate('2026-07-04');
      expect(parsed.hour, 0);
      expect(parsed.minute, 0);
      expect(parsed.isUtc, isFalse);
    });

    test('rejects a malformed date', () {
      expect(() => parseBusinessDate('04-07-2026x'), throwsFormatException);
      expect(() => parseBusinessDate('2026/07/04'), throwsFormatException);
    });
  });

  test('todayBusinessDate agrees with formatting DateTime.now()', () {
    expect(todayBusinessDate(), businessDateOf(DateTime.now()));
  });
}
