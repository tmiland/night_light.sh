#!/bin/bash
# Shell test harness for night_light.sh. No framework; fixture-backed stubs.
set -u
export TZ=Europe/Oslo
export LC_ALL=C

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
  : > "$home/sleep.log"
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
    TZ="$TZ" LC_ALL="${CASE_LC_ALL:-C}" \
    FAKE_NOW="$fake" FIXTURE_MODE="$mode" CURL_FAIL_MATCH="${CURL_FAIL_MATCH:-}" \
    CURL_FAIL_ONCE="${CURL_FAIL_ONCE:-}" CURL_EMPTY_MATCH="${CURL_EMPTY_MATCH:-}" \
    CURL_304="${CURL_304:-}" \
    CURL_LOG="$home/curl.log" LYNX_LOG="$home/lynx.log" \
    SLEEP_LOG="$home/sleep.log" \
    GS_STATE="$home/state" GS_LOG="$home/gsettings.log" \
    bash "$repo/night_light.sh" -ar > "$home/out.log" 2> "$home/err.log"
  LAST_RC=$?
}

assert_alive() {
  if [[ $LAST_RC -ne 124 ]]; then
    echo "  expected the script to stay alive, rc=$LAST_RC" >&2
    return 1
  fi
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
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-to 8.900000000" || return 1
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
  rm -f "$CASE_HOME/.night_light/"met_sun.raw.*
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
  cat > "$CASE_HOME/.night_light/met_sun.json" <<'EOF'
{"date":"2026-11-03","lat":"59.8765","lon":"8.5943","sunrise":"2026-11-03T07:55+01:00","sunset":"2026-11-03T16:21+01:00"}
EOF
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_contains "$CASE_HOME/curl.log" "sunrise/3.0/sun" || return 1
  assert_contains "$CASE_HOME/curl.log" "date=2026-11-04" || return 1
  assert_alive || return 1
}

test_coordinates_truncated() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/curl.log" "lat=59.8765" || return 1
  assert_contains "$CASE_HOME/curl.log" "lon=8.5943" || return 1
}

test_cloud_uv_brightness() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5555" || return 1
}

test_missing_weather_fields() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" missing
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5750" || return 1
  assert_not_contains "$CASE_HOME/err.log" "syntax error" || return 1
  if [[ $LAST_RC -ne 124 ]]; then
    echo "  expected the script to stay alive, rc=$LAST_RC" >&2
    return 1
  fi
}

test_forecast_failure_fallback() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  touch -d "@$((fake - 3600))" "$CASE_HOME/.night_light/met_forecast.json"
  : > "$CASE_HOME/gsettings.log"
  : > "$CASE_HOME/curl.log"
  local CURL_FAIL_MATCH=complete
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5555" || return 1
  assert_not_contains "$CASE_HOME/err.log" "syntax error" || return 1
}

test_corrupt_forecast_cache() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  echo '{bad' > "$CASE_HOME/.night_light/met_forecast.json"
  touch -d "@$((fake - 3600))" "$CASE_HOME/.night_light/met_forecast.json"
  : > "$CASE_HOME/gsettings.log"
  : > "$CASE_HOME/curl.log"
  local CURL_FAIL_MATCH=complete
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5750" || return 1
  assert_not_contains "$CASE_HOME/err.log" "syntax error" || return 1
}

test_cloud_only() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" "" "$fixtures/config_cloud_only"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5650" || return 1
}

test_cloud_off_uv_on() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" "" "$fixtures/config_cloud_off_uv_on"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5750" || return 1
}

test_cc_off_uv_off() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" "" "$fixtures/config_cc_off_uv_off"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5750" || return 1
  assert_not_contains "$CASE_HOME/curl.log" "locationforecast/2.0/complete" || return 1
}

test_uv_extreme() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" alt
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5750" || return 1
}

test_yr_off() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" "" "$fixtures/config_yr0"
  assert_not_contains "$CASE_HOME/curl.log" "locationforecast/2.0/complete" || return 1
  assert_contains "$CASE_HOME/curl.log" "sunrise/3.0/sun" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "color-scheme prefer-light" || return 1
}

test_unit_self_heal() {
  grep -Fq 'while true; do' "$repo/night_light.service" &&
    grep -Fq -- '-ar; echo night_light exited; sleep 5; done' "$repo/night_light.service"
}

test_unit_startup_ordering() {
  grep -Fq 'WantedBy=graphical-session.target' "$repo/night_light.service" &&
    grep -Fq 'After=graphical-session.target' "$repo/night_light.service" &&
    grep -Fq 'PartOf=graphical-session.target' "$repo/night_light.service" &&
    grep -Fq 'After=graphical-session.target' "$repo/night_light.timer" &&
    grep -Fq 'PartOf=graphical-session.target' "$repo/night_light.timer"
}

