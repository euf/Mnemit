#!/bin/bash
# Compiles the app's FSRS.swift unmodified with main.swift (stubs for Grade / InitialStability inside) and runs it.
set -e
D=$(cd "$(dirname "$0")" && pwd)
swiftc -O -o "$D/sim" "$HOME/Code/Mnemit/Packages/VocabCore/Sources/VocabCore/Scheduling/FSRS.swift" "$D/main.swift" 2>&1 | head -30
"$D/sim"
