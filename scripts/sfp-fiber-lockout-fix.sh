#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
ixgbe SFP+ vendor-unlock & power management helper (Intel 82599 / X520-2)

Usage:
  sudo ./ixgbe-sfp-unlock.sh [COMMAND] [OPTIONS]

Commands:
  sfp-unlock    SFP+ vendor unlock operations (default)
  power-mgmt    Intel ixgbe power management fix (D3cold issues)

SFP+ Unlock Options:
  --status      Show current ixgbe parameter value, default route, and ixgbe ifaces.
  --apply       Persistently set: options ixgbe allow_unsupported_sfp=1
  --reload      Unload/reload ixgbe so the setting takes effect immediately (briefly drops ixgbe links).
  --force       Allow reload even if default route uses ixgbe (risk: drop SSH).

Power Management Options:
  --detect      Detect Intel ixgbe devices and their power state
  --fix         Apply power management fixes (udev rule + per-device settings)
  --verify      Check current power control status
  --undo        Revert power management changes

Global Options:
  --dry-run     Print actions without changing anything.
  -h, --help    Show this help message.

Examples:
  sudo ./ixgbe-sfp-unlock.sh sfp-unlock --status
  sudo ./ixgbe-sfp-unlock.sh sfp-unlock --apply --reload
  sudo ./ixgbe-sfp-unlock.sh power-mgmt --detect
  sudo ./ixgbe-sfp-unlock.sh power-mgmt --fix
  sudo ./ixgbe-sfp-unlock.sh power-mgmt --verify
  sudo ./ixgbe-sfp-unlock.sh power-mgmt --undo

Supported Distributions:
  Debian, Ubuntu, Pop!_OS, Arch Linux, Fedora, RHEL/CentOS
EOF
}

# SFP Unlock options
DO_STATUS=0
DO_APPLY=0
DO_RELOAD=0
FORCE=0

# Power Management options
PM_DETECT=0
PM_FIX=0
PM_VERIFY=0
PM_UNDO=0

# Global options
DRYRUN=0
COMMAND="sfp-unlock"

log() { printf '%s\n' "$*"; }
run() {
  if (( DRYRUN )); then
    log "[dry-run] $*"
  else
    eval "$@"
  fi
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "ERROR: run as root (use sudo)."
    exit 1
  fi
}

detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-unknown}"
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/fedora-release ]]; then
    echo "fedora"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  else
    echo "unknown"
  fi
}

install_dependencies() {
  local distro packages_needed=""
  
  # Check if ethtool is installed
  if ! command -v ethtool >/dev/null 2>&1; then
    packages_needed="ethtool"
  fi
  
  # If no packages needed, return
  [[ -z "$packages_needed" ]] && return 0
  
  distro="$(detect_distro)"
  log "Installing required packages: $packages_needed"
  
  case "$distro" in
    debian|ubuntu|pop)
      if (( DRYRUN )); then
        log "[dry-run] apt-get update && apt-get install -y $packages_needed"
      else
        apt-get update -qq && apt-get install -y $packages_needed
      fi
      ;;
    arch|manjaro)
      if (( DRYRUN )); then
        log "[dry-run] pacman -Sy --noconfirm $packages_needed"
      else
        pacman -Sy --noconfirm $packages_needed
      fi
      ;;
    fedora|rhel|centos)
      if (( DRYRUN )); then
        log "[dry-run] dnf install -y $packages_needed"
      else
        dnf install -y $packages_needed
      fi
      ;;
    *)
      log "WARNING: Unknown distribution ($distro). Please install manually: $packages_needed"
      log "  Debian/Ubuntu/Pop!_OS: sudo apt-get install -y $packages_needed"
      log "  Arch Linux: sudo pacman -S $packages_needed"
      log "  Fedora: sudo dnf install -y $packages_needed"
      exit 1
      ;;
  esac
  
  log "Dependencies installed successfully."
}

default_route_iface() {
  ip route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1
}

