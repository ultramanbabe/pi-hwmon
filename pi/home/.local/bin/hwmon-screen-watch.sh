#!/bin/bash
# Blank the kiosk panel while the PC's hwmon server is unreachable, restore it when it returns.
set -u

HOST="${HWMON_HOST:-192.168.1.20}"
PORT="${HWMON_PORT:-8765}"
OUTPUT="${HWMON_OUTPUT:-HDMI-A-1}"
INTERVAL="${HWMON_INTERVAL:-5}"
FAILS_TO_BLANK="${HWMON_FAILS:-3}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# The kiosk compositor owns the socket; wait for it rather than racing it at boot.
while [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
  sleep 2
done

# Actual panel state comes from the kernel, so we stay in sync even if cage restarts.
actual_state() {
  for f in /sys/class/drm/card*-"$OUTPUT"/enabled; do
    [ -r "$f" ] || continue
    [ "$(cat "$f")" = enabled ] && echo on || echo off
    return
  done
  echo unknown
}

set_state() {
  case "$1" in
    on)  wlr-randr --output "$OUTPUT" --on  >/dev/null 2>&1 ;;
    off) wlr-randr --output "$OUTPUT" --off >/dev/null 2>&1 ;;
  esac
}

pc_up() {
  timeout 2 bash -c "exec 3<>/dev/tcp/$HOST/$PORT" 2>/dev/null
}

fails=0
want=on

while :; do
  if pc_up; then
    fails=0
    want=on
  else
    fails=$((fails + 1))
    [ "$fails" -ge "$FAILS_TO_BLANK" ] && want=off
  fi

  [ "$(actual_state)" != "$want" ] && set_state "$want"

  sleep "$INTERVAL"
done
