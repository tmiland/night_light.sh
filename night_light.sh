#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053,SC2034,SC1090

## Author: Tommy Miland (@tmiland) - Copyright (c) 2026


######################################################################
####                       night_light.sh                         ####
####            Automatic night light script for gnome            ####
####            Script to adjust night light in gnome             ####
####                   Maintained by @tmiland                     ####
######################################################################

VERSION='1.0.6'

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2026 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#
## Uncomment for debugging purpose
if [[ $2 == "debug" ]]
then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi
# Symlink: ln -sfn ~/.scripts/night_light.sh ~/.local/bin/night_light.sh
# Crontab: 1 1 * * * bash ~/.scripts/night_light.sh > /dev/null 2>&1
# Based on source: https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2
config_folder=$HOME/.night_light
cfg_sh_file=$config_folder/night_light_config.sh
cfg_file=$config_folder/.night_light_config
if ! [ -d "$config_folder" ]
then
  mkdir -p "$config_folder"
fi
# Read hidden configuration file with entries separated by " " into array
if [[ -f $cfg_file ]]
then
  IFS=' ' read -ra cfg_array < "$cfg_file"
  # Day time maximum display brightness
  max_bright="${cfg_array[0]}"
  # Transition minutes after sunrise to maximum
  after_sunrise="${cfg_array[1]}"
  # Night time minimum display brightness
  min_bright="${cfg_array[2]}"
  # Transition minutes before sunset to minimum
  before_sunset="${cfg_array[3]}"
  # Cloud cover
  cc="${cfg_array[4]}"
  # UV Index
  uv="${cfg_array[5]}"
  # Color scheme
  cs="${cfg_array[6]}"
  # yr.no
  yr="${cfg_array[7]}"
  # yr.no location (E.g: /1-68562/Norway/Telemark/Tinn/Rjukan)
  yr_location="${cfg_array[8]}"
  # Time format
  time_format="${cfg_array[9]}"
else
  # Day time maximum display brightness
  max_bright=5750
  # Transition minutes after sunrise to maximum
  after_sunrise=90
  # Night time minimum display brightness
  min_bright=2350
  # Transition minutes before sunset to minimum
  before_sunset=90
  # Cloud cover
  cc=1
  # UV Index
  uv=1
  # Change color scheme
  cs=1
  # yr.no
  yr=0
  # yr.no location
  yr_location="/1-68562/Norway/Telemark/Tinn/Rjukan"
  # Time format
  time_format=24
fi

# Defaults for optional yr.no-derived values
cloud_cover=0
uv_scale=0

# MET Norway API settings
MET_UA="night_light.sh/${VERSION} (https://github.com/tmiland/night_light.sh)"
met_sun_cache="$config_folder/met_sun.json"
met_forecast_cache="$config_folder/met_forecast.json"
location_cache="$config_folder/location.json"

log() {
  local message=$1
  local log_file="$config_folder/night_light.log"
  if [[ -f $log_file ]] && [[ $(stat -c%s "$log_file") -gt 1048576 ]]; then
    mv "$log_file" "$log_file.1"
  fi
  printf '%s %s\n' "$(date '+%F %T')" "$message" >> "$log_file"
}

fetch_json() {
  local url=$1 cache=$2 max_age=$3
  local tmp="${cache}.tmp.$$" attempt="${cache}.attempt"
  local http_code=""

  if [[ -f $cache ]]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
    if (( age < max_age )); then
      return 0
    fi
  fi

  if [[ -f $attempt ]]; then
    local retry_age=$(( $(date +%s) - $(stat -c %Y "$attempt") ))
    if (( retry_age < 900 )); then
      return 1
    fi
  fi

  http_code=$(curl --silent --show-error --fail --compressed --max-time 20 \
      --retry 2 --retry-delay 2 -H "User-Agent: $MET_UA" \
      -z "$cache" -o "$tmp" -w '%{http_code}' "$url") || true

  case $http_code in
    200)
      if [[ -s $tmp ]] && jq -e . "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$cache"
        rm -f "$attempt"
        return 0
      fi
      rm -f "$tmp"
      log "invalid response: $url"
      date +%s > "$attempt"
      return 1
      ;;
    304)
      rm -f "$tmp"
      if [[ -f $cache ]]; then
        touch "$cache"
        rm -f "$attempt"
        return 0
      fi
      date +%s > "$attempt"
      return 1
      ;;
    *)
      rm -f "$tmp"
      log "fetch failed: $url (${http_code:-no status})"
      date +%s > "$attempt"
      return 1
      ;;
  esac
}