iface_driver() {
  local iface="$1"
  if command -v ethtool >/dev/null 2>&1; then
    ethtool -i "$iface" 2>/dev/null | awk -F': ' '$1=="driver"{print $2}' | head -n1
  else
    echo ""
  fi
}

ixgbe_param_path() {
  echo "/sys/module/ixgbe/parameters/allow_unsupported_sfp"
}

ixgbe_param_value() {
  local p
  p="$(ixgbe_param_path)"
  if [[ -f "$p" ]]; then
    cat "$p" 2>/dev/null || true
  else
    echo "(ixgbe not loaded / no param file)"
  fi
}

list_ixgbe_ifaces() {
  # Needs ethtool for accurate mapping. If missing, return empty.
  command -v ethtool >/dev/null 2>&1 || return 0

  local iface
  for iface in /sys/class/net/*; do
    iface="${iface##*/}"
    [[ "$iface" == "lo" ]] && continue
    if ethtool -i "$iface" 2>/dev/null | awk -F': ' '$1=="driver"{print $2}' | grep -qx "ixgbe"; then
      echo "$iface"
    fi
  done
}

apply_config() {
  local conf="/etc/modprobe.d/ixgbe-allow-unsupported-sfp.conf"
  log "Writing: $conf"
  run "printf '%s\n' 'options ixgbe allow_unsupported_sfp=1' > '$conf'"

  # Rebuild initramfs if the system uses one that might preload ixgbe.
  # Debian/Ubuntu/Pop!_OS use update-initramfs
  if command -v update-initramfs >/dev/null 2>&1; then
    log "Initramfs: update-initramfs -u (Debian/Ubuntu/Pop!_OS)"
    run "update-initramfs -u || true"
  # Arch Linux uses mkinitcpio
  elif command -v mkinitcpio >/dev/null 2>&1; then
    log "Initramfs: mkinitcpio -P (Arch Linux)"
    run "mkinitcpio -P || true"
  # Fedora/RHEL/CentOS use dracut
  elif command -v dracut >/dev/null 2>&1; then
    log "Initramfs: dracut --force (Fedora/RHEL)"
    run "dracut --force || true"
  else
    log "WARNING: Initramfs tool not found; skipping rebuild."
    log "  Changes will take effect after reboot or manual module reload."
  fi
}

reload_ixgbe() {
  local defif defdrv ifaces
  defif="$(default_route_iface || true)"

  if [[ -n "$defif" ]]; then
    defdrv="$(iface_driver "$defif" || true)"
    if [[ "$defdrv" == "ixgbe" && $FORCE -eq 0 ]]; then
      log "Refusing to reload ixgbe: default route uses $defif (ixgbe)."
      log "Re-run with --force if you accept the risk of dropping SSH."
      exit 2
    fi
  fi

  ifaces="$(list_ixgbe_ifaces || true)"
  log "Reloading ixgbe (links will drop briefly on: ${ifaces:-'(unknown; ethtool missing?)'})"

  if [[ -n "$ifaces" ]]; then
    while read -r i; do
      [[ -z "$i" ]] && continue
      run "ip link set '$i' down || true"
    done <<<"$ifaces"
  fi

  run "modprobe -r ixgbe"
  run "modprobe ixgbe"

  if [[ -n "$ifaces" ]]; then
    while read -r i; do
      [[ -z "$i" ]] && continue
      run "ip link set '$i' up || true"
    done <<<"$ifaces"
  fi
}

status() {
  log "Kernel: $(uname -r)"
  log "Distribution: $(detect_distro)"
  log "Default route iface: $(default_route_iface || true)"
  log "ixgbe loaded: $(lsmod | awk '$1==\"ixgbe\"{print \"yes\"; found=1} END{if(!found) print \"no\"}')"
  log "allow_unsupported_sfp: $(ixgbe_param_value)"
  if command -v ethtool >/dev/null 2>&1; then
    log "ixgbe ifaces:"
    list_ixgbe_ifaces || true
  else
    log "WARNING: ethtool not installed; cannot list ixgbe interfaces."
    log "  Dependencies will be auto-installed when using --apply or --reload."
  fi
}

