#!/bin/bash
# Shell test harness for night_light.sh. No framework; fixture-backed stubs.
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
tests="$repo/tests"
fixtures="$tests/fixtures"
base=/tmp/opencode/night_light-tests

selected=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --case)
      selected+=("$2")
      shift 2
      ;;
    *)
      echo "usage: $0 [--case name]..." >&2
      exit 2
      ;;
  esac
done

mkdir -p "$base"
CASE_HOME=""
LAST_RC=0
pass=0
fail=0
failed=()

should_run() {
  local name=$1
  if [[ ${#selected[@]} -eq 0 ]]; then
    return 0
  fi
  local candidate
  for candidate in "${selected[@]}"; do
    [[ $candidate == "$name" ]] && return 0
  done
  return 1
}

make_home() {
  local name=$1 seed=$2 config=${3:-$fixtures/config}
  local home="$base/$name"

  rm -rf "$home"
  mkdir -p "$home/.night_light" "$home/state"
  cp "$config" "$home/.night_light/.night_light_config"
  echo "$seed" > "$home/state/color-scheme"
  : > "$home/curl.log"
  : > "$home/lynx.log"
  : > "$home/gsettings.log"
  CASE_HOME=$home
}

run_case() {
  local name=$1 fake=$2 seed=$3 mode=${4:-} config=${5:-$fixtures/config} keep=${6:-}
  local home="$base/$name"

  if [[ $keep != keep ]]; then
    make_home "$name" "$seed" "$config"
  fi
  CASE_HOME=$home

  timeout 1 env HOME="$home" PATH="$tests/bin:$PATH" FIXTURES="$fixtures" \
    FAKE_NOW="$fake" FIXTURE_MODE="$mode" CURL_FAIL_MATCH="${CURL_FAIL_MATCH:-}" \
    CURL_LOG="$home/curl.log" LYNX_LOG="$home/lynx.log" \
    GS_STATE="$home/state" GS_LOG="$home/gsettings.log" \
    bash "$repo/night_light.sh" -ar > "$home/out.log" 2> "$home/err.log"
  LAST_RC=$?
}

assert_contains() {
  local file=$1 text=$2
  if grep -Fq -- "$text" "$file" 2>/dev/null; then
    return 0
  fi
  echo "  missing in $(basename "$file"): $text" >&2
  return 1
}

assert_not_contains() {
  local file=$1 text=$2
  if grep -Fq -- "$text" "$file" 2>/dev/null; then
    echo "  unexpected in $(basename "$file"): $text" >&2
    return 1
  fi
  return 0
}

assert_empty() {
  local file=$1
  if [[ -s $file ]]; then
    echo "  expected empty: $(basename "$file")" >&2
    return 1
  fi
  return 0
}

test_uses_sunrise_api() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/curl.log" "api.met.no/weatherapi/sunrise/3.0/sun" || return 1
  assert_contains "$CASE_HOME/curl.log" "date=2026-11-04" || return 1
}

test_uses_forecast_api() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/curl.log" "api.met.no/weatherapi/locationforecast/2.0/complete" || return 1
}

test_schedule_from_api() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-to 7.900000000" || return 1
}

test_no_lynx() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_empty "$CASE_HOME/lynx.log" || return 1
}

test_polar_null() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" polar
  assert_not_contains "$CASE_HOME/gsettings.log" "color-scheme" || return 1
  assert_contains "$CASE_HOME/.night_light/night_light.log" "sun times unavailable" || return 1
  if [[ $LAST_RC -ne 124 ]]; then
    echo "  expected the script to stay alive, rc=$LAST_RC" >&2
    return 1
  fi
}

test_cache_ttl() {
  local fake count
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  count=$(grep -c 'sunrise/3.0/sun' "$CASE_HOME/curl.log" || true)
  if [[ $count -ne 1 ]]; then
    echo "  expected 1 sun request, got $count" >&2
    return 1
  fi
}

test_sun_failure_no_cache() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  local CURL_FAIL_MATCH=sunrise
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  assert_not_contains "$CASE_HOME/gsettings.log" "color-scheme" || return 1
  assert_contains "$CASE_HOME/.night_light/night_light.log" "sun times unavailable" || return 1
  if [[ $LAST_RC -ne 124 ]]; then
    echo "  expected the script to stay alive, rc=$LAST_RC" >&2
    return 1
  fi
}

test_corrupt_sun_cache() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  echo '{bad' > "$CASE_HOME/.night_light/met_sun.json"
  : > "$CASE_HOME/gsettings.log"
  : > "$CASE_HOME/curl.log"
  local CURL_FAIL_MATCH=sunrise
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_not_contains "$CASE_HOME/gsettings.log" "color-scheme" || return 1
  assert_contains "$CASE_HOME/.night_light/night_light.log" "sun times unavailable" || return 1
  if [[ $LAST_RC -ne 124 ]]; then
    echo "  expected the script to stay alive, rc=$LAST_RC" >&2
    return 1
  fi
}

test_sun_cache_date_rollover() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  make_home "$FUNCNAME" "'prefer-dark'"
  cp "$fixtures/sun.json" "$CASE_HOME/.night_light/met_sun.json"
  touch -d "@$((fake - 86400))" "$CASE_HOME/.night_light/met_sun.json"
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_contains "$CASE_HOME/curl.log" "sunrise/3.0/sun" || return 1
  assert_contains "$CASE_HOME/curl.log" "date=2026-11-04" || return 1
}

test_coordinates_truncated() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/curl.log" "lat=59.8765" || return 1
  assert_contains "$CASE_HOME/curl.log" "lon=8.5943" || return 1
}

all_tests=(
  test_uses_sunrise_api
  test_uses_forecast_api
  test_schedule_from_api
  test_no_lynx
  test_polar_null
  test_cache_ttl
  test_sun_failure_no_cache
  test_corrupt_sun_cache
  test_sun_cache_date_rollover
  test_coordinates_truncated
)

for name in "${all_tests[@]}"; do
  should_run "$name" || continue
  if "$name"; then
    echo "PASS $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name (script rc=$LAST_RC)"
    fail=$((fail + 1))
    failed+=("$name")
  fi
done

echo
echo "$pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  printf 'failed: %s\n' "${failed[*]}"
  exit 1
fi
