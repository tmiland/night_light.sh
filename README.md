# night_light.sh
 Automatic night light script for gnome

## Script to adjust night light in gnome

- Automatically adjusts night light based on local time. (default 24 hour clock)
  Use: -12 as argument to set to 12 hours, or set `CLOCK=12` in script.
  
### Installation

Download and symlink script
  `Symlink: ln -sfn ~/.scripts/night_light.sh ~/.local/bin/night_light.sh`
  Now use `$ night_ligh 3000` to set temp based on values:
  
  ```bash
  1000 — Lowest value (super warm/red)
  4000 — Default night light on temperature
  5500 — Balanced night light temperature
  6500 — Default night light off temperature
  10000 — Highest value (super cool/blue)
  ```
  Source: https://www.omgubuntu.co.uk/2017/07/adjust-color-temperature-gnome-night-light
  
- Turn on/off with `night_light -le true/false`
- Or install with crontab `contab -e` and add to new line `@hourly bash ~/.scripts/night_light.sh > /dev/null 2>&1`

## Credits

- Based on source: https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2