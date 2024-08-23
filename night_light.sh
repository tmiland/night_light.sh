#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2023


######################################################################
####                       night_light.sh                         ####
####            Automatic night light script for gnome            ####
####            Script to adjust night light in gnome             ####
####                   Maintained by @tmiland                     ####
######################################################################

# VERSION='1.0.0' # Must stay on line 14 for updater to fetch the numbers

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2023 Tommy Miland
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

# Cloud cover
cc=1
# yr.no
yr="1-68562/Norway/Telemark/Tinn/Rjukan"
yr_url=https://www.yr.no/en/other-conditions/$yr
yr_tmp=/tmp/sun.tmp
# Crawler
pkg=lynx


if ! dpkg -s $pkg >/dev/null 2>&1
then
  apt install $pkg
fi

wget -q --spider https://www.yr.no

sun() {
  cat $yr_tmp |
  grep -oE "Sun$1 [[:digit:]]+:[[:digit:]]+" |
  sed -n "s/.*Sun$1 *\([^ ]*.*\)/\1/p"
}

if [[ $cc == "1" ]]
then
  cloud_cover=$(
    cat $yr_tmp |
    grep -oE "[[:digit:]]*% cloud cover" |
  sed "s/% cloud cover//g")
fi

sunrise=$(sun rise)
sunset=$(sun set)

sunrise-transition() {
  date -d"$1$2 minutes $sunrise" '+%H:%M'
}

sunset-transition() {
  date -d"$1$2 minutes $sunset" '+%H:%M'
}

if [ $? -eq 0 ]
then
  echo "yr.no is Online."
  echo "Sunrise: $sunrise Sunset: $sunset"
  if [[ $cc == "1" ]]; then
    echo "Cloud cover past 5 minutes: $cloud_cover%"
  fi
  $pkg --dump $yr_url > $yr_tmp
else
  echo "yr.no is Offline"
fi

cfg_file=/home/tommy/.github/night_light/.night_light_config
# Read hidden configuration file with entries separated by " " into array
IFS=' ' read -ra cfg_array < $cfg_file
max_bright="${cfg_array[0]}"
after_sunrise="${cfg_array[1]}"
min_bright="${cfg_array[2]}"
before_sunset="${cfg_array[3]}"

# Source: https://www.omgubuntu.co.uk/2017/07/adjust-color-temperature-gnome-night-light
# 1000 — Lowest value (super warm/red)
# 4000 — Default night light on temperature
# 5500 — Balanced night light temperature
# 6500 — Default night light off temperature
# 10000 — Highest value (super cool/blue)
temperature_morning="4500"
temperature_noon="$max_bright"
temperature_evening="3500"
temperature_night="$min_bright"

config() {
  . ./night_light_config.sh
}

night-light-temperature() {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature "$1"
}

get_dark_toggle=$(
  [[ $(gsettings get org.gnome.desktop.interface color-scheme) =~ "dark" ]] &&
  echo dark ||
echo light)

dark_toggle() {
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$1"
}

toggle_dark() {
  if ! [[ $get_dark_toggle == "dark" ]]
  then
    dark_toggle dark
  else
    echo "Color-scheme is already set to dark"
  fi
}

toggle_light() {
  if ! [[ $get_dark_toggle == "light" ]]
  then
    dark_toggle light
  else
    echo "Color-scheme is already set to light"
  fi
}

# Source: https://askubuntu.com/a/894470
# global variable
LastSetting=$(
  gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature |
sed 's|uint32 ||g')

