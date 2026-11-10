#!/usr/bin/env bash
# Mirror a source directory onto an unlocked, encrypted offsite drive, verify, then
# (optionally) unmount, lock and power the drive off so it's safe to unplug.
# Usage: ./backup-to-offsite.sh [label] [source-dir]
#   label       the drive name you gave encrypt-backup-drive.sh (prompted if omitted)
#   source-dir  directory to back up (prompted if omitted)
# Destination folder on the drive: <drive>/<basename of source-dir>  (a mirror:
# files deleted from the source are deleted from that folder on the next run).
#
# Speed-ups baked in:
#   - dm-crypt read/write workqueues turned off (needs sudo once, persistent)
#   - JOBS rsyncs in parallel, files split by size so all stay busy to the end
#   - no ACL/xattr copying (set KEEP_XATTRS=1 to keep them)
#   - bigger/leaner kernel write-back is left alone (needs root, small gain)
set -euo pipefail

LABEL="${1:-}"
SRC="${2:-}"
JOBS="${JOBS:-4}"

die() { echo "ERROR: $*" >&2; exit 1; }
if [[ -z "$LABEL" ]]; then read -r -p "Drive name [offsite1]: " LABEL; LABEL="${LABEL:-offsite1}"; fi
if [[ -z "$SRC" ]]; then read -r -p "Directory to back up: " SRC; fi
SRC="${SRC/#\~/$HOME}"; SRC="${SRC%/}"
[[ -n "$SRC" && -d "$SRC" ]] || die "source directory '$SRC' not found"
DEST_MNT="/run/media/$USER/$LABEL"
DEST="$DEST_MNT/$(basename "$SRC")"
LOG="$HOME/offsite-backup-$LABEL-$(date +%F_%H%M).log"
RSYNC_OPTS=(-aH --delete-after --human-readable --log-file="$LOG")
[[ "${KEEP_XATTRS:-0}" == 1 ]] && RSYNC_OPTS+=(-AX)
fmt() { printf '%d:%02d:%02d' $(( $1 / 3600 )) $(( $1 % 3600 / 60 )) $(( $1 % 60 )); }

