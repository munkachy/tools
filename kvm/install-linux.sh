#!/usr/bin/env bash
# Make the Linux side of a shared keyboard/mouse setup start by itself at
# every login and reconnect on its own. Works with Deskflow, Input Leap, or
# Barrier (whichever is installed).
#
# One-line install straight from GitHub (asks for the Mac's name):
#   curl -fsSL https://raw.githubusercontent.com/munkachy/tools/main/kvm/install-linux.sh | bash
#
# Or, from a copy of this file:
#   ./install-linux.sh <mac-address-or-name> [this-screen-name]
#   ./install-linux.sh --test      # run once in the foreground to see errors
#   ./install-linux.sh --uninstall
set -euo pipefail

CONF_DIR="$HOME/.config/kvm-client"
CONF="$CONF_DIR/settings"
RUNNER="$HOME/.local/bin/kvm-client-run"
AUTOSTART="$HOME/.config/autostart/kvm-client.desktop"
LOG="$CONF_DIR/client.log"

die() { echo "Error: $*" >&2; exit 1; }

find_client() {
  for b in deskflow-client deskflow-core input-leapc barrierc; do
    if command -v "$b" >/dev/null 2>&1; then echo "$b"; return; fi
  done
  # Flatpak installs
  if command -v flatpak >/dev/null 2>&1; then
    flatpak info org.deskflow.deskflow >/dev/null 2>&1 && { echo "flatpak:org.deskflow.deskflow"; return; }
    flatpak info io.github.input_leap.input-leap >/dev/null 2>&1 && { echo "flatpak:io.github.input_leap.input-leap"; return; }
  fi
  echo ""
}

case "${1:-}" in
  --uninstall)
    pkill -f "$RUNNER" 2>/dev/null || true
    rm -f "$RUNNER" "$AUTOSTART"
    echo "Removed. Your settings are still in $CONF_DIR (delete it if you like)."
    exit 0 ;;
  --test)
    [ -f "$CONF" ] || die "Run the installer first."
    exec "$RUNNER" --once ;;
  -h|--help)
    cat <<'HELP'
Usage:
  install-linux.sh <mac-address-or-name> [this-screen-name]
  install-linux.sh --test        run once in the foreground to see errors
  install-linux.sh --uninstall   remove it
HELP
    exit 0 ;;
esac

# Ask for anything not given on the command line. Read from the terminal, not
# stdin, because stdin is the script itself when run as "curl ... | bash".
ask() {
  local prompt="$1" default="$2" reply=""
  if [ -r /dev/tty ]; then
    read -r -p "$prompt${default:+ [$default]}: " reply < /dev/tty || true
  fi
  echo "${reply:-$default}"
}

SERVER="${1:-}"
if [ -z "$SERVER" ]; then
  echo "The Mac's name is in System Settings > General > Sharing, at the bottom"
  echo "(\"Local hostname\", something like Brothers-iMac.local)."
  SERVER="$(ask "Mac's name or IP address" "")"
  [ -n "$SERVER" ] || die "No Mac name given."
  NAME="$(ask "This computer's screen name (must match the Mac's layout)" "$(hostname -s)")"
else
  NAME="${2:-$(hostname -s)}"
fi
CLIENT="$(find_client)"
[ -n "$CLIENT" ] || die "No Deskflow, Input Leap, or Barrier client found. Install one first (see README)."

# Barrier needs crypto switched on to match its server default.
EXTRA=""
[ "$CLIENT" = "barrierc" ] && EXTRA="--enable-crypto"

mkdir -p "$CONF_DIR" "$(dirname "$RUNNER")" "$(dirname "$AUTOSTART")"

cat > "$CONF" <<CONF
# Settings for kvm-client-run. Edit, then log out and back in (or reboot).
# SERVER is the Mac. Using its ".local" name (e.g. Brothers-iMac.local)
# keeps working even if the Mac's IP address changes.
SERVER="$SERVER"
PORT="24800"
# Must match the screen name you placed LEFT of the Mac in the server layout.
NAME="$NAME"
CLIENT="$CLIENT"
# Extra flags for the client program, if you need them.
EXTRA="$EXTRA"
CONF

cat > "$RUNNER" <<'RUN'
#!/usr/bin/env bash
# Keeps the keyboard/mouse client running. Started at login.
CONF="$HOME/.config/kvm-client/settings"
LOG="$HOME/.config/kvm-client/client.log"
# shellcheck disable=SC1090
. "$CONF"

client_cmd() {
  case "$CLIENT" in
    deskflow-core) echo deskflow-core client ;;
    flatpak:org.deskflow.deskflow) echo flatpak run --command=deskflow-client org.deskflow.deskflow ;;
    flatpak:io.github.input_leap.input-leap) echo flatpak run --command=input-leapc io.github.input_leap.input-leap ;;
    *) echo "$CLIENT" ;;
  esac
}

# Stop any copy already running (ours or one left from the app's own window),
# so two clients don't fight over the same name.
pkill -x deskflow-client 2>/dev/null; pkill -x input-leapc 2>/dev/null; pkill -x barrierc 2>/dev/null

run_once() {
  # shellcheck disable=SC2046,SC2086
  $(client_cmd) -f --no-tray --name "$NAME" $EXTRA "$SERVER:$PORT"
}

if [ "${1:-}" = "--once" ]; then run_once; exit $?; fi

# Give the desktop and network a moment after login.
sleep 5
while true; do
  echo "$(date '+%F %T') starting client -> $SERVER:$PORT as $NAME" >> "$LOG"
  run_once >> "$LOG" 2>&1
  echo "$(date '+%F %T') client stopped (code $?); retrying in 5s" >> "$LOG"
  # Keep the log from growing forever.
  tail -n 500 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
  sleep 5
done
RUN
chmod +x "$RUNNER"

cat > "$AUTOSTART" <<DESK
[Desktop Entry]
Type=Application
Name=Keyboard & Mouse from Mac
Comment=Connects to the Mac so its keyboard and mouse can move over to this screen
Exec=$RUNNER
X-GNOME-Autostart-enabled=true
NoDisplay=false
DESK

echo "Installed."
echo "  Client program: $CLIENT"
echo "  Connects to:    $SERVER:24800"
echo "  Screen name:    $NAME"
echo
echo "It starts by itself every time you log in."
# Start it now too, if we're inside a desktop session.
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  pkill -f "$RUNNER" 2>/dev/null || true
  setsid nohup "$RUNNER" >/dev/null 2>&1 < /dev/null &
  echo "It's running now as well. Try moving the Mac's mouse off the left edge."
else
  echo "Log in to the desktop (or reboot) to start it."
fi
echo "Log file: $LOG"
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  echo
  echo "Note: you are on Wayland. See the README section on Wayland; this is the"
  echo "most common reason the connection 'forgets' itself after a reboot."
fi
