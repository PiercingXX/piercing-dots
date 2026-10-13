#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
ixgbe SFP+ vendor-unlock & power management helper (Intel 82599 / X520-2)

Usage:
  sudo ./sfp-fiber-lockout-fix.sh [COMMAND] [OPTIONS]

Commands:
  sfp-unlock    SFP+ vendor unlock operations (default)
  power-mgmt    Intel ixgbe power management fix (D3cold issues)

SFP+ Unlock Options:
  --status      Show current ixgbe parameter value, default route, and ixgbe ifaces.
  --apply       Persistently set: options ixgbe allow_unsupported_sfp=1
                (no-op unless an ixgbe NIC is present; --force applies anyway)
  --reload      Unload/reload ixgbe so the setting takes effect immediately (briefly drops ixgbe links).
  --force       Apply without an ixgbe NIC present / reload even if the default
                route uses ixgbe (risk: drop SSH).

Power Management Options:
  --detect      Detect Intel ixgbe devices and their power state
  --fix         Apply power management fixes (udev rule + per-device settings)
  --verify      Check current power control status
  --undo        Revert power management changes

Global Options:
  --dry-run     Print actions without changing anything.
  -h, --help    Show this help message.

Examples:
  sudo ./sfp-fiber-lockout-fix.sh sfp-unlock --status
  sudo ./sfp-fiber-lockout-fix.sh sfp-unlock --apply --reload
  sudo ./sfp-fiber-lockout-fix.sh power-mgmt --detect
  sudo ./sfp-fiber-lockout-fix.sh power-mgmt --fix
  sudo ./sfp-fiber-lockout-fix.sh power-mgmt --verify
  sudo ./sfp-fiber-lockout-fix.sh power-mgmt --undo

Supported Distributions:
  Arch/Artix, Debian/Ubuntu/Pop!_OS, Fedora/RHEL, Void, openSUSE, Alpine
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

