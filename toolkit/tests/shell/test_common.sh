#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
export PYTHON="${PYTHON:-python3}" SIXFAB_TEST=1
. "$ROOT/common.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

export ASK_FROM_STDIN=1
assert_eq "hello" "$(echo hello | ask 'q: ' 2>/dev/null)" "ask reads stdin"
assert_eq "dflt" "$(echo | ask 'q: ' dflt 2>/dev/null)" "ask empty answer uses default"
unset ASK_FROM_STDIN

ASSUME_YES=1 confirm "ok?" && pass "confirm with ASSUME_YES" || fail "confirm with ASSUME_YES"
( export ASK_FROM_STDIN=1; echo y | confirm "ok?" 2>/dev/null ) && pass "confirm y" || fail "confirm y"
( export ASK_FROM_STDIN=1; echo n | confirm "ok?" 2>/dev/null ) && fail "confirm n" || pass "confirm n"

assert_eq "DRY: echo hi" "$(DRY_RUN=1 run echo hi)" "run prints in dry-run"
assert_eq "hi" "$(run echo hi)" "run executes normally"

cat > "$T/models.txt" <<'EOT'
# TAG: demo-v1.0.0
# comment line
a.dxnn  model/a.dxnn  abc123
v.mp4   demo/v.mp4    def456  optional
EOT
assert_eq "demo-v1.0.0" "$(models_tag "$T/models.txt")" "models_tag"
assert_eq "2" "$(models_rows "$T/models.txt" | wc -l | tr -d ' ')" "models_rows skips comments"
assert_eq "v.mp4|demo/v.mp4|def456|optional" "$(models_rows "$T/models.txt" | tail -1 | tr '\t' '|')" "models_rows fields"
assert_eq "https://github.com/o/r/releases/download/t1/f.bin" "$(RELEASE_REPO=o/r release_url t1 f.bin)" "release_url default"
assert_eq "file:///x/t1/f.bin" "$(RELEASE_BASE_URL=file:///x release_url t1 f.bin)" "release_url override"

mkdir -p "$T/rel/demo-v1.0.0" "$T/app"
printf 'MODEL' > "$T/rel/demo-v1.0.0/a.dxnn"
printf 'VIDEO' > "$T/rel/demo-v1.0.0/v.mp4"
SHA_A="$(sha256sum "$T/rel/demo-v1.0.0/a.dxnn" | cut -d' ' -f1)"
SHA_V="$(sha256sum "$T/rel/demo-v1.0.0/v.mp4" | cut -d' ' -f1)"
printf '# TAG: demo-v1.0.0\na.dxnn  model/a.dxnn  %s\nv.mp4  demo/v.mp4  %s  optional\n' "$SHA_A" "$SHA_V" > "$T/app/models.txt"
export RELEASE_BASE_URL="file:///$(cygpath -m "$T" 2>/dev/null || echo "${T#/}")/rel"
fetch_assets "$T/app" 0 >/dev/null
assert_file "$T/app/model/a.dxnn" "fetch required asset"
assert_no_file "$T/app/demo/v.mp4" "optional asset skipped"
fetch_assets "$T/app" 1 >/dev/null
assert_file "$T/app/demo/v.mp4" "optional asset fetched on request"
touch -d '@978307200' "$T/app/model/a.dxnn"
fetch_assets "$T/app" 0 >/dev/null
assert_eq "978307200" "$(stat -c %Y "$T/app/model/a.dxnn")" "fetch skips file with matching sha"

rm -rf "$T/app/model"
printf '# TAG: demo-v1.0.0\na.dxnn  model/a.dxnn  %s\n' "0000" > "$T/app/models.txt"
assert_fails "fetch fails on sha mismatch" fetch_assets "$T/app" 0
assert_no_file "$T/app/model/a.dxnn" "test_fetch_sha_mismatch_removes_file"
assert_no_file "$T/app/model/a.dxnn.part" "no .part left behind"

finish
