#!/usr/bin/env bash
#
# Resets a staff member's password when they have forgotten it.
#
# Why this script exists: the app can only change a password the user can
# still type (see the Change password screen). Setting *someone else's*
# password needs privileged access:
#
#   * sendPasswordResetEmail is useless here — usernames map to synthetic
#     addresses at kitagawa-inventory-app.app, a domain nobody receives mail at
#   * the client SDK cannot touch another account at all
#   * the Admin SDK could, but needs Cloud Functions, which needs Blaze;
#     this project runs on Spark
#
# So the reset goes through the Identity Toolkit *admin* REST API with an
# owner's OAuth token, the same server-side access bootstrap_admin.sh uses.
# It touches the auth account only: the uid, the users/{uid} profile, the
# role and every movement already filed under that person are untouched.
#
# Usage:
#   ./tool/reset_password.sh <username> <new-password>
#
# Then hand the new password over directly and tell them to change it from
# the app's account menu.
#
# The password is passed as an argument and never written to disk here; clear
# it from your shell history afterwards if that matters to you.

set -euo pipefail

PROJECT_ID="kitagawa-inventory-app"
USERNAME_DOMAIN="kitagawa-inventory-app.app"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <username> <new-password>" >&2
  exit 64
fi

USERNAME="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
PASSWORD="$2"
EMAIL="${USERNAME}@${USERNAME_DOMAIN}"

if ! [[ "$USERNAME" =~ ^[a-z0-9._-]{3,24}$ ]]; then
  echo "Username must be 3-24 characters of a-z, 0-9, dot, dash, underscore" >&2
  exit 65
fi
if [ "${#PASSWORD}" -lt 6 ]; then
  echo "Password must be at least 6 characters (Firebase minimum)" >&2
  exit 65
fi

TOKEN="$(gcloud auth print-access-token)"
if [ -z "$TOKEN" ]; then
  echo "Could not get a gcloud access token. Run: gcloud auth login" >&2
  exit 69
fi

BASE="https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}"

echo "Looking up '${USERNAME}' (${EMAIL})…"

LOOKUP_RESPONSE="$(curl -sS -X POST "${BASE}/accounts:lookup" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-goog-user-project: ${PROJECT_ID}" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":[\"${EMAIL}\"]}")"

UID_VALUE="$(printf '%s' "$LOOKUP_RESPONSE" | python3 -c \
  'import json,sys; d=json.load(sys.stdin); u=d.get("users") or [{}]; print(u[0].get("localId",""))')"

if [ -z "$UID_VALUE" ]; then
  ERROR_MESSAGE="$(printf '%s' "$LOOKUP_RESPONSE" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("error",{}).get("message",""))')"
  if [ -z "$ERROR_MESSAGE" ]; then
    echo "No account exists for username '${USERNAME}'." >&2
    echo "Check the spelling on the app's Users tab." >&2
  else
    echo "Lookup failed: ${ERROR_MESSAGE}" >&2
  fi
  exit 70
fi

echo "uid: ${UID_VALUE}"

UPDATE_RESPONSE="$(curl -sS -X POST "${BASE}/accounts:update" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-goog-user-project: ${PROJECT_ID}" \
  -H 'Content-Type: application/json' \
  -d "{\"localId\":\"${UID_VALUE}\",\"password\":\"${PASSWORD}\"}")"

if printf '%s' "$UPDATE_RESPONSE" | grep -q '"error"'; then
  echo "Could not set the password:" >&2
  printf '%s\n' "$UPDATE_RESPONSE" >&2
  exit 71
fi

echo
echo "Done. '${USERNAME}' can sign in with the password you passed."
echo "Existing sessions on their device keep working until they sign out."
echo "Ask them to set their own password: account menu -> Change password."
