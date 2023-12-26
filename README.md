# night_light.sh
 Automatic night light script for gnome

## Script to adjust night light in gnome

- Automatically adjusts night light based on local time. (default 24 hour clock)
  Use: -12 as argument to set to 12 hours, or set `CLOCK=12` in script.
  
### Installation

Download and symlink script

```bash
curl -sSL -o ~/.scripts/night_light.sh  https://raw.githubusercontent.com/tmiland/night_light.sh/main/night_light.sh
```

Symlink:
  ```bash
   ln -sfn ~/.scripts/night_light.sh ~/.local/bin/night_light.sh
  ```
  Now use 
  ```bash
  $ night_ligh <value>
  ```
  to set temp based on values:

  ```bash
  1000 — Lowest value (super warm/red)
  4000 — Default night light on temperature
  5500 — Balanced night light temperature
  6500 — Default night light off temperature
  10000 — Highest value (super cool/blue)
  ```
  Source: https://www.omgubuntu.co.uk/2017/07/adjust-color-temperature-gnome-night-light

```bash
Usage: [options]

If called without arguments, uses 24 hour clock.

 --24hour            | -24           use 24 hour clock
 --12hour            | -12           use 12 hour clock
 --light-enabled     | -le           turn on/off (true/false)
 --light-temperature | -lt           show light-temperature

```


  - Or install with crontab `contab -e` and add to new line
```bash
@hourly bash ~/.scripts/night_light.sh > /dev/null 2>&1
```

## Credits

- Based on source: https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2

#### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](https://github.com/tmiland/night_light.sh/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/night_light.sh/blob/master/LICENSE)