# ============================================================================
# Power Management Functions
# ============================================================================

detect_ixgbe_devices() {
  local devices
  devices=$(lspci -d 8086: 2>/dev/null | grep -iE "ethernet|network" | grep -E "82599|X520|X540|X550" || true)
  
  if [[ -z "$devices" ]]; then
    log "WARNING: No Intel X520/82599 network cards detected via lspci"
    log "  The fixes will still be applied system-wide for PCIe power management."
    return 1
  else
    log "Detected Intel ixgbe devices:"
    echo "$devices" | sed 's/^/  /'
    return 0
  fi
}

get_ixgbe_pci_addrs() {
  lspci -d 8086: 2>/dev/null | grep -iE "ethernet|network" | grep -E "82599|X520|X540|X550" | awk '{print $1}' || true
}

pm_fix_immediate() {
  local addr pci_path current
  log "Applying immediate power management fix..."
  
  local addrs
  addrs="$(get_ixgbe_pci_addrs)"
  
  if [[ -z "$addrs" ]]; then
    log "  (No ixgbe devices found for immediate fix)"
    return 0
  fi
  
  while read -r addr; do
    [[ -z "$addr" ]] && continue
    pci_path="/sys/bus/pci/devices/0000:${addr}"
    if [[ -f "${pci_path}/power/control" ]]; then
      current=$(cat "${pci_path}/power/control" 2>/dev/null || echo "unknown")
      run "echo 'on' > '${pci_path}/power/control'"
      log "  ✓ Set 0000:${addr} power/control to: on"
    else
      log "  ⚠ Could not find ${pci_path}/power/control"
    fi
  done <<<"$addrs"
}

pm_create_udev_rule() {
  local udev_rule="/etc/udev/rules.d/99-ixgbe-power-control.rules"
  
  log "Creating persistent udev rule: $udev_rule"
  
  if (( DRYRUN )); then
    log "[dry-run] Would create udev rule at: $udev_rule"
  else
    run "cat > '$udev_rule' << 'EOFUDEV'
# Disable runtime PM for Intel ixgbe network cards to prevent D3cold power state issues
ACTION==\"add\", SUBSYSTEM==\"pci\", ATTR{vendor}==\"0x8086\", ATTR{device}==\"0x10fb\", ATTR{power/control}=\"on\"
ACTION==\"add\", SUBSYSTEM==\"pci\", ATTR{vendor}==\"0x8086\", ATTR{device}==\"0x1528\", ATTR{power/control}=\"on\"
ACTION==\"add\", SUBSYSTEM==\"pci\", ATTR{vendor}==\"0x8086\", ATTR{device}==\"0x1563\", ATTR{power/control}=\"on\"
EOFUDEV"
    log "  ✓ Created udev rule"
  fi
  
  run "udevadm control --reload-rules"
  run "udevadm trigger --subsystem-match=pci --attr-match=vendor=0x8086"
  log "  ✓ Reloaded udev rules"
}

pm_update_modprobe() {
  local modprobe_file="/etc/modprobe.d/ixgbe-power-management.conf"
  
  log "Creating per-device power management modprobe config..."
  
  if (( DRYRUN )); then
    log "[dry-run] Would create modprobe config at: $modprobe_file"
  else
    run "cat > '$modprobe_file' << 'EOFMOD'
# Intel ixgbe power management - targets ixgbe driver only
options ixgbe allow_unsupported_sfp=1
EOFMOD"
    log "  ✓ Created per-device ixgbe modprobe config"
  fi
}

