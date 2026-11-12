/// The "business date" is the calendar day a movement belongs to, and it is
/// the key the closing report aggregates on.
///
/// It is deliberately derived from the device's LOCAL clock, never from the
/// Firestore server timestamp: the database lives in the `nam5` US
/// multi-region and stamps UTC, so a movement recorded at 9am in India would
/// otherwise be filed under the previous day. Local time is what the people
/// on the warehouse floor mean by "today".
library;

/// Formats a local [DateTime] as `YYYY-MM-DD`. Also the document id of the
/// shift and of its closing report.
String businessDateOf(DateTime local) {
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Today, in the operator's own timezone.
String todayBusinessDate() => businessDateOf(DateTime.now());

/// Parses a `YYYY-MM-DD` business date back into a local midnight DateTime,
/// for formatting in the UI.
DateTime parseBusinessDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Not a business date: $value');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
