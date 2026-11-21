# FinUp – Codebase & Build Setup

FinUp is a private, offline-first expense manager built with Flutter (Android).
Data lives on the phone by default. Optional cloud sync uses
`https://api.finup.yashchauhan.pro` so the same account works on FinUp web
(`finup-frontend`) with 2-way revision-based sync.

## How the repository works

The GitHub repository contains only:

| File | Purpose |
|---|---|
| `.github/workflows/build.yml` | Cloud build: generates the project, builds the APK, publishes a Release |
| `finup.sh` | Part 1: theme, database, accounts, onboarding |
| `finup2.sh` | Part 2: logo, SMS engine, entries, activity, review, reminders |
| `finup3.sh` | Part 3: dashboard, insights, budgets, goals |
| `finup4.sh` | Part 4: people ledger, app lock, backup, legal pages, docs |
| `scripts/make-release-keystore.sh` | Creates a release keystore and prints GitHub Secrets values |
| Signing | Via Actions secrets `FINUP_KEYSTORE_BASE64` + passwords (never commit the keystore) |

The scripts write the full Flutter project into `app/`. The workflow then runs
`flutter create` to add standard Android files, generates the launcher icons,
and builds `FinUp.apk`. Each release also contains `FinUp-source.zip`, which is
the complete, ready-to-open Flutter project (this file is inside it).

## Build an APK (no local install needed)

1. One-time: run `bash scripts/make-release-keystore.sh` and add the printed values as GitHub Actions secrets.
2. Push changes to GitHub.
3. GitHub → **Actions** → **Build FinUp** → **Run workflow**.
4. After about 10 minutes: **Releases** → latest build → download `FinUp.apk`.
5. Install it over the previous version. Data is kept only if the **same** release keystore signs every build.

If you switch from the old debug keystore to a real release keystore, uninstall the old app once (or accept a fresh install). After that, keep the same key forever.

## Build locally (optional)

Requirements: Flutter (stable), Android SDK, JDK 17.

```bash
unzip FinUp-source.zip -d finup && cd finup
flutter pub get
flutter run            # debug on a connected phone
flutter build apk      # release APK in build/app/outputs/flutter-apk/
```

## Project structure (`lib/`)

| Path | What it does |
|---|---|
| `main.dart` | App start, providers, theme, app lock gate |
| `theme.dart` | Colours, light/dark themes, fonts, `inr()` formatter |
| `native.dart` | Bridge to Kotlin: SMS, permissions, reminders, fingerprint, files, sharing |
| `data/db.dart` | SQLite schema, models (Account, Category, Txn) |
| `data/repo.dart` | Transactions, balances, rules, categories |
| `data/stats.dart` | Monthly totals, category totals, budgets, goals |
| `data/people_repo.dart` | People, ledger entries, auto-linking UPI IDs |
| `data/backup.dart` | JSON backup/restore, CSV export, wipe |
| `sms/parser.dart` | Bank SMS parser (Bank of Baroda format and generic patterns) |
| `sms/sync.dart` | Imports new SMS, de-duplicates by Ref number, updates balances |
| `state/` | `SettingsState`, `AccountsState`, `TxnState` (ChangeNotifiers) |
| `security/lock.dart` | PIN + fingerprint lock screen |
| `screens/` | All screens |
| `widgets/` | Shared widgets, charts, logo |

Native Android code lives in `android/app/src/main/kotlin/com/yash/finup/`:
`MainActivity.kt` (method channel `finup/native`) and `Reminder.kt` (daily notification).

## Adding support for another bank

Edit `lib/sms/parser.dart`:
- `_bankName()` maps the SMS sender ID to a bank name.
- The regexes `_amount`, `_drcr`, `_acct`, `_vpa`, `_ref`, `_bal`, `_date` extract the fields.
Then rebuild.

## Updates (Part 5) — browser download only

- Builds are numbered with the GitHub run number (`--build-number`), so each build is newer than the last.
- The workflow publishes `FinUp.apk` to the **public** repo `Yashchauhan008/finup-releases` using the secret `RELEASES_TOKEN`.
- The app reads `https://api.github.com/repos/Yashchauhan008/finup-releases/releases/latest`,
  compares the tag with its version code, then opens the release/APK URL in the **browser**.
- FinUp does **not** use `REQUEST_INSTALL_PACKAGES` or PackageInstaller (Play Protect).
- When running the workflow, fill in **What's new**. It is shown on the in-app update screen.

### One-time setup
1. Create the public repo `finup-releases` (with a README so it is not empty).
2. Create a fine-grained token with **Contents: Read and write** on that repo only.
3. Add it to the private `finup` repo as the Actions secret `RELEASES_TOKEN`.
4. Add release signing secrets (see `scripts/make-release-keystore.sh`):
   `FINUP_KEYSTORE_BASE64`, `FINUP_STORE_PASSWORD`, `FINUP_KEY_PASSWORD`, `FINUP_KEY_ALIAS`.

## Native files (Part 5)
- `Alerts.kt`: SMS receiver, native SMS parser, category suggestions, notification buttons.
- `Reminder.kt`: exact daily reminder with the pending count.
- `MainActivity.kt`: method channel, files, sharing, fingerprint (no APK installer).
