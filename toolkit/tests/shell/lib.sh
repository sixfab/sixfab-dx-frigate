#!/usr/bin/env bash
FAILS=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILS=$((FAILS+1)); }
assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected '$1', got '$2')"; fi
}
assert_file() { if [ -f "$1" ]; then pass "$2"; else fail "$2 (missing $1)"; fi; }
assert_no_file() { if [ ! -e "$1" ]; then pass "$2"; else fail "$2 (unexpected $1)"; fi; }
assert_fails() {
  local name="$1"; shift
  if ( "$@" ) >/dev/null 2>&1; then fail "$name (expected failure)"; else pass "$name"; fi
}
finish() { [ "$FAILS" -eq 0 ] && echo "ALL OK" || { echo "$FAILS failure(s)"; exit 1; }; }