test_branch_matrix() {
  local expected actual

  run_case matrix_0800 "$(date -d '2026-11-04 08:00' +%s)" "'prefer-dark'"
  expected="'prefer-dark'"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  08:00 expected $expected, got $actual" >&2; return 1; }

  run_case matrix_0825 "$(date -d '2026-11-04 08:25' +%s)" "'prefer-dark'"
  expected="'prefer-dark'"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  08:25 expected $expected, got $actual" >&2; return 1; }

  run_case matrix_0900 "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  expected="prefer-light"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  09:00 expected $expected, got $actual" >&2; return 1; }

  run_case matrix_1500 "$(date -d '2026-11-04 15:00' +%s)" "'prefer-light'"
  expected="'prefer-light'"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  15:00 expected $expected, got $actual" >&2; return 1; }

  run_case matrix_1553 "$(date -d '2026-11-04 15:53' +%s)" "'prefer-light'"
  expected="prefer-dark"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  15:53 expected $expected, got $actual" >&2; return 1; }

  run_case matrix_2000 "$(date -d '2026-11-04 20:00' +%s)" "'prefer-light'"
  expected="prefer-dark"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  20:00 expected $expected, got $actual" >&2; return 1; }

  run_case matrix_0030 "$(date -d '2026-11-04 00:30' +%s)" "'prefer-light'"
  expected="prefer-dark"
  actual=$(cat "$CASE_HOME/state/color-scheme")
  [[ $actual == "$expected" ]] || { echo "  00:30 expected $expected, got $actual" >&2; return 1; }
}

test_coordinates_locale() {
  local CASE_LC_ALL=nb_NO.utf8
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/curl.log" "lat=59.8765" || return 1
  assert_not_contains "$CASE_HOME/curl.log" "lat=59,8765" || return 1
  if ! jq -e . "$CASE_HOME/.night_light/location.json" >/dev/null 2>&1; then
    echo "  location.json is not valid JSON" >&2
    return 1
  fi
  assert_alive || return 1
}

test_sun_location_change() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  : > "$CASE_HOME/curl.log"
  cp "$fixtures/config_location2" "$CASE_HOME/.night_light/.night_light_config"
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" location2 "" keep
  assert_contains "$CASE_HOME/curl.log" "locations/1-12345" || return 1
  assert_contains "$CASE_HOME/curl.log" "lat=60.0000" || return 1
  assert_contains "$CASE_HOME/curl.log" "lon=9.0000" || return 1
  assert_alive || return 1
}

test_location_retry() {
  local CURL_FAIL_ONCE=locations count
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/gsettings.log" "color-scheme prefer-light" || return 1
  count=$(grep -c '/locations/' "$CASE_HOME/curl.log" || true)
  if [[ $count -lt 2 ]]; then
    echo "  expected a location retry, got $count request(s)" >&2
    return 1
  fi
  assert_alive || return 1
}

test_failure_backoff() {
  local fake count
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  touch -d "@$((fake - 3600))" "$CASE_HOME/.night_light/met_forecast.json"
  : > "$CASE_HOME/gsettings.log"
  : > "$CASE_HOME/curl.log"
  local CURL_FAIL_MATCH=complete
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  count=$(grep -c 'locationforecast/2.0/complete' "$CASE_HOME/curl.log" || true)
  if [[ $count -ne 1 ]]; then
    echo "  expected 1 forecast request during backoff, got $count" >&2
    return 1
  fi
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5555" || return 1
  assert_alive || return 1
}

test_empty_200_keeps_cache() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  touch -d "@$((fake - 3600))" "$CASE_HOME/.night_light/met_forecast.json"
  : > "$CASE_HOME/gsettings.log"
  : > "$CASE_HOME/curl.log"
  local CURL_EMPTY_MATCH=complete
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5555" || return 1
  assert_alive || return 1
}

test_304_keeps_cache() {
  local fake
  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'"
  touch -d "@$((fake - 3600))" "$CASE_HOME/.night_light/met_forecast.json"
  : > "$CASE_HOME/gsettings.log"
  : > "$CASE_HOME/curl.log"
  local CURL_304=1
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" "" "" keep
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5555" || return 1
  assert_alive || return 1
}

test_dst_schedule() {
  local fake
  fake=$(TZ=Europe/Oslo date -d '2026-03-29 09:00' +%s)
  run_case "$FUNCNAME" "$fake" "'prefer-dark'" dst
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-to 8.083333333" || return 1
  assert_alive || return 1
}

test_uv_zero() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'" uv0
  assert_contains "$CASE_HOME/gsettings.log" "night-light-temperature 5650" || return 1
  assert_alive || return 1
}

