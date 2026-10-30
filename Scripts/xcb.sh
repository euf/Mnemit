#!/bin/bash
# Usage: Scripts/xcb.sh <log file> <xcodebuild args...>
# Runs one xcodebuild at a time across all agents (mkdir lock), output to the log; prints the summary lines.
LOCK="${XCB_LOCK:-$HOME/Library/Caches/mnemit-xcb.lock}"
log="$1"; shift
until mkdir "$LOCK" 2>/dev/null; do
  # A lock whose holder is gone is stale.
  pid=$(cat "$LOCK/pid" 2>/dev/null); if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -rf "$LOCK"; fi
  /bin/sleep 5
done
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT
xcodebuild "$@" > "$log" 2>&1
rc=$?
grep -E "Test run with|TEST (SUCCEEDED|FAILED)|BUILD (SUCCEEDED|FAILED)|error:|recorded an issue" "$log" | grep -v '^ *|' | head -40
echo "xcodebuild rc=$rc"
exit $rc
