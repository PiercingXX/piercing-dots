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

- Piercing‑Dots
	- One repo to keep your machine updated and configured
	- Hyprland and Gnome are fully built out. Awesome/BSPWM/i3/Sway are mostly there/depreciated
	- Waybar, kitty, Neovim, Yazi, GIMP are all heavily customized into minimal yet fully functional power houses.
	- Maintenance and software manager scripts so you stop copy‑pasting from blogs
	- '<Super> /' will open your Cheat Sheet
- Bash driven Settings Menu
	- Dont leave the keyboard, '<Super> S' and your in my settings menu


---

## 📄 Bash Driven Settings Menu – Simplicity

The scripts will:

The update script will
    - Update your entire system (Neovim, pip, npm, cargo, fwupd, flatpak, Docker, Hyprland, etc)
    - Self-update its ofn scropts from the PiercingXX GitHub.
    - Update your github repos 
Terminal Software Manager
    - Don't use gnome software or search the AUR of Flathub
    - This will allow you to fuzzy find all available install options for whatever you're looking for.
    - You can also uninstall anything on your system with this.
Audio Input Manager
    - Easily switch input and output audio
    - Toggle through audio output with '<SUPER> O'
Wifi manager
    - Launches Network Manager TUI
Bluetooth Manager
    - Launches 
Change Wallpaper
    - Does just that on Hyprland and Gnome. 
Backup & Restore
    - Does what you think
User Management
    - Yup it does that
Update Piercing Rice
    - This will install one of 4 options
        -Everything - All dots, scripts, customizations, everything.
        -GIMP dot files only
        -All dotfiles and scripts and gnome customizations without Hyprland dots (this will still replace the keymap file)
        -Gnome Customizations only
Update Mirrors
    - This is only available for Arch, will find the fastest mirrors and update them.
Clean System
    - Deletes file remnants, temp folders, and trash.

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

    Email: Don’t

    Open an issue in the relevant repo instead. If it’s a rant, make it entertaining.