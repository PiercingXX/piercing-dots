# Piercing‑Dots

_A curated collection of dotfiles + a one‑stop distro-agnostic maintenance script for Linux._

---

## 📦 What is Piercing‑Dots?

Piercing‑Dots is my **personal dotfile repository** that includes a powerful, self‑updating Bash script.

- **All your favorite configs** (Gnome, Hyprland, BSPWM, Awesome, i3, Neovim, Kitty, Docker, etc.) are in one place.
- **One command** to keep your system, packages, and dotfiles in sync.
- **Distribution Agnostic** support (Arch, Fedora, Debian/Ubuntu/Pop!_OS, etc.).

---

## 🌟 The Dots

> All dotfiles are stored under 'dots'. Feel free to cherry‑pick or fork.

- The same keybinds are used universally (mostly) across all DEs
		```Hit "<Super>+<?>" to get the full list ```


---

## 📄 [maintenance.sh](vscode-file://vscode-app/opt/visual-studio-code/resources/app/out/vs/code/electron-browser/workbench/workbench.html) – Beautiful Simplicity 

The script will:

1. **Self‑update** from GitHub.
2. Detect your distro and present a **whiptail menu**.
3. Offer options to update the system, mirrors, install the full “Rice”, or just GIMP presets.
4. Run a suite of _universal_ updates (Neovim, pip, npm, cargo, fwupd, flatpak, Docker, Hyprland, …).

---

##  🚀 Gnome Customization - The Rice

The `gnome-customizations.sh` script applies a curated set of tweaks that give your Gnome desktop a polished, “Piercing‑style” look. It:

- This script is meant to be ran as a part of any of the Distro-mods I have in my git repo. It can be ran separately but edit it first so you aren't stuck with issues
- This will apply a number of configs for gnome itself as well as several Gnome-extensions. 
	- dconf* is required to run gnome-customizations.sh
- Simulates Window managers like Hyprland, simular to PopOS but smoother.
- Adjusts system settings such as **keybinds**, **cursor theme**, **icon theme**, **background settings**, and **panel layout**.
- Enables useful shortcuts and accessibility options (e.g., **Alt‑Tab** enhancements, **focus‑follows‑mouse**).
- Applies a consistent color scheme and font settings across all Gnome applications.

Running the script is as simple as `./gnome-customizations.sh` from the `scripts` directory, and it will automatically detect your user and apply the changes without further manual intervention.

---

## 🛠️ Usage

1. **Choose an option**
    - `Update System` – Updates OS .
    - `Update Mirrors` – Refreshes Arch mirrors.
    - `PiercingXX Rice` – Installs/Updates the full dotfile set.
    - `Piercing Gimp Only` – Installs only GIMP dots.
    - `Rice-No Hyprland` – Installs everything except Hyprland config but will still update the Hypr keybinds (useful when running same setup on multiple devices).
    - `Reboot System` – Reboots after 3 s.
    - `Exit` – Quit.

> **Note:** The script will ask for your password when needed (e.g., `sudo`).

---

## 🤝 Contributing

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes.
4. Open a Pull Request.

Please keep the [maintenance.sh](vscode-file://vscode-app/opt/visual-studio-code/resources/app/out/vs/code/electron-browser/workbench/workbench.html) script **POSIX‑friendly** and avoid hard‑coding paths.

---

## 📄 License

MIT © PiercingXX  
See the LICENSE file for details.

---

## 📞 Support & Contact
  
*Don't bothering me. I’ve got better things to do than explain why I didn't add a comment somewhere.* If you have suggestions, fork, hack, PR. I'd love to check it out.