load_location() {
  if [[ -z ${yr_location:-} ]]; then
    log "location not configured"
    return 1
  fi

  local location_id cache="$location_cache" raw="${location_cache}.raw.$$" tmp="${location_cache}.tmp.$$"
  location_id=$(echo "$yr_location" | cut -d '/' -f 1-2 | sed 's|/||g')

  if [[ -f $cache ]]; then
    local cached_location age
    cached_location=$(jq -r '.location // empty' "$cache" 2>/dev/null)
    age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
    if [[ $cached_location == "$yr_location" ]] && (( age < 2592000 )); then
      yr_location_position_lat=$(jq -r '.lat // empty' "$cache" 2>/dev/null)
      yr_location_position_lon=$(jq -r '.lon // empty' "$cache" 2>/dev/null)
      if [[ -n $yr_location_position_lat && -n $yr_location_position_lon ]]; then
        gsettings set org.gnome.settings-daemon.plugins.color night-light-last-coordinates "(${yr_location_position_lat},${yr_location_position_lon})"
        return 0
      fi
    fi
  fi

  if curl --silent --show-error --fail --compressed --max-time 20 \
      --retry 2 --retry-delay 2 -H "User-Agent: $MET_UA" \
      -o "$raw" "https://www.yr.no/api/v0/locations/${location_id}?language=en"; then
    local lat lon
    lat=$(jq -r '.position.lat // empty' "$raw" 2>/dev/null)
    lon=$(jq -r '.position.lon // empty' "$raw" 2>/dev/null)
    if [[ -n $lat && -n $lon ]]; then
      lat=$(LC_ALL=C awk -v v="$lat" 'BEGIN{printf "%.4f", v}')
      lon=$(LC_ALL=C awk -v v="$lon" 'BEGIN{printf "%.4f", v}')
      if jq -n --arg loc "$yr_location" --argjson lat "$lat" --argjson lon "$lon" \
          '{location:$loc,lat:$lat,lon:$lon}' > "$tmp" && [[ -s $tmp ]]; then
        mv "$tmp" "$cache"
        yr_location_position_lat=$lat
        yr_location_position_lon=$lon
        gsettings set org.gnome.settings-daemon.plugins.color night-light-last-coordinates "($lat,$lon)"
        rm -f "$raw"
        return 0
      fi
    fi
  fi

  rm -f "$tmp" "$raw"
  if [[ -f $cache ]]; then
    yr_location_position_lat=$(jq -r '.lat // empty' "$cache" 2>/dev/null)
    yr_location_position_lon=$(jq -r '.lon // empty' "$cache" 2>/dev/null)
    if [[ -n $yr_location_position_lat && -n $yr_location_position_lon ]]; then
      gsettings set org.gnome.settings-daemon.plugins.color night-light-last-coordinates "(${yr_location_position_lat},${yr_location_position_lon})"
      log "using cached location"
      return 0
    fi
  fi

  log "location lookup failed"
  return 1
}

