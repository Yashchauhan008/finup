#!/usr/bin/env bash
# Create a FinUp release keystore and print GitHub Actions secret values.
# Run once on your Mac. Keep the .jks file and passwords safe — never commit them.
set -euo pipefail

OUT_DIR="${1:-$HOME/finup-keys}"
KS="$OUT_DIR/finup-release.jks"
ALIAS="${FINUP_KEY_ALIAS:-finup}"

mkdir -p "$OUT_DIR"

if [ -f "$KS" ]; then
  echo "Keystore already exists: $KS"
  echo "Refusing to overwrite. Pass a different directory or delete the file first."
  exit 1
fi

echo "Creating release keystore at: $KS"
echo "You will be prompted for store + key passwords (use strong ones; save them)."
echo

keytool -genkeypair -v \
  -keystore "$KS" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=FinUp, OU=Mobile, O=FinUp, L=India, ST=India, C=IN"

echo
echo "======= Add these GitHub Actions secrets on the private finup repo ======="
echo
echo "FINUP_KEY_ALIAS"
echo "$ALIAS"
echo
echo "FINUP_STORE_PASSWORD"
echo "(the store password you just typed)"
echo
echo "FINUP_KEY_PASSWORD"
echo "(the key password you just typed — often same as store)"
echo
echo "FINUP_KEYSTORE_BASE64"
base64 < "$KS" | tr -d '\n'
echo
echo
echo "======= Keep a backup ======="
echo "File: $KS"
echo "Also back up the passwords offline. Losing this key means users cannot update without uninstalling."
echo
keytool -list -v -keystore "$KS" | grep -E 'Alias name:|SHA256:' || true
