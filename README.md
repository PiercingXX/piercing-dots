# Piercing‑Dots

_A curated dotfiles collection + a keyboard-driven TUI settings menu for keeping your Linux machine updated and configured._

---

## 📦 What is Piercing‑Dots?

One repo that installs and maintains a full desktop setup: window manager configs, terminal tooling, GNOME customizations, and a set of maintenance scripts — all driven from the keyboard.

> **Heads up:** the installer replaces your dotfiles. It tars up everything it's about to overwrite into `~/.local/state/piercingxx/backups/` first, but read `install.sh` before running it on a machine you care about.

Normally this repo is pulled in by [linux-mod](https://github.com/PiercingXX/linux-mod), which handles packages, drivers and desktops for Arch, Artix, Debian/Ubuntu, Fedora, Void, openSUSE and Alpine, then runs `install.sh` here. It also works standalone.

### Highlights

- **Window Manager Dots** – Hyprland and GNOME are fully built out. Awesome, BSPWM, DWM, i3, Sway, and Qtile configs are included but mostly legacy/deprecated.
- **Waybar / Kitty / Neovim / Yazi / GIMP** – heavily customized into minimal but fully functional powerhouses. Neovim is set up to replace VS Code and Obsidian; GIMP gets a minimalist layout with classic shortcuts.
- **Settings Menu (TUI)** – hit `Super + S` and you're in a bash-driven settings menu. No GUI required.
- **Cheat Sheet** – `Super + /` opens the keybind cheat sheet in your browser.

---

## 🗂️ Repo Layout

- `install.sh` – deploys everything: dots, scripts, fonts/cursors, backgrounds, greetd config, keyboard layout (Colemak), GNOME customizations.
- `dots/` – configs copied into `~/.config` (Hyprland, kitty, nvim, yazi, waybar, eww, GIMP, and more).
- `resources/.scripts/` – installed to `~/.scripts`:
  - `lib/common.sh` – shared helpers (distro/init detection, package installs, notifications, WM detection). Everything else sources it.
  - `PiercingXX-Settings-Menu/` – the TUI settings menu and its helper scripts.
  - `Control-Scripts/` – volume/brightness/notification daemons, screenshots, clipboard, `start-wm` session launcher (`start-*` wrappers), `remote-session.sh`, `update-count.sh`, the keybind cheat sheet.
  - `Note-Scripts/` – `open_daily_note.sh` and `inventory.sh` (notes root: `PIERCINGXX_NOTES_ROOT`).
- `resources/` – backgrounds, bash config, tmux config, fzf, greetd, cursors.
- `scripts/` – standalone setup scripts:
  - `gnome-customizations.sh` – GNOME tweaks (see below).
  - `gimp-mod.sh` – GIMP layout; backs up your old config first.
  - `install-black-minimalistic-cursor.sh` – cursor theme.
  - `surface-kernel.sh` – linux-surface on Arch (linux-mod's Drivers menu is the canonical, multi-distro version).
  - `sfp-fiber-lockout-fix.sh` – unlocks third-party SFP+ modules on ixgbe NICs; does nothing without one.
  - `set_boot_beep.sh` – the startup beep (zeroes the boot menu timeout, beeps once booted). `install.sh` runs it by default.
  - `ollama-setup.sh` – installs Ollama (Arch package or upstream installer) and moves models to `OLLAMA_TARGET`; `--pull` grabs everything in `ollama-models.txt`.
  - `github-clone-all.sh` – clones every repo for an owner (`GITHUB_OWNER`, `GITHUB_BASE_DIR`, `GITHUB_REPO_LIMIT`, `GITHUB_SKIP_ARCHIVED`).
  - `install-git-vendor-trailer-hook.sh` – installs the commit-msg hook that strips AI-vendor `Co-authored-by` trailers (Skippy stays) into repos under `GIT_HOOK_ROOTS`.

---

## 📄 Settings Menu (`Super + S`)

The maintenance script of old evolved into a TUI settings menu, installed at `~/.scripts/PiercingXX-Settings-Menu/settings-menu.sh`:

- **Update System** – distro packages (all seven distro families, plus Ubuntu Touch/postmarketOS), AUR (interactive so you can review PKGBUILDs), flatpak, fwupd, Neovim/yazi plugins, cargo/npm/pipx/uv/rustup/gh extensions, Docker images, ClamAV signatures, your GitHub repos. On Arch it also checks Arch news, snapshots first if snapper/timeshift/snap-pac exist, recovers keyring errors, lists `.pacnew` files, flags when a reboot is needed, and runs `arch-audit`. Ends with a status table; logs live in `~/.local/state/piercingxx/logs/`. Self-updates `~/.scripts` last (`PX_NO_SELF_UPDATE=1` to skip).
- **Terminal Software Manager** – fuzzy-find, install, and uninstall packages (repo, AUR, or Flathub). Won't let you uninstall core packages.
- **Audio Input Manager** – switch audio input/output; toggle outputs with `Super + O`. Hide outputs with `PIERCINGXX_AUDIO_SKIP` (regex, default `IEC958`).
- **WiFi Manager** – `nmtui`, or `impala`/`iwctl` on iwd.
- **Bluetooth Manager** – `bluetui` (falls back to `bluetuith`/`bluetoothctl`), unblocks rfkill.
- **Change Wallpaper** – Hyprland (hyprpaper IPC), Sway, GNOME, and X11 WMs. Saves the pick as `~/.config/wall.png`.
- **Backup & Restore** – rsync with a dry-run preview and confirm every time. Mirror mode (deletes files missing from the source) is opt-in and refused for `$HOME` and system folders.
- **User Management** – add/remove users and manage groups. Removing a user means typing their name; root and yourself are off-limits.
- **Update PiercingXX Rice** – reinstall the dots. Shows what would change, backs up first, and can restore a previous backup.
- **Update Mirrors** – Arch-family only. Backs up the mirrorlist, ranks with reflector (or rate-mirrors / Manjaro / CachyOS / Artix tools), and refuses to install a bad list.
- **Virus Scan** – ClamAV, daemon-first. Fast / Downloads / Quick / Full / Custom scans with live results, real exit codes, a quarantine (report-only unless you say move), scan history, weekly scheduled scans, and an Integrity Audit (package file verification, rkhunter/chkrootkit/lynis/arch-audit, SUID/ssh-key/listening-port baselines, persistence and browser-extension checks). CLI: `--update-db`, `--status`, `--preset NAME --no-tui`.
- **Clean System** – pick what to clean, see sizes first: package cache (`paccache` keeps 2), AUR build cache, orphans, journal, tmpfiles, flatpak, Docker/Podman (never volumes), thumbnails, dev caches, closed-browser caches, trash (incl. external drives), plus reports for stale pacman locks, `.pacnew` files, old kernel modules, failed units and broken symlinks. Never touches Downloads. Flags: `--dry-run`, `--yes`, `--categories`, `--summary`, `--setup` (one-time: pacman-contrib + paccache/fstrim/reflector timers).
- **Firewall** – ufw (or firewalld) status, presets, and rules.
- **Services** – start/stop/enable systemd (system + user) units; basic support for runit/OpenRC/dinit/s6.
- **Logs** – journal errors, kernel, Hyprland, Xorg, package history.
- **Power** – power profiles (power-profiles-daemon / TLP / tuned) and hyprsunset.
- **Hardware Info** – CPU, memory, disks, PCI/USB, sensors, battery, disk usage.
- **Keyboard Layout** – switch layouts live (Hyprland, Sway, GNOME, X11), optionally persist it.

---

## 🚀 GNOME Customization

`scripts/gnome-customizations.sh` applies curated tweaks for a polished GNOME desktop:

- Applies configs for GNOME and several extensions (requires `dconf` and an active GNOME session).
- Simulates a tiling WM workflow — keybinds consistent with the Hyprland setup.
- Adjusts cursor/icon theme, backgrounds, fonts, panel layout, and accessibility options (Alt-Tab enhancements, focus-follows-mouse).

Run it from the `scripts` directory after logging into GNOME:

```
./gnome-customizations.sh
```

---

## 🛠️ Install

```
git clone https://github.com/PiercingXX/piercing-dots
cd piercing-dots
./install.sh
```

Run it as your normal user; it asks for `sudo` when needed. Steps that don't apply (GNOME without a session, greetd when it isn't installed, the SFP fix without an ixgbe card) are skipped.

Knobs (environment variables):

| Variable | Default | What it does |
|---|---|---|
| `PIERCINGXX_KEYMAP` / `PIERCINGXX_XKB_LAYOUT` / `PIERCINGXX_XKB_VARIANT` | Colemak | Console + X11 layout. `PIERCINGXX_KEYMAP=skip` leaves it alone. |
| `PIERCINGXX_BOOT_BEEP` | `1` | Startup beep. `0` to skip. |
| `PIERCINGXX_SFP_FIX` | auto (ixgbe only) | `1`/`0` to force. |
| `PIERCINGXX_POWER_SUDOERS` | `1` | Passwordless `shutdown`/`reboot` via `/etc/sudoers.d/piercingxx-power`. `0` to skip. |
| `PIERCINGXX_SET_PRETTY_NAME` | `1` | Brands `/etc/os-release`. `0` to skip. |
| `PIERCINGXX_CREATE_MEDIA_DIRS` | `0` | Create `/media/Working-Storage` + `/media/Archived-Storage` (linux-mod already does). |
| `PIERCINGXX_SKIP_GNOME` | `0` | Skip the GNOME customizations step. |
| `PIERCINGXX_WORK_ROOT` / `PIERCINGXX_ARCHIVE_ROOT` | `/media/Working-Storage` / `/media/Archived-Storage` | Where scripts look for your projects and archive drive. |

**Remote boxes:** `remote-session.sh` (and the `launch-*` wrappers) read hosts from `~/.config/piercingxx/remotes.conf`:

```
SERVER_HOST="user@server"
SKIPPY_HOST="user@skippy"
```

SSH keys/agent are used; no passwords pass through the scripts.

**Shell:** in the bundled `.bashrc`, `rm` sends files to the trash (`rmd` is the real `rm -rf`), `freshclam` runs `virus-scan.sh --update-db`, `greetd-fix` repairs the greetd login setup, and WM sessions start with `hypr`, `start-sway`, `start-i3`, `herb`, etc.

**Weather widget:** the eww weather scripts need an OpenWeatherMap API key. Set `OPENWEATHER_API_KEY` in your environment or put the key in `~/.config/openweather/api_key`.

---

## 🤝 Contributing

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes.
4. Open a Pull Request.

Please source `resources/.scripts/lib/common.sh` instead of re-rolling distro detection, colors or notifications, keep every distro branch working, and avoid hard-coded paths. CI runs `bash -n` and `shellcheck -S error` on every shell script.

---

## 📄 License

MIT © PiercingXX
See the LICENSE file for details.

---

## 📞 Support & Contact

    Email: Don't

    Open an issue in the relevant repo instead. If it's a rant, make it entertaining.
