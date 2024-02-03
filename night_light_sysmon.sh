#!/usr/bin/env bash

# Source: https://askubuntu.com/a/894470
# And: https://askubuntu.com/a/882420
# if [ -f ~/.lock-screen-timer-remaining ]; then
#     text-spinner
#     Spinner=$(cat ~/.last-text-spinner) # read last text spinner used
#     Minutes=$(cat ~/.lock-screen-timer-remaining)
#     systray=" $Spinner Lock screen in: $Minutes"
# else
#     systray=" Lock screen: OFF"
# fi

if command -v gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature >/dev/null 2>&1; then
  Brightness=$(gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature | sed 's|uint32||g')
  systray="$systray Brightness: $Brightness"
else
  systray="$systray Brightness: OFF"
fi

echo "$systray" # sysmon-indidicator will put echo string into systray for us.

exit 0
