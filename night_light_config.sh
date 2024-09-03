#!/usr/bin/env bash

cfg_file=$HOME/.night_light/.night_light_config
# Read hidden configuration file with entries separated by " " into array
IFS=' ' read -ra CfgArr < $cfg_file

# Zenity form with current values in entry label
# because initializing multiple entry data fields not supported
output=$(zenity --forms --title="Night Light Auto Brightness Configuration" \
        --text="Enter new settings or leave entries blank to keep (existing) settings" \
   --add-entry="Day time maximum display brightness : (${CfgArr[0]})" \
   --add-entry="Transition minutes after sunrise to maximum : (${CfgArr[1]})" \
   --add-entry="Night time minimum display brightness : (${CfgArr[2]})" \
   --add-entry="Transition minutes before sunset to minimum : (${CfgArr[3]})" \
   --add-entry="Cloud cover on/off (0/1) : (${CfgArr[4]})" \
   --add-entry="UV Index on/off (0/1) : (${CfgArr[5]})" \
   --add-entry="Change color scheme on/off (0/1) : (${CfgArr[6]})" \
   --add-entry="Turn yr.no on/off (0/1) : (${CfgArr[7]})"
   --add-entry="yr.no location : (${CfgArr[8]})")

IFS='|' read -ra ZenArr <<<"$output" # Split zenity entries separated by "|" into array elements

# Update non-blank zenity array entries into configuration array
for i in "${!ZenArr[@]}"; do
    if [[ ${ZenArr[i]} != "" ]]; then CfgArr[i]=${ZenArr[i]} ; fi
done

# write hidden configuration file using array (fields automatically separated by " ")
if [[ ! -f cfg_file ]]; then
  touch $cfg_file
fi
echo "${CfgArr[@]}" > $cfg_file