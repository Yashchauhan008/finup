#!/usr/bin/env bash
set -e
if [ -f android/app/build.gradle.kts ]; then
  if ! grep -q "text-recognition" android/app/build.gradle.kts; then
    printf '\ndependencies {\n    implementation("com.google.mlkit:text-recognition:16.0.0")\n}\n' >> android/app/build.gradle.kts
  fi
elif [ -f android/app/build.gradle ]; then
  if ! grep -q "text-recognition" android/app/build.gradle; then
    printf "\ndependencies {\n    implementation 'com.google.mlkit:text-recognition:16.0.0'\n}\n" >> android/app/build.gradle
  fi
fi
echo "ML Kit text recognition added."
