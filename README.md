# night_light.sh
 Automatic night light script for gnome

## Script to adjust night light in gnome

- Automatically adjusts night light based on local time. (default 24 hour clock)
- Toggles dark/light mode based on time of day (light in the morning and dark in the night)
  - Using [dark-toggle](https://github.com/rifazn/dark-toggle)
- Takes local cloud cover and UV radiation into account

Output looks like this
```bash
yr.no is Online.
Sunrise: 06:26 Sunset: 20:21
Cloud cover past 5 minutes: 100%
UV Index past 5 minutes: (1) Low
UV Index is added to Cloud cover
On a inverted scale from 100-0
Calculation: 5750-(100+95)=5555
Current temperature: 5555
```
### Installation

Download and install

```bash
wget -qO- https://github.com/tmiland/night_light.sh/raw/main/night_light.sh | bash -s -- -i
```

### Config options

<a href="https://raw.githubusercontent.com/tmiland/night_light.sh/main/assets/settings.png">![settings](https://raw.githubusercontent.com/tmiland/night_light.sh/main/assets/settings.png)</a>


```bash
Usage: [options]

If called without arguments, uses 24 hour clock.

--24hour            | -24          use 24 hour clock
--12hour            | -12          use 12 hour clock
--light-enabled     | -le          turn on/off (true/false)
--light-temperature | -lt          show light-temperature
--dark-toggle       | -dt          toggle dark/light color scheme
--auto-run          | -ar          auto run
--config            | -c           run config dialog
--install           | -i           install
--uninstall         | -u           uninstall

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