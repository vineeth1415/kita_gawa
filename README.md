# Kitagawa Inventory — Stock Movement

Multi-user stock movement app for Kitagawa India. Flutter (Android) on
Firebase project **`kitagawa-inventory-app`**: Firestore is the primary datastore and
Firebase Auth handles sign-in, so several people work against one shared set
of figures from their own devices.

## Roles

| Role | Can do |
|---|---|
| **Front Office** | Record stock coming **in**, at any time — open day or not |
| **Back Office** | **Dispatch** stock (needs an open day), open and close the day |
| **Auditor** | Verify physical stock against the system, when an admin enables it |
| **Administrator** | Manage items, users, and the stock-verification setting |

Every stock movement carries a **reference number**: alphanumeric, 4–16
characters, uppercased. The rule is defined once in
[`lib/utils/validators.dart`](lib/utils/validators.dart) and enforced again
server-side in [`firestore.rules`](firestore.rules).

## The day

The back office opens the day and closes it. Closing aggregates every movement
filed under that date and writes a **sealed report** — `shiftReports/<date>`
plus a `lines` subcollection with a per-item opening/closing snapshot for the
whole catalogue, not just the items that moved. Reports cannot be edited or
deleted; the rules deny it.

Front-office inward entries do **not** wait for the day to open. They carry the
business date and are swept into that day's report at close. An entry filed
against a day whose report is already sealed is flagged `lateEntry` and
surfaces on the next report rather than altering the sealed one.

The business date always comes from the device's **local** clock, never the
server timestamp — the database is in the `nam5` US multi-region and stamps
UTC. See [`lib/utils/business_date.dart`](lib/utils/business_date.dart).

## Running it

```bash
flutter pub get
flutter run
```

Sign in with a username and password. Usernames map to synthetic addresses
(`<username>@kitagawa-inventory-app.app`) so warehouse staff need no real mailbox.

### First administrator

Security rules only let an admin create users, so the first one is made
outside the app, once:

```bash
./tool/bootstrap_admin.sh <username> <password> "Display Name"
```

It creates the auth account and writes `users/{uid}` with `role: admin` using
your own Google credentials. Every account after that is created from the
app's **Users** tab.

### Passwords

Anyone signed in can change their own password from the account menu in the
app bar. Nobody can set someone *else's* from inside the app — the synthetic
`@kitagawa-inventory-app.app` addresses receive no mail and rewriting another account
needs the Admin SDK — so a forgotten password is reset out of band:

```bash
./tool/reset_password.sh <username> <new-password>
```

### Deactivating someone

Admin → **Users** → the switch on their row. Accounts are deactivated, never
deleted, because movements are attributed by uid and sealed reports must keep
resolving. `active: false` is the field every security rule checks, and the
app watches the profile live, so access disappears on their device within
seconds rather than at their next sign-in.

## Tests

```bash
flutter test                                       # unit + repository + widget
firebase emulators:exec --only firestore \
  --project kitagawa-rules-test "cd tool/rules-test && npm test"
```

The Dart tests cover reference-number validation, business-date arithmetic
across midnight, the stock transaction, and day-close report generation
(against `fake_cloud_firestore`). The Node suite asserts the security rules
themselves — that a front-office account cannot dispatch, a back-office
account cannot post inward, the ledger cannot be rewritten, and the auditor is
locked out while verification is switched off.

Run `npm install` in `tool/rules-test` first.

## Shipping a build

Every push to `main` builds a signed release APK and publishes it to Firebase
App Distribution — `.github/workflows/distribute-android.yml`, gated on
`flutter analyze` and `flutter test`. Testers install the update in place.

The one-time setup (upload keystore, service account, tester group, repository
secrets) is in [docs/operations.md](docs/operations.md#continuous-delivery).
Release signing reads `android/key.properties`, which CI writes from secrets
and which is never committed; without it a local `flutter build apk --release`
falls back to debug signing as before.

## Deploying rules and indexes

```bash
firebase deploy --only firestore --project kitagawa-inventory-app
```

## Docs

- [docs/data-model.md](docs/data-model.md) — every Firestore collection, field
  by field, and the indexes that serve them
- [docs/roles-and-permissions.md](docs/roles-and-permissions.md) — what each
  role can do, the deliberate front/back office asymmetry, and two documented
  limitations of the rules
- [docs/operations.md](docs/operations.md) — provisioning, adding staff,
  deploying rules, and the failure modes hit so far
- [CLAUDE.md](CLAUDE.md) — architecture and invariants, for anyone (or any
  agent) changing the code

## Notes

- Firestore's offline cache is what makes the app usable on a patchy warehouse
  network; there is no separate local database.
- The theme is light-only on purpose: `assets/logo.jpeg` has an opaque white
  background, so a dark surface would render it as a white rectangle. A
  transparent PNG or SVG would make dark mode a small follow-up.
