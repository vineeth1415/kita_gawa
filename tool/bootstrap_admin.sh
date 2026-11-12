#!/usr/bin/env bash
#
# Creates the first administrator for the kitagawa-inventory-app project.
#
# Why this script exists: security rules only let an admin create users, and
# an account's role lives in its users/{uid} document. So the very first admin
# cannot be made from inside the app — there is nobody yet allowed to make
# them. This script breaks that circle exactly once, using an owner's Google
# credentials:
#
#   * the auth account is created through the Identity Toolkit REST API
#   * the users/{uid} profile is written through the Firestore REST API with
#     an OAuth token, which is server-side access and legitimately bypasses
#     the security rules
#
# After this runs, every further account is created from the app's Users
# screen. Run it again only if you lose admin access entirely.
#
# Usage:
#   ./tool/bootstrap_admin.sh <username> <password> ["Display Name"]
#
# The password is passed as an argument and never written to disk here; clear
# it from your shell history afterwards if that matters to you.

set -euo pipefail

PROJECT_ID="kitagawa-inventory-app"
API_KEY="AIzaSyDqHP62H-7Vv4xJRFK3WIzWIhnhZF_daKk"
USERNAME_DOMAIN="kitagawa-inventory-app.app"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <username> <password> [\"Display Name\"]" >&2
  exit 64
fi

USERNAME="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
PASSWORD="$2"
DISPLAY_NAME="${3:-Administrator}"
EMAIL="${USERNAME}@${USERNAME_DOMAIN}"

if ! [[ "$USERNAME" =~ ^[a-z0-9._-]{3,24}$ ]]; then
  echo "Username must be 3-24 characters of a-z, 0-9, dot, dash, underscore" >&2
  exit 65
fi
if [ "${#PASSWORD}" -lt 6 ]; then
  echo "Password must be at least 6 characters (Firebase minimum)" >&2
  exit 65
fi

echo "Creating admin '${USERNAME}' (${EMAIL}) in ${PROJECT_ID}…"

TOKEN="$(gcloud auth print-access-token)"
if [ -z "$TOKEN" ]; then
  echo "Could not get a gcloud access token. Run: gcloud auth login" >&2
  exit 69
fi

# 1. The auth account. If it already exists we sign in instead, so re-running
#    the script repairs a missing profile rather than failing outright.
SIGNUP_RESPONSE="$(curl -sS -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"returnSecureToken\":true}")"

UID_VALUE="$(printf '%s' "$SIGNUP_RESPONSE" | python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("localId",""))')"

if [ -z "$UID_VALUE" ]; then
  ERROR_MESSAGE="$(printf '%s' "$SIGNUP_RESPONSE" | python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("error",{}).get("message",""))')"

  if [ "$ERROR_MESSAGE" = "EMAIL_EXISTS" ]; then
    echo "Auth account already exists — signing in to recover its uid…"
    SIGNIN_RESPONSE="$(curl -sS -X POST \
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"returnSecureToken\":true}")"
    UID_VALUE="$(printf '%s' "$SIGNIN_RESPONSE" | python3 -c \
      'import json,sys; print(json.load(sys.stdin).get("localId",""))')"
    if [ -z "$UID_VALUE" ]; then
      echo "That username exists but the password did not match." >&2
      exit 70
    fi
  else
    echo "Could not create the auth account: ${ERROR_MESSAGE:-$SIGNUP_RESPONSE}" >&2
    exit 70
  fi
fi

echo "uid: ${UID_VALUE}"

# 2. The profile that grants the admin role. Written with an owner token, so
#    it goes in even though the rules would refuse an ordinary client.
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FIRESTORE_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${UID_VALUE}"

PROFILE_RESPONSE="$(curl -sS -X PATCH "$FIRESTORE_URL" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-goog-user-project: ${PROJECT_ID}" \
  -H 'Content-Type: application/json' \
  -d "{
    \"fields\": {
      \"username\":    {\"stringValue\": \"${USERNAME}\"},
      \"displayName\": {\"stringValue\": \"${DISPLAY_NAME}\"},
      \"role\":        {\"stringValue\": \"admin\"},
      \"active\":      {\"booleanValue\": true},
      \"createdAt\":   {\"timestampValue\": \"${NOW}\"},
      \"createdBy\":   {\"stringValue\": \"bootstrap\"}
    }
  }")"

if printf '%s' "$PROFILE_RESPONSE" | grep -q '"error"'; then
  echo "Could not write the user profile:" >&2
  printf '%s\n' "$PROFILE_RESPONSE" >&2
  exit 71
fi

echo
echo "Done. Sign in to the app with:"
echo "  username: ${USERNAME}"
echo "  password: (the one you passed)"
echo
echo "Create every other account from the app's Users tab."