load_sun_times() {
  local today offset cache="$met_sun_cache" raw url=""
  local wrapper_date="" wrapper_lat="" wrapper_lon=""
  local sunrise_iso="" sunset_iso=""

  today=$(date +%F)
  if [[ -z ${yr_location_position_lat:-} || -z ${yr_location_position_lon:-} ]]; then
    sun_times_valid=0
    if [[ ${sun_warned:-0} != 1 ]]; then
      log "sun times unavailable"
      sun_warned=1
    fi
    return 1
  fi

  raw="$config_folder/met_sun.raw.${yr_location_position_lat}_${yr_location_position_lon}.json"
  offset=$(date +%:z | sed 's/+/%2B/')
  url="https://api.met.no/weatherapi/sunrise/3.0/sun?lat=${yr_location_position_lat}&lon=${yr_location_position_lon}&date=${today}&offset=${offset}"

  if [[ -f $cache ]]; then
    wrapper_date=$(jq -r '.date // empty' "$cache" 2>/dev/null)
    wrapper_lat=$(jq -r '.lat // empty' "$cache" 2>/dev/null)
    wrapper_lon=$(jq -r '.lon // empty' "$cache" 2>/dev/null)
  fi

  if [[ $wrapper_date == "$today" && $wrapper_lat == "$yr_location_position_lat" && $wrapper_lon == "$yr_location_position_lon" ]]; then
    sunrise_iso=$(jq -r '.sunrise // empty' "$cache" 2>/dev/null)
    sunset_iso=$(jq -r '.sunset // empty' "$cache" 2>/dev/null)
  else
    fetch_json "$url" "$raw" 0 || true
    sunrise_iso=$(jq -r '.properties.sunrise.time // empty' "$raw" 2>/dev/null)
    sunset_iso=$(jq -r '.properties.sunset.time // empty' "$raw" 2>/dev/null)

    if [[ -n $sunrise_iso && -n $sunset_iso ]]; then
      local sunrise_date sunset_date
      sunrise_date=$(date -d "$sunrise_iso" +%F 2>/dev/null)
      sunset_date=$(date -d "$sunset_iso" +%F 2>/dev/null)
      if [[ $sunrise_date != "$today" || $sunset_date != "$today" ]]; then
        sunrise_iso=""
        sunset_iso=""
      elif jq -n --arg date "$today" --arg lat "$yr_location_position_lat" \
          --arg lon "$yr_location_position_lon" --arg sunrise "$sunrise_iso" \
          --arg sunset "$sunset_iso" \
          '{date:$date,lat:$lat,lon:$lon,sunrise:$sunrise,sunset:$sunset}' > "${cache}.tmp.$$" \
          && [[ -s "${cache}.tmp.$$" ]]; then
        mv "${cache}.tmp.$$" "$cache"
      else
        rm -f "${cache}.tmp.$$"
      fi
    fi
  fi

  if [[ -z $sunrise_iso || -z $sunset_iso ]]; then
    sun_times_valid=0
    if [[ ${sun_warned:-0} != 1 ]]; then
      log "sun times unavailable"
      sun_warned=1
    fi
    return 1
  fi

  if ! sunrise_epoch=$(date -d "$sunrise_iso" +%s 2>/dev/null) || \
     ! sunset_epoch=$(date -d "$sunset_iso" +%s 2>/dev/null); then
    sun_times_valid=0
    if [[ ${sun_warned:-0} != 1 ]]; then
      log "sun times unavailable"
      sun_warned=1
    fi
    return 1
  fi

  sunrise=$(date -d "@$sunrise_epoch" +%H:%M)
  sunset=$(date -d "@$sunset_epoch" +%H:%M)
  sun_date=$today
  sun_times_valid=1
  sun_warned=0

  local dark_start=$(( sunset_epoch - ${before_sunset:-0} * 60 ))
  local light_start=$(( sunrise_epoch + ${after_sunrise:-0} * 60 ))
  night_light_schedule_from_hour=$(date -d "@$dark_start" +%-H)
  night_light_schedule_from_min=$(date -d "@$dark_start" +%-M)
  night_light_schedule_to_hour=$(date -d "@$light_start" +%-H)
  night_light_schedule_to_min=$(date -d "@$light_start" +%-M)
  night_light_schedule_from_min=$(LC_ALL=C bc <<< "scale=9; $night_light_schedule_from_min / 60")
  night_light_schedule_to_min=$(LC_ALL=C bc <<< "scale=9; $night_light_schedule_to_min / 60")

  return 0
}

