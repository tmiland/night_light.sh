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
# set -o errexit
# set -o pipefail
# set -o nounset
# set -o xtrace

# Symlink: ln -sfn ~/.scripts/night_light.sh ~/.local/bin/night_light.sh
# Crontab: 1 1 * * * bash ~/.scripts/night_light.sh > /dev/null 2>&1
# Based on source: https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2

CLOCK=24

# Source: https://www.omgubuntu.co.uk/2017/07/adjust-color-temperature-gnome-night-light
# 1000 — Lowest value (super warm/red)
# 4000 — Default night light on temperature
# 5500 — Balanced night light temperature
# 6500 — Default night light off temperature
# 10000 — Highest value (super cool/blue)
temperature_morning="5500"
temperature_noon="6500"
temperature_evening="3500"
temperature_night="2500"

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "${CYAN}" $(basename "$0")
  echo
  echo "  If called without arguments, uses 24 hour clock."
  echo
  printf "  --24hour            | -24           use 24 hour clock\\n"
  printf "  --12hour            | -12           use 12 hour clock\\n"
  printf "  --light-enabled     | -le           turn on/off (true/false)\\n"
  printf "  --light-temperature | -lt           show light-temperature\\n"
  printf "  --dark-toggle       | -dt           toggle dark/light color scheme"
  printf "\\n"
  printf "  Crontab: 1 * * * * bash ~/.scripts/night_light.sh > /dev/null 2>&1\\n"
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
    --dark-toggle | -dt)
      DT=1
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
      morning="09:00"
      noon="12:00"
      evening="16:00"
      night="20:00"
      ;;
    2 )
      morning="08:00"
      noon="12:00"
      evening="17:00"
      night="20:00"
      ;;
    3 )
      morning="07:00"
      noon="12:00"
      evening="18:00"
      night="21:00"
      ;;
    4 )
      morning="07:00"
      noon="12:00"
      evening="19:00"
      night="21:00"
      ;;
    5 )
      morning="07:00"
      noon="12:00"
      evening="20:00"
      night="22:00"
      ;;
    6 )
      morning="07:00"
      noon="12:00"
      evening="21:00"
      night="23:00"
      ;;
    7 )
      morning="07:00"
      noon="12:00"
      evening="20:00"
      night="23:00"
      ;;
    8 )
      morning="07:00"
      noon="12:00"
      evening="19:00"
      night="23:00"
      ;;
    9 )
      morning="08:00"
      noon="12:00"
      evening="18:00"
      night="22:00"
      ;;
    10 )
      morning="09:00"
      noon="12:00"
      evening="17:00"
      night="21:00"
      ;;
    11 )
      morning="10:00"
      noon="12:00"
      evening="16:00"
      night="20:00"
      ;;
    12 )
      morning="10:00"
      noon="12:00"
      evening="15:00"
      night="20:00"
      ;;
  esac
  # elif [[ $CLOCK = 12 ]]; then
  #   currenttime=$(date +"%I:%M")
  #   case $currentmonth in
  #     1 )
  #       morning="09:00 AM"
  #       noon="12:00 PM"
  #       evening="04:00 PM"
  #       night="08:00 PM"
  #       ;;
  #     2 )
  #       morning="08:00 AM"
  #       noon="12:00 PM"
  #       evening="05:00 PM"
  #       night="09:00 PM"
  #       ;;
  #     3 )
  #       morning="07:00 AM"
  #       noon="12:00 PM"
  #       evening="06:00 PM"
  #       night="09:00 PM"
  #       ;;
  #     4 )
  #       morning="07:00 AM"
  #       noon="12:00 PM"
  #       evening="07:00 PM"
  #       night="09:00 PM"
  #       ;;
  #     5 )
  #       morning="07:00 AM"
  #       noon="12:00 PM"
  #       evening="08:00 PM"
  #       night="09:00 PM"
  #       ;;
  #     6 )
  #       morning="07:00 AM"
  #       noon="12:00 PM"
  #       evening="10:00 PM"
  #       night="10:00 PM"
  #       ;;
  #     7 )
  #       morning="07:00 AM"
  #       noon="12:00 PM"
  #       evening="10:00 PM"
  #       night="11:00 PM"
  #       ;;
  #     8 )
  #       morning="07:00 AM"
  #       noon="12:00 PM"
  #       evening="09:00 PM"
  #       night="11:00 PM"
  #       ;;
  #     9 )
  #       morning="08:00 AM"
  #       noon="12:00 PM"
  #       evening="08:00 PM"
  #       night="11:00 PM"
  #       ;;
  #     10 )
  #       morning="09:00 AM"
  #       noon="12:00 PM"
  #       evening="07:00 PM"
  #       night="10:00 PM"
  #       ;;
  #     11 )
  #       morning="10:00 AM"
  #       noon="12:00 PM"
  #       evening="06:00 PM"
  #       night="09:00 PM"
  #       ;;
  #     12 )
  #       morning="10:00 AM"
  #       noon="12:00 PM"
  #       evening="05:00 PM"
  #       night="08:00 PM"
  #       ;;
  #   esac
fi

dark_toggle=$([[ $(gsettings get org.gnome.desktop.interface color-scheme) =~ "dark" ]] && echo dark || echo light)

toogle_dark() {
  if [[ $DT == 1 ]]; then
    if command -v dark-toggle &> /dev/null; then
      if ! [[ $dark_toggle == "dark" ]]; then
        dark-toggle
      else
        echo "Color-scheme is already set to dark"
        exit 1
      fi
    else
      echo "dark-toggle could not be found"
      exit 1
    fi
  fi
}

toggle_light() {
  if [[ $DT == 1 ]]; then
    if command -v dark-toggle &> /dev/null; then
      if ! [[ $dark_toggle == "light" ]]; then
        dark-toggle
      else
        echo "Color-scheme is already set to light"
        exit 1
      fi
    else
      echo "dark-toggle could not be found"
      exit 1
    fi
  fi
}

night_light() {

  if [ -n "${1}" ]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature "${1}"
  fi

  if [[ ! ( "$currenttime" < "$morning" || "$currenttime" > "$noon" ) ]]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature $temperature_morning
    echo "Temperature set to morning ($temperature_morning)"
    toggle_light
  fi

  if [[ ! ( "$currenttime" < "$noon" || "$currenttime" > "$evening" ) ]]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature $temperature_noon
    echo "Temperature set to noon ($temperature_noon)"
    toggle_light
  fi

  if [[ ! ( "$currenttime" < "$evening" || "$currenttime" > "$night" ) ]]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature $temperature_evening
    echo "Temperature set to evening ($temperature_evening)"
    toogle_dark
  fi

  if [[ ! ( "$currenttime" < "$night" ) ]]; then
    gsettings set \
      org.gnome.settings-daemon.plugins.color \
      night-light-temperature $temperature_night
    echo "Temperature set to night ($temperature_night)"
    toogle_dark
  fi

}

night_light "$@"
exit 0
