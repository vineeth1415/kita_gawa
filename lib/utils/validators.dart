/// Pure validation helpers. Kept free of Flutter and Firebase imports so they
/// can be unit-tested directly, and so the reference-number rule has exactly
/// one definition shared by every form that collects it.
library;

const int kReferenceMinLength = 4;
const int kReferenceMaxLength = 16;

final RegExp _referencePattern = RegExp(r'^[A-Za-z0-9]+$');

String? requiredField(String? value, {String label = 'This field'}) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

/// Stock movements are traced back to paperwork by this reference, so the
/// format is enforced identically on the client and in firestore.rules:
/// alphanumeric only, 4 to 16 characters.
String? validateReferenceNumber(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return 'Reference number is required';
  }
  if (raw.length < kReferenceMinLength) {
    return 'Reference must be at least $kReferenceMinLength characters';
  }
  if (raw.length > kReferenceMaxLength) {
    return 'Reference must be at most $kReferenceMaxLength characters';
  }
  if (!_referencePattern.hasMatch(raw)) {
    return 'Use letters and numbers only — no spaces or symbols';
  }
  return null;
}

/// The stored form of a reference number. Uppercasing means `inv001` and
/// `INV001` are the same piece of paperwork rather than two different ones.
String normalizeReferenceNumber(String value) => value.trim().toUpperCase();

/// Item codes follow the same normalisation so lookups are case-insensitive.
String normalizeItemCode(String value) => value.trim().toUpperCase();

String? validateItemCode(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Code is required';
  if (raw.length > 32) return 'Code must be at most 32 characters';
  if (!RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(raw)) {
    return 'Use letters, numbers, dot, dash or underscore';
  }
  return null;
}

String? validateUsername(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Username is required';
  if (raw.length < 3) return 'Username must be at least 3 characters';
  if (raw.length > 24) return 'Username must be at most 24 characters';
  if (!RegExp(r'^[a-z0-9._\-]+$').hasMatch(raw.toLowerCase())) {
    return 'Use letters, numbers, dot, dash or underscore';
  }
  return null;
}

String? validatePassword(String? value) {
  final raw = value ?? '';
  if (raw.isEmpty) return 'Password is required';
  // Firebase Auth's own floor is 6 characters.
  if (raw.length < 6) return 'Password must be at least 6 characters';
  return null;
}

/// A password change has to clear Firebase's floor *and* actually be a
/// change. Silently accepting the old value back would leave an operator
/// believing they had rotated a password they had not.
String? validateNewPassword(String? value, {String? currentPassword}) {
  final basic = validatePassword(value);
  if (basic != null) return basic;
  if (currentPassword != null &&
      currentPassword.isNotEmpty &&
      value == currentPassword) {
    return 'New password must be different from the current one';
  }
  return null;
}

/// Typing a new password blind, on a phone, with gloves on, is easy to get
/// wrong — so it is always confirmed against a second field.
String? validatePasswordConfirmation(String? value, {required String password}) {
  if ((value ?? '').isEmpty) return 'Re-enter the new password';
  if (value != password) return 'Passwords do not match';
  return null;
}

String? validatePositiveQuantity(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Quantity is required';
  final parsed = int.tryParse(raw);
  if (parsed == null) return 'Enter a whole number';
  if (parsed <= 0) return 'Quantity must be greater than zero';
  return null;
}

String? validateNonNegativeQuantity(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Enter a count';
  final parsed = int.tryParse(raw);
  if (parsed == null) return 'Enter a whole number';
  if (parsed < 0) return 'Count cannot be negative';
  return null;
}