load_weather() {
  if [[ ${yr:-0} != 1 ]] || { [[ ${cc:-0} != 1 ]] && [[ ${uv:-0} != 1 ]]; }; then
    cloud_cover=0
    uv_rad=0
    uv_scale=0
    uv_radiation=""
    return 0
  fi

  if [[ -z ${yr_location_position_lat:-} || -z ${yr_location_position_lon:-} ]]; then
    cloud_cover=0
    uv_rad=0
    uv_scale=0
    uv_radiation=""
    if [[ ${weather_warned:-0} != 1 ]]; then
      log "forecast unavailable"
      weather_warned=1
    fi
    return 1
  fi

  local url="https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=${yr_location_position_lat}&lon=${yr_location_position_lon}"
  fetch_json "$url" "$met_forecast_cache" 1800 || true

  if [[ ! -f $met_forecast_cache ]] || ! jq -e . "$met_forecast_cache" >/dev/null 2>&1; then
    cloud_cover=0
    uv_rad=0
    uv_scale=0
    uv_radiation=""
    if [[ ${weather_warned:-0} != 1 ]]; then
      log "forecast unavailable"
      weather_warned=1
    fi
    return 1
  fi

  local now_utc entry cloud uv
  now_utc=$(date -u +%Y-%m-%dT%H:00:00Z)
  entry=$(jq -c --arg now "$now_utc" \
    '[.properties.timeseries[] | select(.time <= $now)] | last // .properties.timeseries[0]' \
    "$met_forecast_cache" 2>/dev/null)
  cloud=$(jq -r '.data.instant.details.cloud_area_fraction // 0' <<<"$entry" 2>/dev/null)
  uv=$(jq -r '.data.instant.details.ultraviolet_index_clear_sky // empty' <<<"$entry" 2>/dev/null)

  cloud_cover=$(LC_ALL=C printf '%.0f' "${cloud:-0}")

  if [[ -z $uv ]]; then
    uv_rad=0
    uv_scale=0
    uv_radiation=""
  else
    uv_rad=$(LC_ALL=C printf '%.0f' "$uv")

    case $uv_rad in
    0)
      uv_radiation="($uv_rad) No UV radiation"
      uv_scale=100
      ;;
    1)
      uv_radiation="($uv_rad) Low"
      uv_scale=95
      ;;
    2)
      uv_radiation="($uv_rad) Low"
      uv_scale=85
      ;;
    3)
      uv_radiation="($uv_rad) Moderate"
      uv_scale=75
      ;;
    4)
      uv_radiation="($uv_rad) Moderate"
      uv_scale=65
      ;;
    5)
      uv_radiation="($uv_rad) Moderate"
      uv_scale=55
      ;;
    6)
      uv_radiation="($uv_rad) High"
      uv_scale=45
      ;;
    7)
      uv_radiation="($uv_rad) High"
      uv_scale=35
      ;;
    8)
      uv_radiation="($uv_rad) Very high"
      uv_scale=25
      ;;
    9)
      uv_radiation="($uv_rad) Very high"
      uv_scale=15
      ;;
    10)
      uv_radiation="($uv_rad) Very high"
      uv_scale=5
      ;;
    11)
      uv_radiation="($uv_rad) Extreme"
      uv_scale=0
      ;;
    *)
      uv_radiation="($uv_rad) Extreme"
      uv_scale=0
      ;;
  esac
  fi

  weather_warned=0
  return 0
}

print_weather() {
  echo "Sunrise: $sunrise Sunset: $sunset"
  if [[ ${cc:-0} == "1" ]]; then
    echo "Cloud cover (current hour): ${cloud_cover:-0}%"
  fi
  if [[ ${uv:-0} == "1" ]]; then
    echo "UV index (current hour): ${uv_radiation:-}"
  fi
  if [[ ${cc:-0} == "1" ]] && [[ ${uv:-0} == "1" ]]; then
    echo "UV Index is added to Cloud cover"
    echo "On a inverted scale from 100-0"
    echo "Calculation: ${max_bright}-(${cloud_cover:-0}+${uv_scale:-0})="$(( max_bright - (cloud_cover + uv_scale) ))""
  fi
}

case $time_format in
  12)
  time_format="%l"
    ;;
  24)
  time_format="%H"
    ;;
esac

load_location || true



load_sun_times || true
load_weather || true

