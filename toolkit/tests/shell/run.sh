#!/usr/bin/env bash
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"
rc=0
for t in test_*.sh; do
  echo "== $t"
  bash "$t" || rc=1
done
exit $rc
