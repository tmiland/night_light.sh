# night_light.sh
 Automatic night light script for gnome

## Script to adjust night light in gnome

- Automatically adjusts night light based on local time. (default 24 hour clock)
  ~~Use: -12 as argument to set to 12 hours, or set `CLOCK=12` in script.~~ (WIP)
- Toggles dark/light mode based on time of day (light in the morning and dark in the night)
  - Using [dark-toggle](https://github.com/rifazn/dark-toggle)
  
### Installation

Download and symlink script

```bash
curl -sSL -o ~/.scripts/night_light.sh  https://raw.githubusercontent.com/tmiland/night_light.sh/main/night_light.sh
```

Symlink:
  ```bash
   ln -sfn ~/.scripts/night_light.sh ~/.local/bin/night_light
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
 --12hour            | -12           use 12 hour clock (WIP) (NOT WORKING)
 --light-enabled     | -le           turn on/off (true/false)
 --light-temperature | -lt           show light-temperature
 --dark-toggle       | -dt           toggle dark/light color scheme

```


  - Or install with crontab `contab -e` and add to new line
```bash
1 * * * * bash ~/.scripts/night_light.sh > /dev/null 2>&1
```

Or with systemd:
`/etc/systemd/system/timers.target.wants/night_light.timer`
```bash
[Unit]
Description=Automatically adjusts night light based on local time.
Requires=night_light.service

[Timer]
Unit=night_light.service
OnCalendar=hourly
AccuracySec=60s
Persistent=true

[Install]
WantedBy=timers.target
```

`/etc/systemd/system/night_light.service`
```bash
[Unit]
Description=Logs system statistics to the systemd journal
Wants=night_light.timer

[Service]
Type=oneshot
ExecStart=/bin/bash $HOME/.scripts/night_light.sh

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable night_light.{service,timer} && \
systemctl start night_light.{service,timer} && \
systemctl status night_light.{service,timer}
```

## Compatibility and Requirements

 - Gnome desktop

## Credits

- [Based on source](https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2)
- [dark-toggle](https://github.com/rifazn/dark-toggle)

#### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](https://github.com/tmiland/night_light.sh/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/night_light.sh/blob/master/LICENSE)