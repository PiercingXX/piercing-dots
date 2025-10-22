# Piercing‑Dots

_A curated collection of dotfiles + a one‑stop distro-agnostic maintenance script for Linux._

---

## 📦 What is Piercing‑Dots?

**Piercing‑Dots** – *Your One‑Stop Shop for “Easy” Linux  

This single line will *obliterate* your current system state: it updates your distro, cleans stale packages, and **overwrites** your dotfiles *without* a backup—because who needs safety nets, right?  
    - **`maintenance.sh`** – Detects your distro, runs a full‑system update, and auto‑patches any script changes you push to this repo.  
    - **`terminal_software_manager.sh`** – Installs or removes *any* software from the terminal, even if you’ve forgotten the exact package name.  
    - **`open_daily_note.sh`** – Launches a fresh Neovim buffer for your daily musings, syncing to a cloud folder on my server (you’ll have to set that up yourself, genius).

The “Favorite” Configs (Because You’ll Never Be Satisfied)
    - **Window Manager Dots** – Hyprland, Awesome, BSPWM, i3, Sway – all pre‑tuned for maximum efficiency.  
    - **GIMP** – My *PiercingXX* layout strips away clutter, keeps the classic shortcuts, and looks like a minimalist’s wet dream.  
    - **Yazi / Kitty** – File navigation so slick it feels like a dance.  
    - **Gnome** – A full‑blown `customization.sh` that emulates the keybindings of the WM’s above, because why not be consistent?  
    - **Neovim** – *PiercingXX* setup to replace both VS Code and Obsidian; it’s the future, not the past.

> **Bottom line:** If you’re still using a GUI to manage packages, you’re living in the Stone Age. Grab this repo and let the automation do the heavy lifting while you sit back and marvel at your newfound efficiency.



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

The `gnome-customizations.sh` script applies a curated set of tweaks that give your Gnome desktop a polished look.

- This script is meant to be ran as a part of any of the Distro-mods I have in my git repo. It can be ran separately but edit it first so you aren't stuck with issues.
- This will apply a number of configs for gnome itself as well as several Gnome-extensions. 
	- dconf* is required to run gnome-customizations.sh
- Simulates Window Managers like Hyprland, simular to PopOS but smoother.
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
    - `Reboot System` – Does what you think it will.
    - `Exit` – Quit.

> **Note:** The script will ask for your password when needed (e.g., `sudo`).


<img width="961" height="775" alt="2025-08-26-190921_hyprshot" src="https://github.com/user-attachments/assets/ce7b6549-24b8-40ab-b648-10589cc57fdd" />

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
  
*Don't.*