auto-run() {
  while true
  do
    # Current seconds
    secNow=$(date +"%s")
    secSunrise=$(date --date="$sunrise today" +%s)
    secSunset=$(date --date="$sunset today" +%s)
    # Skip running at night time
    if ! [[ "$secNow" -gt "$secSunset" ]] || ! [[ "$secNow" -lt "$secSunrise" ]]
    then
      if [[ $(find "$yr_tmp" -mmin +5 -print) ]]
      then
        echo "File $yr_tmp exists and is older than 5 minutes"
        $pkg --dump $yr_url > $yr_tmp
      elif ! [[ -f $yr_tmp ]]
      then
        $pkg --dump $yr_url > $yr_tmp
      fi
      if [[ $cc == "1" ]]
      then
        # yr.no cloud cover percentage
        cloud_cover=$(
          cat $yr_tmp |
          grep -oE "[[:digit:]]*% cloud cover" |
        sed "s/% cloud cover//g")
      fi
    fi

    set-and-sleep() {
      if [[ $1 != $LastSetting ]]
      then
        # sudo sh -c "echo $1 | sudo tee $backlight"
        # echo "$1" > "/tmp/display-current-brightness"
        LastSetting="$1"
        night-light-temperature "$1"
        echo "Temperature set to ($1)"
      fi
      sleep 60
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
      # Current time - Sunrise = progress through transition
      secPast=$(( $secNow - $secSunrise ))
      calc-level-and-sleep "$after_sunrise" $secPast
      PastDuration=$(date +%H:%M:%S -ud @${secPast})
      echo "Transitioning $PastDuration minutes after sunrise (Currently set to: $after_sunrise)."
      toggle_light
      continue
    fi
    # Is it full bright day time?
    if [[ "$secNow" -gt "$secMaxCutoff" ]] && [[ "$secNow" -lt "$secMinStart" ]]
    then
      # MAXIMUM: after sunrise transition AND before nightime transition
      # Subtract yr.no cloud cover percentage from max brightness
      if [[ $cc == "1" ]]
      then
        set-and-sleep $(( $max_bright - $cloud_cover ))
      else
        set-and-sleep "$max_bright"
      fi
      toggle_light
      continue
    fi
    # Are we between beginning to dim and sunset (full dim)?
    if [[ "$secNow" -gt "$secMinStart" ]] && [[ "$secNow" -lt "$secSunset" ]]
    then
      # Sunset - Current time = progress through transition
      secBefore=$(( $secSunset - $secNow ))
      calc-level-and-sleep "$before_sunset" $secBefore
      BeforeDuration=$(date +%H:%M:%S -ud @${secBefore})
      echo "Transitioning $BeforeDuration minutes before sunset (Currently set to: $before_sunset)."
      continue
    fi
    # Is it night time?
    if [[ "$secNow" -gt "$secSunset" ]] || [[ "$secNow" -lt "$secSunrise" ]]
    then
      # MINIMUM: after sunset or before sunrise nightime setting
      set-and-sleep "$min_bright"
      toggle_dark
      continue
    fi
    # At this stage brightness was set with manual override outside this program
    # or exactly at a testpoint, then it will change next minute so no big deal.
    sleep 60 # reset brightness once / minute.
  done # End of forever loop
}

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "" $(basename "$0")
  echo
  echo "  If called without arguments, uses 24 hour clock."
  echo
  printf "  --24hour            | -24           use 24 hour clock\\n"
  printf "  --12hour            | -12           use 12 hour clock\\n"
  printf "  --light-enabled     | -le           turn on/off (true/false)\\n"
  printf "  --light-temperature | -lt           show light-temperature\\n"
  printf "  --dark-toggle       | -dt           toggle dark/light color scheme\\n"
  printf "  --auto-run          | -ar           auto run\\n"
  printf "  --config            | -c            run config dialog"
  printf "\\n"
  printf "  Crontab: 1 * * * * bash ~/.scripts/night_light.sh > /dev/null 2>&1\\n"
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
    --dark-toggle | -dt)
      toggle_dark
      toggle_light
      shift
      ;;
    --auto-run | -ar)
      AR=1
      auto-run
      shift
      ;;
    --config | -c)
      config
      exit 0
      ;;
    -*|--*)
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

currenttime=$(date +%H:%M)
# morning="$sunrise"
morning=$(sunrise-transition + "$after_sunrise")
noon="12:00"
evening=$(sunset-transition - "$before_sunset")
night=$(sunset-transition + "$before_sunset")

night_light() {
  if ! [[ $AR == "1" ]] && [[ -n "${1}" ]]
  then
    night-light-temperature "${1}"
    return
  elif [[ ! ( "$currenttime" < "$morning" || "$currenttime" > "$noon" ) ]]
  then
    night-light-temperature $temperature_morning
    echo "Temperature set to morning ($temperature_morning)"
    return
    toggle_light
  elif [[ ! ( "$currenttime" < "$noon" || "$currenttime" > "$evening" ) ]]
  then
    night-light-temperature $temperature_noon
    echo "Temperature set to noon ($temperature_noon)"
    return
    toggle_light
  elif [[ ! ( "$currenttime" < "$evening" || "$currenttime" > "$night" ) ]]
  then
    night-light-temperature $temperature_evening
    echo "Temperature set to evening ($temperature_evening)"
    return
    toggle_dark
  elif [[ ! ( "$currenttime" < "$night" ) ]]
  then
    night-light-temperature $temperature_night
    echo "Temperature set to night ($temperature_night)"
    return
    toggle_dark
  fi
}

night_light "$@"
exit 0