# run cmd args... : execute (or print under --dry-run); no eval, no word re-splitting
run() {
  if (( DRYRUN )); then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

# run_write FILE : write stdin to FILE (or print under --dry-run)
run_write() {
  local file="$1"
  if (( DRYRUN )); then
    log "[dry-run] write $file:"
    sed 's/^/    /'
  else
    cat > "$file"
  fi
}

# write_sysfs FILE VALUE
write_sysfs() {
  if (( DRYRUN )); then
    log "[dry-run] echo $2 > $1"
  else
    printf '%s\n' "$2" > "$1"
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
    ( . /etc/os-release; echo "${ID:-unknown}" )
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
  command -v ethtool >/dev/null 2>&1 && return 0

  local cmd=()
  if command -v pacman >/dev/null 2>&1; then
    cmd=(pacman -S --needed --noconfirm ethtool)
  elif command -v apt-get >/dev/null 2>&1; then
    cmd=(apt-get install -y ethtool)
  elif command -v dnf >/dev/null 2>&1; then
    cmd=(dnf install -y ethtool)
  elif command -v xbps-install >/dev/null 2>&1; then
    cmd=(xbps-install -y ethtool)
  elif command -v zypper >/dev/null 2>&1; then
    cmd=(zypper -n install ethtool)
  elif command -v apk >/dev/null 2>&1; then
    cmd=(apk add ethtool)
  else
    log "WARNING: Unknown package manager ($(detect_distro)). Install ethtool manually."
    exit 1
  fi

  log "Installing required package: ethtool"
  # No `pacman -Sy`: a stale database fails here and tells you to update first.
  if ! run "${cmd[@]}"; then
    log "ERROR: could not install ethtool. Update the system first, then rerun."
    exit 1
  fi
  log "Dependencies installed successfully."
}

# True when an Intel 10GbE (ixgbe-driven) NIC is present
has_ixgbe_hw() {
  [[ -d /sys/module/ixgbe ]] && return 0
  lspci -d 8086: 2>/dev/null | grep -iE "ethernet|network" | grep -qE "82599|X520|X540|X550"
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
  printf '%s\n' 'options ixgbe allow_unsupported_sfp=1' | run_write "$conf"

  # Rebuild initramfs if the system uses one that might preload ixgbe.
  # Debian/Ubuntu/Pop!_OS use update-initramfs
  if command -v update-initramfs >/dev/null 2>&1; then
    log "Initramfs: update-initramfs -u (Debian/Ubuntu/Pop!_OS)"
    run update-initramfs -u || true
  # Arch Linux uses mkinitcpio
  elif command -v mkinitcpio >/dev/null 2>&1; then
    log "Initramfs: mkinitcpio -P (Arch Linux)"
    run mkinitcpio -P || true
  # Fedora/RHEL/CentOS use dracut
  elif command -v dracut >/dev/null 2>&1; then
    log "Initramfs: dracut --force (Fedora/RHEL)"
    run dracut --force || true
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
      run ip link set "$i" down || true
    done <<<"$ifaces"
  fi

  run modprobe -r ixgbe
  run modprobe ixgbe

  if [[ -n "$ifaces" ]]; then
    while read -r i; do
      [[ -z "$i" ]] && continue
      run ip link set "$i" up || true
    done <<<"$ifaces"
  fi
}

status() {
  log "Kernel: $(uname -r)"
  log "Distribution: $(detect_distro)"
  log "Default route iface: $(default_route_iface || true)"
  log "ixgbe loaded: $([[ -d /sys/module/ixgbe ]] && echo yes || echo no)"
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
      write_sysfs "${pci_path}/power/control" on
      log "  ✓ Set 0000:${addr} power/control: ${current} -> on"
    else
      log "  ⚠ Could not find ${pci_path}/power/control"
    fi
  done <<<"$addrs"
}

pm_create_udev_rule() {
  local udev_rule="/etc/udev/rules.d/99-ixgbe-power-control.rules"
  
  log "Creating persistent udev rule: $udev_rule"
  
  run_write "$udev_rule" <<'EOFUDEV'
# Disable runtime PM for Intel ixgbe network cards to prevent D3cold power state issues
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x10fb", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x1528", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x1563", ATTR{power/control}="on"
EOFUDEV
  log "  ✓ Created udev rule"

  run udevadm control --reload-rules
  run udevadm trigger --subsystem-match=pci --attr-match=vendor=0x8086
  log "  ✓ Reloaded udev rules"
}

# Legacy: older versions wrote a second file with the same SFP option
LEGACY_PM_MODPROBE="/etc/modprobe.d/ixgbe-power-management.conf"

# Where the kernel command line is configured, and whether pcie_aspm=off is in it
kernel_cmdline_sources() {
  local esp
  [[ -f /etc/default/grub ]] && echo /etc/default/grub
  [[ -f /etc/kernel/cmdline ]] && echo /etc/kernel/cmdline
  esp="$(bootctl --print-esp-path 2>/dev/null || true)"
  for esp in "$esp" /boot /efi /boot/efi; do
    [[ -n "$esp" && -d "$esp/loader/entries" ]] || continue
    ls "$esp"/loader/entries/*.conf 2>/dev/null
    break
  done
}

aspm_configured() {
  grep -q 'pcie_aspm=off' /proc/cmdline && return 0
  local f
  while read -r f; do
    [[ -n "$f" ]] && grep -q 'pcie_aspm=off' "$f" 2>/dev/null && return 0
  done < <(kernel_cmdline_sources)
  return 1
}

pm_regenerate_grub() {
  [[ -f /etc/default/grub ]] || { log "  GRUB not in use; nothing to regenerate."; return 0; }
  log "Regenerating GRUB bootloader..."
  if command -v update-grub &>/dev/null; then
    run update-grub
  elif command -v grub2-mkconfig &>/dev/null && [[ -d /boot/grub2 ]]; then
    run grub2-mkconfig -o /boot/grub2/grub.cfg
  elif command -v grub-mkconfig &>/dev/null; then
    run grub-mkconfig -o /boot/grub/grub.cfg
  else
    log "  ERROR: no GRUB config generator found"
    return 1
  fi
  log "  ✓ GRUB updated"
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
  
  log "======================================"
  log "Power Management Fix Applied!"
  log "======================================"
  log ""
  log "Summary of changes:"
  log "  1. Disabled runtime PM for ixgbe cards (immediate)"
  log "  2. Created udev rule: /etc/udev/rules.d/99-ixgbe-power-control.rules"
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
  log "Kernel pcie_aspm setting (GRUB / systemd-boot / kernel-install):"
  if aspm_configured; then
    log "  ✓ pcie_aspm=off is configured"
  else
    log "  - pcie_aspm=off not set (not needed when the udev rule is in place)"
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
  log "Kernel command line:"
  log "  $(cat /proc/cmdline)"
  
  log ""
  log "Checking udev rule:"
  if [[ -f /etc/udev/rules.d/99-ixgbe-power-control.rules ]]; then
    log "  ✓ Udev rule exists"
  else
    log "  ✗ Udev rule NOT found"
  fi
  
  log ""
  log "Checking ixgbe modprobe config:"
  if [[ -f /etc/modprobe.d/ixgbe-allow-unsupported-sfp.conf ]]; then
    log "  ✓ Modprobe config exists"
  else
    log "  ✗ Modprobe config NOT found (run: sfp-unlock --apply)"
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
    run rm -f /etc/udev/rules.d/99-ixgbe-power-control.rules
    log "  ✓ Removed: /etc/udev/rules.d/99-ixgbe-power-control.rules"
    files_removed=$((files_removed + 1))
  else
    log "Udev rule not found (already removed)"
  fi
  
  log ""
  
  # Remove the legacy duplicate modprobe config (the SFP option itself stays
  # in ixgbe-allow-unsupported-sfp.conf; that's the sfp-unlock setting)
  if [[ -f "$LEGACY_PM_MODPROBE" ]]; then
    log "Removing legacy ixgbe modprobe config..."
    run rm -f "$LEGACY_PM_MODPROBE"
    log "  ✓ Removed: $LEGACY_PM_MODPROBE"
    files_removed=$((files_removed + 1))
  fi
  
  log ""
  
  # Reload udev rules
  log "Reloading udev rules..."
  run udevadm control --reload-rules
  run udevadm trigger --subsystem-match=pci
  log "  ✓ udev rules reloaded"
  
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
      if (( DO_APPLY )) && ! has_ixgbe_hw && (( !FORCE )); then
        log "No Intel ixgbe NIC detected; skipping SFP unlock (use --force to apply anyway)."
        DO_APPLY=0
        DO_RELOAD=0
        (( DO_STATUS )) || exit 0
      fi
      install_dependencies
      if (( DO_STATUS )); then status; fi
      if (( DO_APPLY )); then
        apply_config
        # Clean up the duplicate file older versions wrote
        if [[ -f "$LEGACY_PM_MODPROBE" ]]; then run rm -f "$LEGACY_PM_MODPROBE"; fi
      fi
      if (( DO_RELOAD )); then reload_ixgbe; fi
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
      if (( PM_DETECT )); then pm_detect; fi
      if (( PM_FIX )); then pm_fix; fi
      if (( PM_VERIFY )); then pm_verify; fi
      if (( PM_UNDO )); then pm_undo; fi
      ;;
    *)
      log "ERROR: Unknown command: $COMMAND"
      usage
      exit 1
      ;;
  esac
}

main "$@"