# Piercing‑Dots

_A curated dotfiles collection + a keyboard-driven TUI settings menu for keeping your Linux machine updated and configured._

---

## 📦 What is Piercing‑Dots?

One repo that installs and maintains a full desktop setup: window manager configs, terminal tooling, GNOME customizations, and a set of maintenance scripts — all driven from the keyboard.

> **Warning:** the installer overwrites dotfiles in place — no backups. Read `install.sh` before running it on a machine you care about.

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
  - `PiercingXX-Settings-Menu/` – the TUI settings menu and its helper scripts.
  - `Control-Scripts/` – volume/brightness/notification helpers, WM session launchers, the keybind cheat sheet.
  - `Note-Scripts/` – `open_daily_note.sh` opens a Neovim buffer for daily notes.
- `resources/` – backgrounds, bash config, tmux config, fzf, greetd, cursors.
- `scripts/` – standalone setup scripts (`gnome-customizations.sh`, `gimp-mod.sh`, cursor theme installer, etc.).

---

## 📄 Settings Menu (`Super + S`)

The maintenance script of old evolved into a TUI settings menu, installed at `~/.scripts/PiercingXX-Settings-Menu/settings-menu.sh`:

- **Update System** – updates your entire system (distro packages, Neovim plugins, pip, npm, cargo, fwupd, flatpak, Docker, etc.), self-updates its own scripts from GitHub, and pulls your GitHub repos.
- **Terminal Software Manager** – fuzzy-find, install, and uninstall packages (repo, AUR, or Flathub) without touching a GUI store.
- **Audio Input Manager** – switch audio input/output; toggle outputs with `Super + O`.
- **WiFi Manager** – launches the NetworkManager TUI.
- **Bluetooth Manager** – launches bluetooth pairing.
- **Change Wallpaper** – works on Hyprland and GNOME.
- **Backup & Restore** – does what you think.
- **User Management** – yup, it does that.
- **Update PiercingXX Rice** – reinstall the dots. Options: everything / GIMP dots only / everything except Hyprland dots (still updates the keymap file) / GNOME customizations only.
- **Update Mirrors** – Arch only; finds the fastest mirrors.
- **Virus Scan** – runs a scan.
- **Clean System** – deletes file remnants, temp folders, and trash.

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

The script asks for your password when needed (`sudo`). Some steps (GNOME customizations, boot beep) are skipped automatically when they don't apply.

**Weather widget:** the eww weather scripts need an OpenWeatherMap API key. Set `OPENWEATHER_API_KEY` in your environment or put the key in `~/.config/openweather/api_key`.

---

## 🤝 Contributing

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes.
4. Open a Pull Request.

Please keep scripts POSIX-friendly and avoid hard-coded paths.

---

## 📄 License

MIT © PiercingXX
See the LICENSE file for details.

---

## 📞 Support & Contact

    Email: Don't

    Open an issue in the relevant repo instead. If it's a rant, make it entertaining.
