#!/usr/bin/env bash
# Wipe + LUKS2-encrypt + format the plugged-in external USB drive for backups.
# Usage: ./encrypt-backup-drive.sh [label] [/dev/sdX]
#   label      name for the drive (prompted for if not given)
#   /dev/sdX   default: auto-detect the one USB disk
# You will enter: your sudo password once, then a new drive passphrase twice.
# DESTROYS ALL DATA on the target drive.
set -euo pipefail

LABEL="${1:-}"
DEV="${2:-}"

die() { echo "ERROR: $*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  exec sudo SUDO_HOME="$HOME" "$0" "$@"
fi
REAL_HOME="${SUDO_HOME:-$HOME}"

if [[ -z "$LABEL" ]]; then
  read -r -p "Drive name [offsite1]: " LABEL
  LABEL="${LABEL:-offsite1}"
fi
[[ "$LABEL" =~ ^[A-Za-z0-9_.-]{1,16}$ ]] || die "drive name must be 1-16 chars: letters, numbers, _ . -"

for cmd in cryptsetup wipefs mkfs.ext4 lsblk findmnt; do
  command -v "$cmd" >/dev/null || die "missing command: $cmd"
done

# ---- Find the drive --------------------------------------------------------
if [[ -z "$DEV" ]]; then
  mapfile -t CANDS < <(lsblk -dnbo PATH,TYPE,TRAN,SIZE | awk '$2=="disk" && $3=="usb" && $4>0 {print $1}')
  (( ${#CANDS[@]} == 1 )) || die "found ${#CANDS[@]} USB drives (${CANDS[*]:-none}); pass one: $0 $LABEL /dev/sdX"
  DEV="${CANDS[0]}"
fi

# ---- Safety checks ---------------------------------------------------------
[[ -b "$DEV" ]] || die "$DEV is not a block device"
[[ "$(lsblk -dno TYPE "$DEV")" == "disk" ]] || die "$DEV is not a whole disk"
[[ "$(lsblk -dno TRAN "$DEV" | tr -d ' ')" == "usb" ]] || die "$DEV is not a USB drive. Refusing."
SIZE_BYTES="$(lsblk -bdno SIZE "$DEV")"
(( SIZE_BYTES > 0 )) || die "$DEV reports 0 bytes"
while read -r mp; do
  case "$mp" in
    /|/boot*|/home|/var*|/usr*|/etc*|/opt*)
      die "$DEV has a partition mounted at critical path $mp. Refusing." ;;
  esac
done < <(lsblk -nro MOUNTPOINTS "$DEV" | tr ' ' '\n' | sed '/^$/d')

SERIAL="$(lsblk -dno SERIAL "$DEV" | sed 's/ *$//')"
echo "Target: $DEV  $(lsblk -dno MODEL "$DEV" | sed 's/ *$//')  $(lsblk -dno SIZE "$DEV" | tr -d ' ')  (label: $LABEL)"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$DEV"
echo "ALL DATA ON THIS DRIVE WILL BE ERASED."
echo

# ---- Passphrase (twice) ----------------------------------------------------
while true; do
  read -r -s -p "New drive passphrase: " PASS; echo
  [[ -n "$PASS" ]] || { echo "Passphrase can't be empty."; continue; }
  read -r -s -p "Again: " PASS2; echo
  [[ "$PASS" == "$PASS2" ]] && break
  echo "Didn't match, try again."
done
unset PASS2

read -r -p "Proceed? [Y/n] " GO
[[ "${GO:-y}" =~ ^[Yy]|^$ ]] || die "Aborted, nothing changed."
echo

# ---- Progress bar ----------------------------------------------------------
SIZE_GB=$(( SIZE_BYTES / 1000000000 ))
E_SIG=3; E_LUKS=8; E_OPEN=3; E_MKFS=$(( 5 + SIZE_GB / 40 )); E_TEST=2; E_HDR=2
TOTAL=$(( E_SIG + E_LUKS + E_OPEN + E_MKFS + E_TEST + E_HDR ))
DONE=0; T0=$(date +%s)
fmt() { printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
draw() {  # done-seconds label
  local pct=$(( $1 * 100 / TOTAL )) f fill empty eta=$(( TOTAL - $1 ))
  (( pct > 100 )) && pct=100; (( eta < 0 )) && eta=0
  f=$(( pct * 30 / 100 ))
  printf -v fill '%*s' "$f" ''; fill=${fill// /#}
  printf -v empty '%*s' $(( 30 - f )) ''; empty=${empty// /-}
  printf '\r\033[K[%s%s] %3d%%  ETA %s  %s' "$fill" "$empty" "$pct" "$(fmt "$eta")" "$2"
}
step() {  # est label command...   (runs command with a live bar)
  local est=$1 label=$2 start rc=0 el; shift 2
  "$@" & local pid=$!; start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    el=$(( $(date +%s) - start )); (( el >= est )) && el=$(( est * 99 / 100 ))
    draw $(( DONE + el )) "$label"; sleep 0.5
  done
  wait "$pid" || rc=$?
  DONE=$(( DONE + est )); draw "$DONE" "$label ✓"; echo
  return "$rc"
}

MAPPER="backup_$$"
trap 'cryptsetup status "$MAPPER" &>/dev/null && cryptsetup close "$MAPPER" || true; unset PASS' EXIT

# ---- Do it -----------------------------------------------------------------
for part in $(lsblk -nro PATH "$DEV" | tail -n +2); do
  findmnt -rn "$part" >/dev/null && umount "$part"
done

clear_sigs() { wipefs -a "$DEV" >/dev/null; blkdiscard -s "$DEV" 2>/dev/null || blkdiscard "$DEV" 2>/dev/null || true; udevadm settle || true; }
luks_format() { printf '%s' "$PASS" | cryptsetup luksFormat --type luks2 --batch-mode --key-file=- --label "$LABEL" "$DEV"; }
luks_open()   { printf '%s' "$PASS" | cryptsetup open --key-file=- "$DEV" "$MAPPER"; }
make_fs()     { mkfs.ext4 -q -m 0 -L "$LABEL" "/dev/mapper/$MAPPER"; }
test_fs() {
  local tmp; tmp="$(mktemp -d)"
  mount "/dev/mapper/$MAPPER" "$tmp"; echo ok > "$tmp/.t" && rm "$tmp/.t"
  [[ -n "${SUDO_USER:-}" ]] && chown "$SUDO_USER":"$SUDO_USER" "$tmp" || true   # so you can write to it without sudo
  umount "$tmp"; rmdir "$tmp"; cryptsetup close "$MAPPER"
}
HDR="$REAL_HOME/luks-header-${LABEL}-${SERIAL:-unknown}.img"
backup_hdr() {
  rm -f "$HDR"; cryptsetup luksHeaderBackup "$DEV" --header-backup-file "$HDR"; chmod 600 "$HDR"
  [[ -n "${SUDO_USER:-}" ]] && chown "$SUDO_USER":"$SUDO_USER" "$HDR" || true
}

step "$E_SIG"  "wiping old data"       clear_sigs
step "$E_LUKS" "encrypting (LUKS2)"    luks_format
step "$E_OPEN" "unlocking"             luks_open
step "$E_MKFS" "creating filesystem"   make_fs
step "$E_TEST" "testing"               test_fs
step "$E_HDR"  "saving header backup"  backup_hdr

echo
echo "DONE: $DEV is encrypted + formatted ('$LABEL') in $(fmt $(( $(date +%s) - T0 )))."
echo "Header backup: $HDR"
echo "  -> copy it somewhere OTHER than this drive (password manager / another machine)."
echo "Use it: udisksctl unlock -b $DEV   (or: sudo cryptsetup open $DEV $LABEL)"