pm_regenerate_grub() {
  local distro
  distro="$(detect_distro)"
  
  log "Regenerating GRUB bootloader..."
  case "$distro" in
    debian|ubuntu|pop|devuan)
      if command -v update-grub &>/dev/null; then
        run "update-grub"
        log "  ✓ GRUB updated (update-grub)"
      else
        log "  ERROR: update-grub not found"
        return 1
      fi
      ;;
    fedora|rhel|centos|rocky)
      if command -v grub2-mkconfig &>/dev/null; then
        run "grub2-mkconfig -o /boot/grub2/grub.cfg"
        log "  ✓ GRUB2 updated (grub2-mkconfig)"
      else
        log "  ERROR: grub2-mkconfig not found"
        return 1
      fi
      ;;
    arch|manjaro)
      if command -v grub-mkconfig &>/dev/null; then
        run "grub-mkconfig -o /boot/grub/grub.cfg"
        log "  ✓ GRUB updated (grub-mkconfig)"
      else
        log "  ERROR: grub-mkconfig not found"
        return 1
      fi
      ;;
    *)
      log "  WARNING: Unknown distribution ($distro)"
      log "  Please manually update GRUB bootloader"
      return 1
      ;;
  esac
}

pm_fix() {
  log "======================================"
  log "Intel ixgbe Power Management Fix"
  log "======================================"
  log ""
  
  detect_ixgbe_devices || true
  log ""
  
  pm_fix_immediate
  log ""
  
  pm_create_udev_rule
  log ""
  
  pm_update_modprobe
  log ""
  
  log "======================================"
  log "Power Management Fix Applied!"
  log "======================================"
  log ""
  log "Summary of changes:"
  log "  1. Disabled runtime PM for ixgbe cards (immediate)"
  log "  2. Created udev rule: /etc/udev/rules.d/99-ixgbe-power-control.rules"
  log "  3. Created per-device ixgbe modprobe config: /etc/modprobe.d/ixgbe-power-management.conf"
  log ""
  log "NOTE: These changes target Intel ixgbe devices specifically and do NOT"
  log "affect other PCIe devices (unlike system-wide ASPM changes)."
  log ""
  log "Reboot is recommended to ensure all changes take full effect."
  log ""
  log "To verify power state after reboot:"
  log "  sudo dmesg -T | grep -i 'ixgbe.*power\\|D3cold'"
  log ""
}

pm_detect() {
  log "======================================"
  log "Intel ixgbe Power Management Detection"
  log "======================================"
  log ""
  
  if ! detect_ixgbe_devices; then
    log "No Intel ixgbe devices detected."
    return 0
  fi
  
  log ""
  log "Current power control status:"
  local addrs
  addrs="$(get_ixgbe_pci_addrs)"
  
  if [[ -n "$addrs" ]]; then
    while read -r addr; do
      [[ -z "$addr" ]] && continue
      local pci_path="/sys/bus/pci/devices/0000:${addr}"
      local status="unknown"
      [[ -f "${pci_path}/power/control" ]] && status=$(cat "${pci_path}/power/control")
      log "  0000:${addr}: $status"
    done <<<"$addrs"
  fi
  
  log ""
  log "GRUB pcie_aspm setting:"
  if grep -q "pcie_aspm=off" /etc/default/grub 2>/dev/null; then
    log "  ✓ pcie_aspm=off is configured"
  else
    log "  ✗ pcie_aspm=off NOT configured (may need fixes)"
  fi
  
  log ""
}

pm_verify() {
  log "======================================"
  log "Power Management Verification"
  log "======================================"
  log ""
  
  log "Checking for power-related errors in dmesg..."
  if dmesg -T 2>/dev/null | grep -iE 'ixgbe.*power|D3cold|ASPM' | tail -5; then
    echo ""
  else
    log "  (No recent power-related messages found)"
  fi
  
  log ""
  log "Checking GRUB configuration:"
  grep "^GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub 2>/dev/null || \
    log "  Could not read GRUB config"
  
  log ""
  log "Checking udev rule:"
  if [[ -f /etc/udev/rules.d/99-ixgbe-power-control.rules ]]; then
    log "  \u2713 Udev rule exists"
  else
    log "  \u2717 Udev rule NOT found"
  fi
  
  log ""
  log "Checking ixgbe modprobe config:"
  if [[ -f /etc/modprobe.d/ixgbe-power-management.conf ]]; then
    log "  \u2713 Modprobe config exists"
  else
    log "  \u2717 Modprobe config NOT found"
  fi
  
  log ""
}

