#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2024


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
# Copyright (c) 2024 Tommy Miland
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
fi

# Crawler
pkg=lynx
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

if ! dpkg -s $pkg >/dev/null 2>&1
then
  apt install $pkg
fi

yr() {
  # yr.no url
  yr_url=https://www.yr.no
  # yr.no location url
  yr_location_url=$yr_url/en/other-conditions$yr_location
  # Use home folder for tmp file Persistence
  nl_folder=$config_folder
  # yr.no tmp file
  yr_tmp="$nl_folder"/yr.tmp
  if ! [ -f "$yr_tmp" ]
  then
    mkdir -p "$nl_folder"
    $pkg --dump "$yr_location_url" > "$yr_tmp"
  fi

  sun() {
    grep -oE "Sun$1 [[:digit:]]+:[[:digit:]]+" "$yr_tmp" |
    sed -n "s/.*Sun$1 *\([^ ]*.*\)/\1/p"
  }

  if [[ $cc == "1" ]]
  then
    cloud_cover=$(
      grep -oE "[[:digit:]]*% cloud cover" "$yr_tmp" |
    sed "s/% cloud cover//g")
  fi

  if [[ $uv == "1" ]]
  then
    uv_rad=$(
      grep --no-group-separator -A 3 "UV forecast" "$yr_tmp" |
      awk 'FNR == 4 {print}'|
    grep -o "[[:digit:]]")
  fi
  # The forecast shows the UV index for the selected hour. It does not take the cloud cover into account.
  #
  # The UV index indicates how strong the UV radiation from the sun is.
  # 1-2	Low
  # 3–5	Moderate
  # 6–7	High
  # 8–10	Very high
  # 11+	Extreme
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
  esac

  sunrise=$(sun rise)
  sunset=$(sun set)

  sunrise-transition() {
    date -d"$1$2 minutes $sunrise" '+%H:%M'
  }

  sunset-transition() {
    date -d"$1$2 minutes $sunset" '+%H:%M'
  }
  wget -q --spider $yr_url
  if [ $? -eq 0 ]
  then
    echo "yr.no is Online."
    echo "Sunrise: $sunrise Sunset: $sunset"
    if [[ $cc == "1" ]]; then
      echo "Cloud cover past 5 minutes: $cloud_cover%"
    fi
    if [[ $uv == "1" ]]; then
      echo "UV Index past 5 minutes: $uv_radiation"
    fi
    if [[ $cc == "1" ]] && [[ $uv == "1" ]]
    then
      echo "UV Index is added to Cloud cover"
      echo "On a inverted scale from 100-0"
      echo "Calculation: $max_bright-($cloud_cover+$uv_scale)="$(( $max_bright - ($cloud_cover + $uv_scale) ))""
    fi
    $pkg --dump "$yr_location_url" > "$yr_tmp"
  else
    echo "yr.no is Offline"
  fi
}

if [[ $yr == "1" ]]
then
  yr
fi

night-light-temperature() {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature "$1"
}

get_color_scheme=$(
  [[ $(gsettings get org.gnome.desktop.interface color-scheme) =~ "dark" ]] &&
  echo dark ||
echo light)

color_scheme_toggle() {
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$1"
}

toggle_dark() {
  if [[ ! $get_color_scheme == "dark" ]]
  then
    color_scheme_toggle dark
  else
    echo "Color-scheme is already set to dark"
  fi
}

toggle_light() {
  if [[ ! $get_color_scheme == "light" ]]
  then
    color_scheme_toggle light
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
        $pkg --dump "$yr_location_url" > "$yr_tmp"
      elif ! [[ -f $yr_tmp ]]
      then
        $pkg --dump "$yr_location_url" > "$yr_tmp"
      fi
      if [[ $cc == "1" ]]
      then
        # yr.no cloud cover percentage
        cloud_cover=$(
          grep -oE "[[:digit:]]*% cloud cover" "$yr_tmp" |
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
      # Set global Light Mode when half the time "after sunrise" time is reached
      secBeforeSunriseLightMode=$(( $secSunrise + ( $after_sunrise / 2 ) ))
      # Set global Light Mode
      if [[ $cs == "1" ]] && [[ $secNow -gt $secBeforeSunriseLightMode ]]
      then
        toggle_light
      fi
      # Current time - Sunrise = progress through transition
      secPast=$(( $secNow - $secSunrise ))
      calc-level-and-sleep "$after_sunrise" $secPast
      PastDuration=$(date +%H:%M:%S -ud @${secPast})
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
        set-and-sleep $(( $max_bright - ( $cloud_cover + $uv_scale ) ))
        # Subtract yr.no cloud cover percentage from max brightness
      elif [[ $cc == "1" ]]
      then
        set-and-sleep $(( $max_bright - $cloud_cover ))
      else
        set-and-sleep "$max_bright"
      fi
      continue
    fi
    # Are we between beginning to dim and sunset (full dim)?
    if [[ "$secNow" -gt "$secMinStart" ]] && [[ "$secNow" -lt "$secSunset" ]]
    then
      secBeforeSunsetDarkMode=$(( $secSunset - ( $before_sunset / 2 ) ))
      # Set global Dark Mode when half the time "before sunset" time is reached
      if [[ $cs == "1" ]] && [[ $secBeforeSunsetDarkMode -gt $secNow ]]
      then
        toggle_dark
      fi
      # Sunset - Current time = progress through transition
      secBeforeSunset=$(( $secSunset - $secNow ))
      calc-level-and-sleep "$before_sunset" $secBeforeSunset
      BeforeDuration=$(date +%H:%M:%S -ud @${secBeforeSunset})
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
    sleep 60 # reset brightness once / minute.
  done # End of forever loop
}

install() {
  url=https://github.com/tmiland/night_light.sh/raw/main
  night_light_config_url=$url/.night_light_config
  night_light_config_sh_url=$url/night_light_config.sh
  night_light_url=$url/night_light.sh
  night_light_service=$url/night_light.service
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
    if [[ $(command -v 'curl') ]]; then
      curl -fsSLk "$night_light_config_url" > "${config_folder}"/.night_light_config
      curl -fsSLk "$night_light_config_sh_url" > "${config_folder}"/night_light_config.sh
      curl -fsSLk "$night_light_url" > "${config_folder}"/night_light.sh
      curl -fsSLk "$night_light_service" > "$systemd_user_folder"/night_light.service
    elif [[ $(command -v 'wget') ]]; then
      wget -q "$night_light_config_url" -O "${config_folder}"/.night_light_config
      wget -q "$night_light_config_sh_url" -O "${config_folder}"/night_light_config.sh
      wget -q "$night_light_url" -O "${config_folder}"/night_light.sh
      wget -q "$night_light_service" -O "$systemd_user_folder"/night_light.service
    else
      echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NC}"
      exit 0
    fi
  }
  echo ""
  read -n1 -r -p "Night Light is ready to be installed, press any key to continue..."
  echo ""
  download_files
  ln -sfn "$HOME"/.night_light/night_light.sh "$HOME"/.local/bin/night_light
  chmod +x "$HOME"/.night_light/night_light.sh
  chmod +x "$HOME"/.night_light/night_light_config.sh
  "$HOME"/.local/bin/night_light -c
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
  printf "  --24hour            | -24          use 24 hour clock\\n"
  printf "  --12hour            | -12          use 12 hour clock\\n"
  printf "  --light-enabled     | -le          turn on/off (true/false)\\n"
  printf "  --light-temperature | -lt          show light-temperature\\n"
  printf "  --dark-toggle       | -dt          toggle dark/light color scheme\\n"
  printf "  --auto-run          | -ar          auto run\\n"
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