# ---- Preflight -------------------------------------------------------------
mountpoint -q "$DEST_MNT" || die "$DEST_MNT isn't mounted. Unlock/mount the drive first."
DSRC="$(findmnt -no SOURCE "$DEST_MNT")"
[[ "$DSRC" == /dev/mapper/* ]] || die "$DEST_MNT isn't an encrypted volume ($DSRC). Refusing."
[[ -w "$DEST_MNT" ]] || die "$DEST_MNT isn't writable by you. Run: sudo chown $USER:$USER $DEST_MNT"

# Space check uses the used space of the source's whole filesystem (conservative).
NEED=$(df -B1 --output=used "$SRC" | tail -1 | tr -d ' ')
HAVE=$(df -B1 --output=avail "$DEST_MNT" | tail -1 | tr -d ' ')
echo "Source:      $SRC  ($(numfmt --to=iec "$NEED") used)"
echo "Destination: $DEST  ($(numfmt --to=iec "$HAVE") free)"
(( NEED < HAVE )) || die "Not enough space on the offsite drive."
echo "Parallel jobs: $JOBS   Log: $LOG"
echo

read -r -p "Start backup? [Y/n] " GO
[[ "${GO:-y}" =~ ^[Yy]|^$ ]] || die "Aborted."

# ---- Speed: disable dm-crypt workqueues (live, persistent; needs sudo) -----
MAPNAME="$(basename "$DSRC")"
echo "Optimizing encryption throughput (sudo may ask for your password)..."
sudo cryptsetup refresh --perf-no_read_workqueue --perf-no_write_workqueue \
     --persistent "$MAPNAME" || echo "  (couldn't apply; continuing at normal speed)"

mkdir -p "$DEST"

# ---- Parallel copy ---------------------------------------------------------
# Split ALL files (by size, regardless of folder layout) into JOBS balanced lists so
# every rsync stays busy until the end, even if one folder holds most of the data.
split_files() {  # outdir
  find "$SRC" -type f -printf '%s\t%P\0' | python3 -I -c '
import sys, heapq
n = int(sys.argv[1]); out = sys.argv[2]
items = []
for rec in sys.stdin.buffer.read().split(b"\0"):
    if rec:
        s, _, p = rec.partition(b"\t"); items.append((int(s), p))
items.sort(reverse=True)
outs = [open("%s/list.%d" % (out, i), "wb") for i in range(n)]
heap = [(0, i) for i in range(n)]
for s, p in items:
    w, i = heapq.heappop(heap)
    outs[i].write(p + b"\0")
    heapq.heappush(heap, (w + s + 262144, i))   # +256K per file ~ per-file overhead
for f in outs: f.close()
' "$JOBS" "$1"
}

run_copy() {
  local tmp rc=0 pids=() l p
  tmp="$(mktemp -d)"
  split_files "$tmp"
  local PAR_OPTS=(-aH --no-r --human-readable --log-file="$LOG")
  [[ "${KEEP_XATTRS:-0}" == 1 ]] && PAR_OPTS+=(-AX)
  for l in "$tmp"/list.*; do
    rsync "${PAR_OPTS[@]}" --from0 --files-from="$l" "$SRC/" "$DEST/" & pids+=($!)
  done
  for p in "${pids[@]}"; do
    wait "$p" || { r=$?; [[ $r -eq 24 ]] || rc=$r; }
  done
  rm -rf "$tmp"
  (( rc == 0 )) || return "$rc"
  # Final pass: folder metadata, empty folders, and removal of anything deleted from the source
  rsync "${RSYNC_OPTS[@]}" "$SRC/" "$DEST/" || { rc=$?; [[ $rc -eq 24 ]] && rc=0; }
  return "$rc"
}

BASE=$(df -B1 --output=used "$DEST_MNT" | tail -1 | tr -d ' ')
REMAIN=$(( NEED - BASE )); (( REMAIN > 0 )) || REMAIN=1
T0=$(date +%s)
echo
echo "Scanning source and balancing work, then copying (progress = bytes written)..."
run_copy & CPID=$!
while kill -0 "$CPID" 2>/dev/null; do
  sleep 2
  USED=$(df -B1 --output=used "$DEST_MNT" | tail -1 | tr -d ' ')
  WROTE=$(( USED - BASE )); (( WROTE < 0 )) && WROTE=0
  EL=$(( $(date +%s) - T0 )); (( EL > 0 )) || EL=1
  RATE=$(( WROTE / EL ))
  PCT=$(( WROTE * 100 / REMAIN )); (( PCT > 99 )) && PCT=99
  if (( RATE > 0 )); then ETA=$(fmt $(( (REMAIN - WROTE) / RATE ))); else ETA="--:--:--"; fi
  F=$(( PCT * 30 / 100 ))
  printf -v FILL '%*s' "$F" ''; FILL=${FILL// /#}
  printf -v EMPTY '%*s' $(( 30 - F )) ''; EMPTY=${EMPTY// /-}
  printf '\r\033[K[%s%s] %3d%%  %s written  %d MB/s  ETA %s' \
    "$FILL" "$EMPTY" "$PCT" "$(numfmt --to=iec "$WROTE")" $(( RATE / 1000000 )) "$ETA"
done
rc=0; wait "$CPID" || rc=$?
echo
(( rc == 0 )) || die "copy failed (exit $rc). See $LOG. Do NOT eject yet."
echo "Copy finished in $(fmt $(( $(date +%s) - T0 )))."

# ---- Verify: a dry-run should find nothing left to transfer ----------------
echo
echo "Verifying (comparing source and copy)..."
VOPTS=(-aHn --delete --itemize-changes); [[ "${KEEP_XATTRS:-0}" == 1 ]] && VOPTS+=(-AX)
DIFFS="$(rsync "${VOPTS[@]}" "$SRC/" "$DEST/" | grep -v '^\.d\.\.t\.\.\.\.\.\. \./$' || true)"
if [[ -n "$DIFFS" ]]; then
  echo "$DIFFS" | head -20
  die "Verification found differences (above). Re-run the script. Do NOT eject yet."
fi
echo "Verified: copy matches source."
sync

# ---- Eject -----------------------------------------------------------------
echo
read -r -p "Unmount, lock and power off the drive now? [Y/n] " EJ
if [[ "${EJ:-y}" =~ ^[Yy]|^$ ]]; then
  BASEDEV="$(lsblk -snlo NAME "$DSRC" | tail -1)"   # underlying disk (e.g. sde)
  udisksctl unmount -b "$DSRC"
  udisksctl lock -b "/dev/$BASEDEV"
  udisksctl power-off -b "/dev/$BASEDEV"
  echo "Drive is locked and powered off. Safe to unplug."
else
  echo "Left mounted. Eject it from your file manager when ready."
fi
