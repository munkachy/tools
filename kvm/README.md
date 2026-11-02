# One keyboard and mouse for the Mac and the Linux desktop

Push the mouse off the **left edge** of the Mac screen and it shows up on
the Linux screen. The Apple keyboard follows it. Move back to the right and
you're on the Mac again.

The sharing itself is done by a free program (Deskflow, Input Leap, or
Barrier). That part already worked for you. What broke was that **the Linux
side didn't start again after a reboot.** This folder fixes that: the Linux
computer starts the connection by itself every time you log in, and if the
connection drops (the Mac sleeps, Wi-Fi blips), it keeps trying until it's
back.

## On the Mac (the "server": it owns the keyboard and mouse)

1. Open Deskflow (or whatever you were using) and choose **Server**.
2. In the screen layout, drag a new screen to the **left** of the Mac.
   Name it exactly what the Linux computer will call itself (the installer
   uses its hostname by default, e.g. `monk-linux`).
3. In the app's settings, turn on **Start when I log in** (or add it under
   System Settings > General > Login Items).
4. Allow it under System Settings > Privacy & Security > **Accessibility**.
   Without this the Mac won't let it move your mouse.
5. Find the Mac's network name: System Settings > General > Sharing, at the
   bottom ("Local hostname"). It looks like `Brothers-iMac.local`. Use this
   name instead of an IP address, so it still works if the Mac's address
   changes after a reboot.

## On Linux (the "client")

Install the same program you use on the Mac, if it isn't already there.
On Ubuntu/Debian/Mint, `sudo apt install input-leap` (or `barrier`) works;
Deskflow is on Flathub.

Then open a terminal on the Linux desktop and paste this one line:

```bash
curl -fsSL https://raw.githubusercontent.com/munkachy/tools/main/kvm/install-linux.sh | bash
```

It asks two questions: the Mac's name (e.g. `Brothers-iMac.local`) and
what to call this screen (just press Enter to keep the computer's name,
unless you named it something else in the Mac's layout). It starts the
connection right away, and again at every login.

Reboot the Linux computer once to prove it comes back on its own.

To answer the questions up front instead (handy for a script):

```bash
curl -fsSL https://raw.githubusercontent.com/munkachy/tools/main/kvm/install-linux.sh | bash -s -- Brothers-iMac.local monk-linux
```

Running the same line again later is safe; it just updates the settings.

**Turn off the program's own client.** If the Deskflow/Input Leap window on
Linux is also set to start at login, switch that off. Two clients with the
same name knock each other off the server.

## If it doesn't connect

- **See the error directly:** add ` -s -- --test` to the end of the install
  line (so it ends `| bash -s -- --test`). That runs the client in
  the window so you can read what it says. Ctrl+C stops it.
- **Read the log:** `~/.config/kvm-client/client.log`
- **"Unknown screen name"**: the name on Linux doesn't match the screen you
  placed on the Mac. Fix one of them.
- **Can't find the Mac**: try the Mac's IP address instead of the `.local`
  name. If that works, give the Mac a fixed address in your router so it
  never changes.
- **Encryption/TLS mismatch**: open `~/.config/kvm-client/settings` and add
  or remove `--enable-crypto` on the `EXTRA=` line so it matches the Mac.
- **Change any setting later**: edit `~/.config/kvm-client/settings`, then log
  out and back in.

## Wayland: the most likely reason it kept "forgetting"

Newer Linux desktops (Ubuntu 22.04+ and Fedora with GNOME, recent KDE) use
**Wayland**. Under Wayland, a program isn't allowed to move your mouse until
you click "Allow" in a pop-up, and on many systems that pop-up comes back
**after every reboot**. Barrier and older Input Leap don't work on Wayland
at all.

Check what you're on: `echo $XDG_SESSION_TYPE`

If it says `wayland`, the simplest permanent fix is to log in with the
"Xorg" session instead. On the login screen, click your name, then the small
gear in the corner, and pick **Ubuntu on Xorg** (or **GNOME on Xorg** /
**Plasma (X11)**). The system remembers that choice, and the installer above
then works with no pop-ups.

## Removing it

```bash
curl -fsSL https://raw.githubusercontent.com/munkachy/tools/main/kvm/install-linux.sh | bash -s -- --uninstall
```