send_notification() {
  notification="$1"
  notification_title="Night Light"
  notification_img="$config_folder/assets/$2.png"
  # Send notification to desktop
  notify-send \
  --hint=string:sound-name:dialog-information \
  --app-name="$notification_title" \
  --app-icon=dialog-information-symbolic \
  --icon="$notification_img" \
  "$notification_title" \
  "$notification"
}
# set night light temperature
night_light_temperature() {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature "$1"
}
# set night light
night_light_enabled() {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled "$1"
}
# toggle color scheme
color_scheme_toggle() {
  if ! gsettings set org.gnome.desktop.interface color-scheme "prefer-$1"; then
    log "color-scheme set failed: $1"
    return 1
  fi
  log "color scheme $1"
}
# toggle do not disturb
dnd_toggle() {
  gsettings set org.gnome.desktop.notifications show-banners "$1"
  gsettings set org.gnome.desktop.sound event-sounds "$1"
}

# Put together in a function E.G: 17:55 turns into 17.916666666
set_night_light_schedule_from() {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from "$night_light_schedule_from_hour$night_light_schedule_from_min"
}
# Put together in a function E.G: 07:21 turns into 7.350000000
set_night_light_schedule_to () {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to "$night_light_schedule_to_hour$night_light_schedule_to_min"
}

sync_night_light_schedule() {
  set_night_light_schedule_from
  set_night_light_schedule_to
}

