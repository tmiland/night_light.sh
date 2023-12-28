#!/usr/bin/env bash


## Author: Tommy Miland (@tmiland) - Copyright (c) 2023


######################################################################
####                       night_light.sh                         ####
####            Automatic night light script for gnome            ####
####            Script to adjust night light in gnome             ####
####                   Maintained by @tmiland                     ####
######################################################################

VERSION='1.0.0' # Must stay on line 14 for updater to fetch the numbers

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
#set -o errexit
#set -o pipefail
#set -o nounset
#set -o xtrace

# Symlink: ln -sfn ~/.scripts/night_light.sh ~/.local/bin/night_light.sh
# Crontab: @hourly bash ~/.scripts/night_light.sh > /dev/null 2>&1
# Based on source: https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2

CLOCK=24

# Source: https://www.omgubuntu.co.uk/2017/07/adjust-color-temperature-gnome-night-light
# 1000 — Lowest value (super warm/red)
# 4000 — Default night light on temperature
# 5500 — Balanced night light temperature
# 6500 — Default night light off temperature
# 10000 — Highest value (super cool/blue)
temperature_day="6000"
temperature_night="3000"

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "${CYAN}" $(basename "$0")
  echo
  echo "  If called without arguments, uses 24 hour clock."
  echo
  printf "  --24hour            | -24           use 24 hour clock\\n"
  printf "  --12hour            | -12           use 12 hour clock\\n"
  printf "  --light-enabled     | -le           turn on/off (true/false)\\n"
  printf "  --light-temperature | -lt           show light-temperature"
  printf "\\n"
  printf "  Crontab: @hourly bash ~/.scripts/night_light.sh > /dev/null 2>&1\\n"
  echo
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --24hour | -24)
      shift
      CLOCK=24
      ;;
    --12hour | -12)
      shift
      CLOCK=12
      ;;
    --light-enabled | -le) # Bash Space-Separated (e.g., --option argument)
      gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled "$2" # Source: https://stackoverflow.com/a/14203146
      shift # past argument
      shift # past value
      ;;
    --light-temperature | -lt)
      gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature
      shift
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

currentmonth=$(date +%m)

if [[ $CLOCK = 24 ]]; then
  currenttime=$(date +%H:%M)
  case $currentmonth in
    1 )
      start="16:00"
      end="09:00"
      ;;
    2 )
      start="17:00"
      end="08:00"
      ;;
    3 )
      start="18:00"
      end="07:00"
      ;;
    4 )
      start="19:00"
      end="07:00"
      ;;
    5 )
      start="20:00"
      end="07:00"
      ;;
    6 )
      start="21:00"
      end="07:00"
      ;;
    7 )
      start="20:00"
      end="07:00"
      ;;
    8 )
      start="19:00"
      end="07:00"
      ;;
    9 )
      start="18:00"
      end="08:00"
      ;;
    10 )
      start="17:00"
      end="09:00"
      ;;
    11 )
      start="16:00"
      end="10:00"
      ;;
    12 )
      start="15:00"
      end="10:00"
      ;;
  esac
elif [[ $CLOCK = 12 ]]; then
  currenttime=$(date +"%I:%M %p")
  case $currentmonth in
    1 )
      start="04:00 PM"
      end="09:00 AM"
      ;;
    2 )
      start="05:00 PM"
      end="08:00 AM"
      ;;
    3 )
      start="06:00 PM"
      end="07:00 AM"
      ;;
    4 )
      start="07:00 PM"
      end="07:00 AM"
      ;;
    5 )
      start="08:00 PM"
      end="07:00 AM"
      ;;
    6 )
      start="10:00 PM"
      end="07:00 AM"
      ;;
    7 )
      start="10:00 PM"
      end="07:00 AM"
      ;;
    8 )
      start="09:00 PM"
      end="07:00 AM"
      ;;
    9 )
      start="08:00 PM"
      end="08:00 AM"
      ;;
    10 )
      start="07:00 PM"
      end="09:00 AM"
      ;;
    11 )
      start="06:00 PM"
      end="10:00 AM"
      ;;
    12 )
      start="05:00 PM"
      end="10:00 AM"
      ;;
  esac
fi

night_light() {
  if [ -n "${1}" ]
  then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature "${1}"
  elif [[ "$currenttime" > "$start" ]] || [[ "$currenttime" < "$end" ]]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature $temperature_night
  elif [[ "$currenttime" > "$end" ]] || [[ "$currenttime" < "$start" ]]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature $temperature_day
  fi
}

night_light "$@"
exit 0
