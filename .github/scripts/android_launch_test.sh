#!/usr/bin/env bash
# Installs the APK on the running emulator, launches it and checks that:
#  1. the app is still running after 30 seconds (no launch crash), and
#  2. none of its audio players are still playing after pressing Home.
set -u
PKG=com.gemdrake.gemdrake_isles

adb install -r gemdrake-isles.apk || exit 1
adb logcat -c
adb logcat -b crash -c
adb shell am start -W -n "$PKG/.MainActivity"
sleep 30
adb logcat -d > logcat.txt
adb logcat -d -b crash > crash.txt
adb exec-out screencap -p > screen.png

echo "=== CRASH BUFFER ==="
cat crash.txt
echo "=== APP LINES ==="
grep -E "AndroidRuntime|DEBUG|flutter|$PKG|audioplayers" logcat.txt | grep -v "Access denied" | tail -150

if ! adb shell pidof "$PKG"; then
  echo "APP CRASHED"
  exit 1
fi
echo "APP IS RUNNING"

uid=$(adb shell cmd package list packages -U "$PKG" | grep -o 'uid:[0-9]*' | head -1 | cut -d: -f2 | tr -d '\r')
echo "app uid: $uid"
players() { adb shell dumpsys audio | grep -E "u/pid:$uid/" ; }
echo "=== AUDIO PLAYERS WHILE OPEN ==="
players | head -20
adb shell input keyevent KEYCODE_HOME
sleep 5
echo "=== AUDIO PLAYERS AFTER HOME ==="
players | head -20
if [ -z "$uid" ]; then
  echo "AUDIO CHECK SKIPPED (uid not found)"
elif players | grep -q "state:started"; then
  echo "AUDIO STILL PLAYING AFTER HOME"
  exit 1
else
  echo "AUDIO SILENT AFTER HOME"
fi