auto-run() {
  local loop_count=0
  local loop_sleep=60
  local schedule_synced=0
  while true
  do
    loop_count=$((loop_count + 1))
    if (( loop_count <= 24 )); then
      loop_sleep=5
    else
      loop_sleep=60
    fi
    if [[ -z ${yr_location_position_lat:-} || -z ${yr_location_position_lon:-} ]]; then
      if (( loop_count % 5 == 1 )); then
        load_location || true
      fi
    fi
    if [[ $(date +%F) != "${sun_date:-}" ]]; then
      load_sun_times || true
      schedule_synced=0
    fi
    if [[ ${sun_times_valid:-0} != 1 ]]; then
      if [[ ${sun_warned:-0} != 1 ]]; then
        log "sun times unavailable"
        sun_warned=1
      fi
      sleep "$loop_sleep"
      continue
    fi
    if [[ $schedule_synced != 1 ]]; then
      sync_night_light_schedule
      schedule_synced=1
    fi

    get_color_scheme=$(
      if ! scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null); then
        log "color-scheme read failed"
        echo light
      elif [[ $scheme =~ dark ]]; then
        echo dark
      else
        echo light
      fi
    )
    toggle_dark() {
      if [[ ! $get_color_scheme == "dark" ]]
      then
        night_light_enabled true
        color_scheme_toggle dark
        dnd_toggle false
        set_night_light_schedule_from
        if [[ $(command -v 'notify-send') ]]; then
          send_notification "Color-scheme is set to dark" "dark"
        fi
      else
        echo "Color-scheme is already set to dark"
      fi
    }

    toggle_light() {
      if [[ ! $get_color_scheme == "light" ]]
      then
        night_light_enabled false
        color_scheme_toggle light
        dnd_toggle true
        set_night_light_schedule_to
        if [[ $(command -v 'notify-send') ]]; then
          send_notification "Color-scheme is set to light" "light"
        fi
      else
        echo "Color-scheme is already set to light"
      fi
    }
    # Source: https://askubuntu.com/a/894470
    # global variable
    LastSetting=$(
      gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature |
    sed 's|uint32 ||g')
    # Current seconds
    secNow=$(date +"%s")
    secSunrise=$sunrise_epoch
    secSunset=$sunset_epoch
    load_weather || true

    set-and-sleep() {
      if [[ $1 != $LastSetting ]]
      then
        # sudo sh -c "echo $1 | sudo tee $backlight"
        # echo "$1" > "/tmp/display-current-brightness"
        LastSetting="$1"
        night_light_temperature "$1"
        echo "Temperature set to ($1)"
      fi
      sleep "$loop_sleep"
    }

    re='^[0-9]+$'   # regex for valid numbers

    calc-level-and-sleep() {
      # Parms $1 = number of minutes for total transition
      #       $2 = number of seconds into transition
      # Daytime - nightime = transition brightness levels
      transition_spread=$(( $max_bright - $min_bright ))
      secTotal=$(( $1 * 60 )) # Convert total transition minutes to seconds
      Adjust=$( bc <<< "scale=6; $transition_spread * ( $2 / $secTotal )" )
      Adjust=$( echo "$Adjust" | cut -f1 -d"." ) # Truncate number to integer

      if ! [[ $Adjust =~ $re ]]
      then
        Adjust=0   # When we get to last minute $Adjust can be non-numeric
      fi

      calc_bright=$(( $min_bright + $Adjust ))
      set-and-sleep "$calc_bright"
    }
    # We're somewhere between sunrise and sunset
    secMaxCutoff=$(( $secSunrise + ( $after_sunrise * 60 ) ))
    secMinStart=$((  $secSunset  - ( $before_sunset * 60 ) ))

    # Are we between sunrise and full brightness?
    if [[ "$secNow" -gt "$secSunrise" ]] && [[ "$secNow" -lt "$secMaxCutoff" ]]
    then
      # Light mode is set by the full-day branch once the ramp completes.
      # Current time - Sunrise = progress through transition
      secPast=$(( $secNow - $secSunrise ))
      calc-level-and-sleep "$after_sunrise" $secPast
      PastDuration=$(date +$time_format:%M:%S -ud @${secPast})
      echo "Transitioning $PastDuration minutes after sunrise (Currently set to: $after_sunrise minutes)."
      continue
    fi
    # Is it full bright day time?
    if [[ "$secNow" -gt "$secMaxCutoff" ]] && [[ "$secNow" -lt "$secMinStart" ]]
    then
      # Set global Light Mode
      if [[ $cs == "1" ]] && [[ ! $get_color_scheme == "light" ]]
      then
        toggle_light
      fi
      # MAXIMUM: after sunrise transition AND before nightime transition
      # Subtract yr.no cloud cover percentage from max brightness and UV Index
      if [[ $cc == "1" ]] && [[ $uv == "1" ]]
      then
        set-and-sleep $(( $max_bright - ( ${cloud_cover:-0} + ${uv_scale:-0} ) ))
        # Subtract yr.no cloud cover percentage from max brightness
      elif [[ $cc == "1" ]]
      then
        set-and-sleep $(( $max_bright - ${cloud_cover:-0} ))
      else
        set-and-sleep "$max_bright"
      fi
      continue
    fi
    # Are we between beginning to dim and sunset (full dim)?
    if [[ "$secNow" -gt "$secMinStart" ]] && [[ "$secNow" -lt "$secSunset" ]]
    then
      # Set global Dark Mode at the start of the evening dim
      if [[ $cs == "1" ]]
      then
        toggle_dark
      fi
      # Sunset - Current time = progress through transition
      secBeforeSunset=$(( $secSunset - $secNow ))
      calc-level-and-sleep "$before_sunset" $secBeforeSunset
      BeforeDuration=$(date +$time_format:%M:%S -ud @${secBeforeSunset})
      echo "Transitioning $BeforeDuration minutes before sunset (Currently set to: $before_sunset minutes)."
      continue
    fi
    # Is it night time?
    if [[ "$secNow" -gt "$secSunset" ]] || [[ "$secNow" -lt "$secSunrise" ]]
    then
      # Set global Light Mode
      if [[ $cs == "1" ]]
      then
        toggle_dark
      fi
      # MINIMUM: after sunset or before sunrise nightime setting
      set-and-sleep "$min_bright"
      continue
    fi
    # At this stage brightness was set with manual override outside this program
    # or exactly at a testpoint, then it will change next minute so no big deal.
    sleep "$loop_sleep" # reset brightness once per loop.
  done # End of forever loop
}

