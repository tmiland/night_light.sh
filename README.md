# night_light.sh
 Automatic night light script for gnome

## Script to adjust night light in gnome

- Automatically adjusts night light based on local time. (default 24 hour clock)
- Toggles dark/light mode based on time of day (light in the morning and dark in the night)
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

### notification

<a href="https://raw.githubusercontent.com/tmiland/night_light.sh/main/assets/notification.png">![notification](https://raw.githubusercontent.com/tmiland/night_light.sh/main/assets/notification.png)</a>

```bash
Usage: [options]

--light-enabled     | -le          turn on/off (true/false)
--light-temperature | -lt          show light-temperature
--auto-run          | -ar          auto run
--config            | -c           run config dialog
--install           | -i           install
--uninstall         | -u           uninstall

```

### Compatibility and Requirements

 - Debian
 - Gnome desktop
 - screen
 - lynx
 - wget
 - curl

### Extra

  - [Script to install dynamic wallpapers in GNOME Desktop](https://github.com/tmiland/dynamic-wallpaper-installer) dark/light mode.

### Credits

- [Based on source](https://discussion.fedoraproject.org/t/can-i-manipulate-night-mode-from-command-line/72853/2)
- [dark-toggle](https://github.com/rifazn/dark-toggle)
- [yr.no](https://yr.no) for sunrise/sunset times.

### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/5/5d/MIT_logo_2003-2023.svg/330px-MIT_logo_2003-2023.svg.png?20250128192424)](https://github.com/tmiland/night_light.sh/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/night_light.sh/blob/master/LICENSE)