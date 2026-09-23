# Pi kiosk side

Everything that lives on the Raspberry Pi, as deployed. Paths under `etc/`, `usr/`
and `home/` mirror their real locations (`home/` is `/home/pi`). The PC address
`192.168.1.20` is hardcoded throughout — change it in `usr/local/bin/hwmon-kiosk.sh`,
`home/.local/bin/hwmon-screen-watch.sh` and the `only-when-pc-up.conf` drop-in.

## What each piece does

| File | Role |
|---|---|
| `etc/systemd/system/hwmon-kiosk.service` | Runs `cage -s -- /usr/local/bin/hwmon-kiosk.sh` on tty1. `PAMName=login` opens a real login session, which is what keeps the `pi` user manager alive without lingering. |
| `…/hwmon-kiosk.service.d/override.conf` | `XCURSOR_PATH` so wlroots finds the blank theme. (`XCURSOR_THEME`/`XCURSOR_SIZE` are set too but are dead code — see Cursor below.) |
| `usr/local/bin/hwmon-kiosk.sh` | Waits for the server, then `exec`s Chromium in kiosk mode. |
| `etc/systemd/system/hwmon-kiosk-restart.{service,timer}` | Daily 12:00 restart. Memory hygiene only (~48 MB of renderer RSS on a 425 MB box); it does **not** improve frame rate. |
| `…/hwmon-kiosk-restart.service.d/only-when-pc-up.conf` | Skips that restart when the PC is unreachable. |
| `home/.config/systemd/user/hwmon-screen.service` | Runs the panel watcher; `ExecStopPost` turns the panel back on if the watcher dies. |
| `home/.local/bin/hwmon-screen-watch.sh` | Probes the server every 5s and blanks/restores the panel with `wlr-randr`, so the display sleeps with the PC. |
| `icons/default/` | Blank cursor theme. Install to **both** locations below. |

## Install order

```sh
sudo apt install -y cage chromium wlr-randr

# 1. Cursor — both locations (see Cursor below for why both)
cp -a icons/default ~/.icons/default
sudo cp -a icons/default/cursors /usr/share/icons/default/cursors
sudo chown -R root:root /usr/share/icons/default/cursors

# 2. Kiosk launcher + units
sudo install -m 755 usr/local/bin/hwmon-kiosk.sh /usr/local/bin/hwmon-kiosk.sh
sudo cp -a etc/systemd/system/. /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hwmon-kiosk.service
sudo systemctl enable --now hwmon-kiosk-restart.timer

# 3. Panel watcher (user service, no sudo)
mkdir -p ~/.config/systemd/user ~/.local/bin
cp home/.config/systemd/user/hwmon-screen.service ~/.config/systemd/user/
install -m 755 home/.local/bin/hwmon-screen-watch.sh ~/.local/bin/
systemctl --user enable --now hwmon-screen.service
```

Optional, to allow remote restarts without a password:

```sh
echo 'pi ALL=(root) NOPASSWD: /usr/bin/systemctl restart hwmon-kiosk.service, /usr/bin/systemctl status hwmon-kiosk.service' \
  | sudo tee /etc/sudoers.d/hwmon-kiosk
```

## Cursor

The Pi has no pointer device, but cage still draws a cursor at its startup
position. Hiding it is fiddlier than it looks:

- cage/wlroots **never read `XCURSOR_THEME` or `XCURSOR_SIZE`** (`strings` finds
  neither in the binary or `libwlroots`). cage asks for the cursor named
  `left_ptr` from the theme named **`default`**, and wlroots honours only
  `XCURSOR_PATH`. A theme installed under any other name does nothing.
- wlroots draws **nothing** when a cursor name is missing from a theme, so a
  *visible* arrow can only mean the lookup reached
  `/usr/share/icons/default/index.theme` → `/etc/alternatives/x-cursor-theme` →
  `Inherits=Adwaita`.
- Hence both locations: `~/.icons/default/` is what normally answers, and
  `/usr/share/icons/default/cursors/` is the backstop that wins *before* the
  `Inherits` hop if anything about the environment differs at cage startup.
- CSS `cursor: none` in the dashboard cannot help — with no pointer device
  Chromium never receives a pointer enter. It is kept only as cover for a mouse
  being plugged in later.

## Restarting

```sh
ssh pi@<pi-ip> 'sudo -n systemctl restart hwmon-kiosk.service'
```

Frontend changes need this; server-side changes do not (the Pi holds no copy of
the code, only the URL). The panel can lag a restart — if a theme or layout
change looks like it did not apply, restart once more before assuming it failed.

Do **not** put the restart timer in `systemd --user`: with no ssh session open it
would be restarting the unit that owns its own login session. Use the root timer.
