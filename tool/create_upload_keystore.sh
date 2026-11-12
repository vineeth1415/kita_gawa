#!/usr/bin/env bash
#
# Generates the upload keystore that signs release APKs, and prints the four
# GitHub secrets that go with it.
#
# Run this ONCE. The keystore is the only artefact in this project that cannot
# be regenerated: Android identifies an app by its signing key, so replacing it
# means every tester has to uninstall and reinstall rather than update in
# place. Back the .jks file up somewhere outside this machine before you go
# any further, and keep the password with it.
#
# Usage:
#   ./tool/create_upload_keystore.sh [output.jks]
#
# Then, in GitHub → Settings → Secrets and variables → Actions, add the four
# secrets it prints, plus FIREBASE_SERVICE_ACCOUNT. See docs/operations.md.

set -euo pipefail

OUTPUT="${1:-upload-keystore.jks}"
ALIAS="upload"
DNAME="CN=Kitagawa India, OU=Inventory, O=Kitagawa, L=Chennai, C=IN"

if [ -e "$OUTPUT" ]; then
  echo "$OUTPUT already exists. Refusing to overwrite a signing key." >&2
  echo "Delete it deliberately if you are certain it is not the live one." >&2
  exit 65
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool not found — install a JDK (e.g. 'brew install temurin')." >&2
  exit 69
fi

# java.util.Properties reads a backslash as an escape, so key.properties would
# mangle a password containing one. Generate from an alphabet without it.
#
# Note the fixed-size read: piping /dev/urandom straight into `head -c` closes
# the pipe early, and under `set -o pipefail` that SIGPIPE fails the script
# with no message at all.
RANDOM_BYTES="$(head -c 512 /dev/urandom | base64)"
PASSWORD="$(printf '%s' "$RANDOM_BYTES" | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-40)"

if [ "${#PASSWORD}" -ne 40 ]; then
  echo "Could not generate a password from /dev/urandom." >&2
  exit 70
fi

# 10000 days: an upload key that expires is an app that can no longer ship an
# update its users can install.
keytool -genkeypair \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -keystore "$OUTPUT" \
  -storetype PKCS12 \
  -storepass "$PASSWORD" \
  -keypass "$PASSWORD" \
  -dname "$DNAME" >/dev/null

echo "Created $OUTPUT"
echo
echo "Back this file up now, off this machine. Losing it is unrecoverable."
echo
echo "--- GitHub repository secrets ------------------------------------------"
echo
echo "ANDROID_KEYSTORE_PASSWORD"
echo "$PASSWORD"
echo
echo "ANDROID_KEY_PASSWORD"
echo "$PASSWORD"
echo
echo "ANDROID_KEY_ALIAS"
echo "$ALIAS"
echo
echo "ANDROID_KEYSTORE_BASE64"
base64 < "$OUTPUT" | tr -d '\n'
echo
echo
echo "------------------------------------------------------------------------"
echo "The base64 blob above is the keystore itself — treat it exactly as you"
echo "would the file. Clear your terminal scrollback when you are done."