pm_undo() {
  log "======================================"
  log "Reverting Power Management Changes"
  log "======================================"
  log ""
  
  local files_removed=0
  
  # Remove udev rule
  if [[ -f /etc/udev/rules.d/99-ixgbe-power-control.rules ]]; then
    log "Removing udev rule..."
    run "rm -f /etc/udev/rules.d/99-ixgbe-power-control.rules"
    log "  \u2713 Removed: /etc/udev/rules.d/99-ixgbe-power-control.rules"
    ((files_removed++))
  else
    log "Udev rule not found (already removed)"
  fi
  
  log ""
  
  # Remove modprobe config
  if [[ -f /etc/modprobe.d/ixgbe-power-management.conf ]]; then
    log "Removing ixgbe modprobe config..."
    run "rm -f /etc/modprobe.d/ixgbe-power-management.conf"
    log "  \u2713 Removed: /etc/modprobe.d/ixgbe-power-management.conf"
    ((files_removed++))
  else
    log "Modprobe config not found (already removed)"
  fi
  
  log ""
  
  # Reload udev rules
  log "Reloading udev rules..."
  run "udevadm control --reload-rules"
  run "udevadm trigger --subsystem-match=pci"
  log "  \u2713 udev rules reloaded"
  
  log ""
  
  if (( files_removed > 0 )); then
    log "======================================"
    log "Changes Reverted Successfully!"
    log "======================================"
    log ""
    log "Removed $files_removed configuration file(s)."
    log ""
    log "NOTE: Runtime power management will resume on next reboot."
    log "To verify the reversal, reload the ixgbe module:"
    log "  sudo modprobe -r ixgbe && sudo modprobe ixgbe"
    log ""
  else
    log "======================================"
    log "No Power Management Changes Found"
    log "======================================"
    log ""
    log "The fixes do not appear to be currently applied."
    log ""
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      sfp-unlock)
        COMMAND="sfp-unlock"
        shift
        ;;
      power-mgmt)
        COMMAND="power-mgmt"
        shift
        ;;
      # SFP unlock options
      --status) DO_STATUS=1; shift ;;
      --apply) DO_APPLY=1; shift ;;
      --reload) DO_RELOAD=1; shift ;;
      --force) FORCE=1; shift ;;
      # Power management options
      --detect) PM_DETECT=1; shift ;;
      --fix) PM_FIX=1; shift ;;
      --verify) PM_VERIFY=1; shift ;;
      --undo) PM_UNDO=1; shift ;;
      # Global options
      --dry-run) DRYRUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) log "ERROR: Unknown argument: $1"; usage; exit 1 ;;
    esac
  done

  need_root

  # Route to appropriate command
  case "$COMMAND" in
    sfp-unlock)
      if (( !DO_STATUS && !DO_APPLY && !DO_RELOAD )); then
        usage
        exit 0
      fi
      install_dependencies
      (( DO_STATUS )) && status
      (( DO_APPLY )) && apply_config
      (( DO_RELOAD )) && reload_ixgbe
      if (( DO_APPLY || DO_RELOAD )); then
        log "Final allow_unsupported_sfp: $(ixgbe_param_value)"
      fi
      ;;
    power-mgmt)
      if (( !PM_DETECT && !PM_FIX && !PM_VERIFY && !PM_UNDO )); then
        log "ERROR: power-mgmt requires one of: --detect, --fix, --verify, --undo"
        echo ""
        usage
        exit 1
      fi
      (( PM_DETECT )) && pm_detect
      (( PM_FIX )) && pm_fix
      (( PM_VERIFY )) && pm_verify
      (( PM_UNDO )) && pm_undo
      ;;
    *)
      log "ERROR: Unknown command: $COMMAND"
      usage
      exit 1
      ;;
  esac
}

main "$@"