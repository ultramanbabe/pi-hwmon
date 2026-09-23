#!/bin/sh
export XCURSOR_THEME=blank
export XCURSOR_PATH=/home/pi/.icons:/usr/share/icons
export XCURSOR_SIZE=1

# Chromium's error page has no JS to retry, so never launch into a dead server.
while ! timeout 2 bash -c "exec 3<>/dev/tcp/192.168.1.20/8765" 2>/dev/null; do
  sleep 5
done

exec /usr/lib/chromium/chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --no-default-browser-check \
  --check-for-update-interval=31536000 \
  --start-fullscreen \
  --force-device-scale-factor=1 \
  --window-size=1024,600 \
  --incognito \
  --disable-application-cache \
  --disk-cache-size=1 \
  http://192.168.1.20:8765
