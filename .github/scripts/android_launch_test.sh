#!/usr/bin/env bash
# Installs the APK on the running emulator, launches it and checks that:
#  1. the app keeps running for 20 seconds after launch (no launch crash), and
#  2. none of its audio players are still playing after pressing Home.
set -u
PKG=com.gemdrake.gemdrake_isles

# Every adb call has a time limit: if the emulator itself goes away, adb
# would otherwise wait for it forever.
ADB=$(command -v adb)
adb() { timeout 60 "$ADB" "$@"; }

adb install -r gemdrake-isles.apk || exit 1
adb logcat -c
adb logcat -b crash -c
# Stream the log while the app runs, so it survives if the emulator dies.
"$ADB" logcat -v time > logcat_live.txt 2>&1 &
adb shell am start -W -n "$PKG/.MainActivity"

lost() {
  echo "EMULATOR LOST (the emulator stopped responding, not an app crash)"
  echo "=== GAME, ADS, WEBVIEW AND CRASH LINES BEFORE IT WENT AWAY ==="
  grep -E "flutter|$PKG|Ads|WebView|chromium|FATAL|AndroidRuntime|lowmemorykiller|ANR" logcat_live.txt | tail -150
  echo "=== LAST 40 LOG LINES ==="
  tail -40 logcat_live.txt
  cp logcat_live.txt logcat.txt
  exit 1
}

# Check every 2 seconds that the app is still running.
for i in $(seq 1 10); do
  sleep 2
  adb shell true >/dev/null 2>&1 || lost
  if ! adb shell pidof "$PKG" >/dev/null; then
    echo "APP CRASHED after $((i * 2)) s"
    adb logcat -d -b crash
    grep -E "AndroidRuntime|flutter|$PKG" logcat_live.txt | tail -150
    exit 1
  fi
done
echo "App ran for 20 s"
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
