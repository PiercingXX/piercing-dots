# Piercing‑Dots

_A curated dotfiles collection + a one‑stop Linux maintenance script._

---

## 📦 What is Piercing‑Dots?

**Piercing‑Dots** automates your Linux setup: updates your distro, cleans stale packages, and overwrites dotfiles—no backups.

- **maintenance.sh** – Detects your distro, updates system, auto-patches scripts.
- **terminal_software_manager.sh** – Installs/removes software from the terminal.
- **open_daily_note.sh** – Opens a Neovim buffer for daily notes (cloud sync optional).

### Favorite Configs

- **Window Manager Dots** – Hyprland, Awesome, BSPWM, i3, Sway.
- **GIMP** – Minimalist layout, classic shortcuts.
- **Yazi / Kitty** – Fast file navigation.
- **Gnome** – Consistent keybindings via customization.sh.
- **Neovim** – Setup to replace VS Code and Obsidian.

> **Tip:** Use automation, not GUIs, for package management.

---

## 🌟 The Dots

All dotfiles are in `dots`. Universal keybinds:
```
<Super>+<?> for full list
```

---

## 📄 maintenance.sh – Simplicity

The script will:

- Self-update from GitHub.
- Detect your distro and present a **whiptail menu**.
- Offer options to update the system, mirrors, install the full “Rice”, or just GIMP presets.
- Run universal updates (Neovim, pip, npm, cargo, fwupd, flatpak, Docker, Hyprland, etc).

---

## 🚀 Gnome Customization

The `gnome-customizations.sh` script applies curated tweaks for a polished Gnome desktop.

- Intended for use with any Distro-mod in this repo. Can be run separately (edit first to avoid issues).
- Applies configs for Gnome and several extensions (requires dconf).
- Simulates WMs like Hyprland; smoother than PopOS.
- Adjusts keybinds, cursor/icon theme, backgrounds, panel layout.
- Enables shortcuts and accessibility options (e.g., Alt‑Tab enhancements, focus‑follows‑mouse).
- Consistent color scheme and fonts across Gnome apps.

Run with:
```
./gnome-customizations.sh
```
from the `scripts` directory. Auto-detects user and applies changes.

---

## 🛠️ Usage

Choose an option:

- `Update System` – Updates OS.
- `Update Mirrors` – Refreshes Arch mirrors.
- `PiercingXX Rice` – Installs/updates the full dotfile set.
- `Piercing Gimp Only` – Installs only GIMP dots.
- `Rice-No Hyprland` – Installs everything except Hyprland config, but updates Hypr keybinds.
- `Reboot System` – Reboots.
- `Exit` – Quit.

> **Note:** The script will ask for your password when needed (e.g., `sudo`).

---

## 🤝 Contributing

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes.
4. Open a Pull Request.

Please keep `maintenance.sh` **POSIX-friendly** and avoid hard-coded paths.

---

## 📄 License

MIT © PiercingXX  
See the LICENSE file for details.

---

## 📞 Support & Contact

*Don't.*