install() {
  systemd_user_folder=$HOME/.config/systemd/user
  if ! [[ -d $systemd_user_folder ]]
  then
    mkdir -p "$systemd_user_folder"
  fi
  local_bin_folder=$HOME/.local/bin
  if ! [[ -d $local_bin_folder ]]
  then
    mkdir -p "$local_bin_folder"
  fi

  SUDO="sudo"
  INSTALL="apt-get -o Dpkg::Progress-Fancy="1" install -qq"
  UPDATE="apt-get -o Dpkg::Progress-Fancy="1" update -qq"
  PKGCHK="dpkg -s"

  PKGS="screen libnotify-bin"

  echo -e "Setting up Dependencies"
  if ! ${PKGCHK} ${PKGS} >/dev/null 2>&1; then
    ${UPDATE}
    for i in ${PKGS}; do
      ${SUDO} ${INSTALL} $i 2> /dev/null
    done
  fi

  download_files() {
    echo "Cloning files to $config_folder..."
    if [[ $(command -v 'git') ]]; then
      git clone https://github.com/tmiland/night_light.sh.git "$config_folder" >/dev/null 2>&1
    else
      echo -e "This script requires git.\nProcess aborted"
      exit 0
    fi
  }
  echo ""
  read -n1 -r -p "Night Light is ready to be installed, press any key to continue..."
  echo ""
  download_files
  ln -sfn "$config_folder"/night_light.sh "$HOME"/.local/bin/night_light
  chmod +x "$config_folder"/night_light.sh
  chmod +x "$config_folder"/night_light_config.sh
  "$HOME"/.local/bin/night_light -c
  echo "Enabling systemd service"
  if ! [[ -d "$HOME"/.config/systemd/user ]]
  then
    mkdir -p "$HOME"/.config/systemd/user
  fi
  cp -rp  "$config_folder"/night_light.service "$HOME"/.config/systemd/user/night_light.service
  sed -i "s|/usr/local/bin/night_light|$HOME/.local/bin/night_light|g" "$HOME"/.config/systemd/user/night_light.service
  systemctl --user enable night_light.service &&
  systemctl --user start night_light.service &&
  systemctl --user status night_light.service --no-pager
  if [ $? -eq 0 ]
  then
    echo "Install finished, enjoy..."
    echo "You can resume screen with 'screen -r night_light' "
    echo "Restart service with 'systemdctl --user restart night_light' "
  else
    echo "ERROR: Some thing went wrong..."
  fi
}

uninstall() {
  echo ""
  read -n1 -r -p "Night Light is ready to be installed, press any key to continue..."
  echo ""
  rm -rf "$config_folder"
  rm -rf "$HOME"/.local/bin/night_light
  systemctl --user disable night_light.service
  rm -rf "$HOME"/.config/systemd/user/night_light.service
  echo "Uninstall finished, have a good day..."
}

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "" $(basename "$0")
  echo
  echo "  If called without arguments, uses 24 hour clock."
  echo
  printf "  --light-enabled     | -le          turn on/off (true/false)\\n"
  printf "  --light-temperature | -lt          show light-temperature\\n"
  printf "  --auto-run          | -ar          auto run\\n"
  printf "  --yr                | -y           show yr.no information\\n"
  printf "  --config            | -c           run config dialog\\n"
  printf "  --install           | -i           install\\n"
  printf "  --uninstall         | -u           uninstall\\n"
  printf "\\n"
  echo
}

AR=

ARGS=()
while [[ $# -gt 0 ]]
do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --light-enabled | -le) # Bash Space-Separated (e.g., --option argument)
      gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled "$2" # Source: https://stackoverflow.com/a/14203146
      shift # past argument
      shift # past value
      ;;
    --light-temperature | -lt)
      echo "Current temperature: $LastSetting"
      exit 0
      ;;
    --auto-run | -ar)
      AR=1
      auto-run
      shift
      ;;
    --yr | -y)
      load_sun_times || true
      load_weather || true
      print_weather
      shift
      ;;
    --config | -c)
      . "$cfg_sh_file"
      exit 0
      ;;
    --install | -i)
      install
      exit 0
      ;;
    --uninstall | -u)
      uninstall
      exit 0
      ;;
    --*|-*)
      printf "Unrecognized option: $1\\n\\n"
      usage
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${ARGS[@]}"

exit 0