test_full_ramp_light() {
  local fake
  fake=$(date -d '2026-11-04 08:53:59' +%s)
  run_case full_ramp_light_before "$fake" "'prefer-dark'"
  if [[ $(cat "$CASE_HOME/state/color-scheme") != "'prefer-dark'" ]]; then
    echo "  08:53:59 should still be dark" >&2
    return 1
  fi

  fake=$(date -d '2026-11-04 08:54:01' +%s)
  run_case full_ramp_light_after "$fake" "'prefer-dark'"
  if [[ $(cat "$CASE_HOME/state/color-scheme") != "prefer-light" ]]; then
    echo "  08:54:01 should be light" >&2
    return 1
  fi
  assert_alive || return 1
}

test_full_ramp_dark() {
  local fake
  fake=$(date -d '2026-11-04 15:21:59' +%s)
  run_case full_ramp_dark_before "$fake" "'prefer-light'"
  if [[ $(cat "$CASE_HOME/state/color-scheme") != "'prefer-light'" ]]; then
    echo "  15:21:59 should still be light" >&2
    return 1
  fi

  fake=$(date -d '2026-11-04 15:22:01' +%s)
  run_case full_ramp_dark_after "$fake" "'prefer-light'"
  if [[ $(cat "$CASE_HOME/state/color-scheme") != "prefer-dark" ]]; then
    echo "  15:22:01 should be dark" >&2
    return 1
  fi
  assert_alive || return 1
}

test_full_ramp_schedule() {
  local fake
  fake=$(date -d '2026-11-04 15:22:01' +%s)
  run_case full_ramp_schedule_dark "$fake" "'prefer-light'"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-from 15.366666666" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-to 8.900000000" || return 1

  fake=$(date -d '2026-11-04 09:00' +%s)
  run_case full_ramp_schedule_light "$fake" "'prefer-dark'"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-to 8.900000000" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-from 15.366666666" || return 1
  assert_alive || return 1
}

test_full_ramp_startup_sync() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 16:30' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-from 15.366666666" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "night-light-schedule-to 8.900000000" || return 1
  assert_alive || return 1
}

test_startup_grace() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 20:30' +%s)" "'prefer-light'"
  local first
  first=$(head -1 "$CASE_HOME/sleep.log" 2>/dev/null)
  if [[ $first != 5 ]]; then
    echo "  expected first sleep 5, got ${first:-empty}" >&2
    return 1
  fi
  assert_contains "$CASE_HOME/gsettings.log" "color-scheme prefer-dark" || return 1
  assert_alive || return 1
}

test_mode_change_log() {
  run_case "$FUNCNAME" "$(date -d '2026-11-04 20:30' +%s)" "'prefer-light'"
  assert_contains "$CASE_HOME/.night_light/night_light.log" "color scheme dark" || return 1
  assert_alive || return 1
}

test_dnd_sound_toggle() {
  run_case dnd_dark "$(date -d '2026-11-04 20:30' +%s)" "'prefer-light'"
  assert_contains "$CASE_HOME/gsettings.log" "show-banners false" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "event-sounds false" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "color-scheme prefer-dark" || return 1
  assert_alive || return 1

  run_case dnd_light "$(date -d '2026-11-04 09:00' +%s)" "'prefer-dark'"
  assert_contains "$CASE_HOME/gsettings.log" "show-banners true" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "event-sounds true" || return 1
  assert_contains "$CASE_HOME/gsettings.log" "color-scheme prefer-light" || return 1
  assert_alive || return 1
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
  test_cloud_uv_brightness
  test_missing_weather_fields
  test_forecast_failure_fallback
  test_corrupt_forecast_cache
  test_cloud_only
  test_cloud_off_uv_on
  test_cc_off_uv_off
  test_uv_extreme
  test_yr_off
  test_unit_self_heal
  test_unit_startup_ordering
  test_branch_matrix
  test_coordinates_locale
  test_sun_location_change
  test_location_retry
  test_failure_backoff
  test_empty_200_keeps_cache
  test_304_keeps_cache
  test_dst_schedule
  test_uv_zero
  test_full_ramp_light
  test_full_ramp_dark
  test_full_ramp_schedule
  test_full_ramp_startup_sync
  test_startup_grace
  test_mode_change_log
  test_dnd_sound_toggle
)

for name in "${all_tests[@]}"; do
  should_run "$name" || continue
  if "$name"; then
    if [[ $name != test_unit_self_heal && $name != test_unit_startup_ordering && $LAST_RC -ne 124 ]]; then
      echo "FAIL $name (script exited, rc=$LAST_RC)"
      fail=$((fail + 1))
      failed+=("$name")
    else
      echo "PASS $name"
      pass=$((pass + 1))
    fi
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
