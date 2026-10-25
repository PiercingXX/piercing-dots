#!/usr/bin/env bash
# Portable setup for several Grok Build logins that share one context.
#
# Copy this file to another machine and run it. A .sh suffix is fine:
#   ./setup-grok-accounts.sh
#
# Account 1 is ~/.grok, which is also what plain `grok` uses.
# Accounts 2 through 4 live in ~/.config/grok/accounts/N. Start them with
# `grok2` through `grok4`. To add another, append its number to
# EXTRA_ACCOUNTS below and run setup again.
# You choose the account by which command you run. A usage limit does not
# move you to another account.
#
# Each account keeps its own auth.json and leader socket under its GROK_HOME.
# Memory, sessions, skills, plugins, and config.toml are shared with ~/.grok,
# and setup turns memory on in the shared config.toml so every login uses it.
#
# On a headless machine, run `grok login --device-auth` and
# `grokN login --device-auth`. They print a URL and a code. Open that URL in a
# browser on any other computer.

set -euo pipefail

SHARED="${HOME}/.grok"
ROOT="${HOME}/.config/grok"
EXTRA_ACCOUNTS=(2 3 4)
RUNTIME="${ROOT}/grok-accounts"
SHELL_SNIPPET="${ROOT}/shell.bash"
BIN_DIR="${HOME}/.local/bin"
BASHRC="${HOME}/.bashrc"

# memory and memory-v2 are the cross-session memory. sessions holds the
# transcripts, so `grok2 -c` continues a conversation started with `grok`.
# bin, downloads, bundled, vendor, docs, and completions are the Grok install
# itself: one copy, so an update from any account updates them all.
SHARED_DIRS=(
  memory memory-v2 sessions
  skills agents personas rules commands workflows hooks
  plugins installed-plugins marketplace-cache
  bin downloads bundled vendor docs completions
)
# Files are symlinked too, but Grok saves some of them with
# write-temp-then-rename, which turns an account's link into a private copy.
# ensure_account() (run before every grokN start) folds such copies back
# into the shared store and restores the link. See heal_shared_file.
# Only files that already exist in ~/.grok are linked.
SHARED_FILES=(config.toml trusted_folders.toml AGENTS.md lsp.json pager.toml sandbox.toml statusline.sh)

account_dir() {
  printf '%s/accounts/%s\n' "$ROOT" "$1"
}

is_extra_account() {
  local n
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    [[ "$n" == "$1" ]] && return 0
  done
  return 1
}

die() {
  printf 'grok-accounts: %s\n' "$*" >&2
  exit 1
}

grok_bin() {
  if command -v grok >/dev/null 2>&1; then
    command -v grok
    return
  fi
  local candidate
  for candidate in "${BIN_DIR}/grok" "${SHARED}/bin/grok"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  die "grok is not installed. Run: bash ${RUNTIME} setup"
}

json_string() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] || return 0
  grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
    | head -1 \
    | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' \
    || true
}

link_path() {
  local src="$1"
  local dst="$2"

  if [[ -L "$dst" ]]; then
    local current wanted
    current="$(readlink -f "$dst")"
    wanted="$(readlink -f "$src")"
    if [[ "$current" == "$wanted" ]]; then
      return 0
    fi
    die "unexpected symlink ${dst} -> $(readlink "$dst")"
  fi
  if [[ -e "$dst" ]]; then
    die "refusing to replace ${dst}; it is not a link to the shared store"
  fi
  ln -s "$src" "$dst"
}

# heal_shared_file DIR NAME: the account has a regular file where the link should be
heal_shared_file() {
  local dir="$1"
  local name="$2"
  local src="${SHARED}/${name}"
  local dst="${dir}/${name}"
  [[ -f "$dst" && ! -L "$dst" ]] || return 0

  if [[ ! -e "$src" ]]; then
    mv "$dst" "$src"
  elif [[ "$dst" -nt "$src" ]]; then
    # Settings: the most recently saved copy wins
    cp -p "$src" "${src}.bak"
    mv "$dst" "$src"
  else
    rm -f "$dst"
  fi
}

ensure_account() {
  local dir
  dir="$(account_dir "$1")"
  mkdir -p "$dir"
  chmod 700 "$dir"

  local name src
  for name in "${SHARED_DIRS[@]}"; do
    src="${SHARED}/${name}"
    mkdir -p "$src"
    link_path "$src" "${dir}/${name}"
  done
  for name in "${SHARED_FILES[@]}"; do
    src="${SHARED}/${name}"
    heal_shared_file "$dir" "$name"
    if [[ ! -e "$src" ]]; then
      continue
    fi
    link_path "$src" "${dir}/${name}"
  done
}

ensure() {
  local n
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    ensure_account "$n"
  done
}

# Memory is off by default, and xAI's server-side settings may turn it on for
# one login but not another. Pin it on in the shared config.toml. A section the
# user already wrote is left alone.
ensure_memory_config() {
  local config="${SHARED}/config.toml"
  mkdir -p "$SHARED"
  touch "$config"
  local section
  for section in memory memory_v2; do
    if ! grep -qE "^[[:space:]]*\[${section}\][[:space:]]*(#.*)?$" "$config"; then
      printf '\n[%s]\nenabled = true\n' "$section" >> "$config"
    fi
  done
}

install_grok_if_missing() {
  export PATH="${BIN_DIR}:${PATH}"
  if command -v grok >/dev/null 2>&1 || [[ -x "${BIN_DIR}/grok" || -x "${SHARED}/bin/grok" ]]; then
    return 0
  fi
  printf 'Grok Build is not installed. Installing it for this user...\n'
  # Download first, sanity-check, then run: a truncated or HTML error page
  # never reaches bash.
  local installer
  installer="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 https://x.ai/cli/install.sh -o "$installer" \
      || die "could not download the Grok installer"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --https-only -O "$installer" https://x.ai/cli/install.sh \
      || die "could not download the Grok installer"
  else
    die "install curl or wget, then run this script again"
  fi
  [[ -s "$installer" ]] || die "the Grok installer download was empty"
  head -n1 "$installer" | grep -q '^#!' || die "the Grok installer download does not look like a script"
  bash -n "$installer" || die "the Grok installer download failed a syntax check"
  local rc=0
  bash "$installer" || rc=$?
  rm -f "$installer"
  [[ $rc -eq 0 ]] || die "the Grok installer failed (exit ${rc})"
  export PATH="${BIN_DIR}:${PATH}"
  command -v grok >/dev/null 2>&1 || [[ -x "${BIN_DIR}/grok" || -x "${SHARED}/bin/grok" ]] \
    || die "the Grok installer finished but grok is still not on PATH"
}

write_shell_snippet() {
  local n
  {
    printf '# Manual Grok Build accounts. Sourced from ~/.bashrc.\n'
    printf '# grok and grok1 are account 1. grokN is account N.\n'
    for n in 1 "${EXTRA_ACCOUNTS[@]}"; do
      printf '\ngrok%s() {\n  "${HOME}/.config/grok/grok-accounts" run %s "$@"\n}\n' "$n" "$n"
    done
    printf '\ngrok-status() {\n  "${HOME}/.config/grok/grok-accounts" status\n}\n'
  } > "$SHELL_SNIPPET"
}

write_wrapper() {
  local name="$1"
  local body="$2"
  local path="${BIN_DIR}/${name}"
  printf '%s\n' "$body" > "$path"
  chmod 755 "$path"
}

install_commands() {
  mkdir -p "$BIN_DIR"
  local n
  for n in 1 "${EXTRA_ACCOUNTS[@]}"; do
    write_wrapper "grok${n}" '#!/usr/bin/env bash
exec "${HOME}/.config/grok/grok-accounts" run '"${n}"' "$@"'
  done
  write_wrapper grok-status '#!/usr/bin/env bash
exec "${HOME}/.config/grok/grok-accounts" status'
}

install_self() {
  mkdir -p "$ROOT"
  local source_path
  source_path="$(readlink -f "$0")"
  local dest_path
  dest_path="$(readlink -f "$RUNTIME" 2>/dev/null || true)"
  if [[ "$source_path" != "$dest_path" ]]; then
    cp "$source_path" "$RUNTIME"
  fi
  chmod 755 "$RUNTIME"
  ln -sfn grok-accounts "${ROOT}/setup-grok-accounts"
}

ensure_bashrc() {
  touch "$BASHRC"
  if ! grep -qE '^[^#]*\.local/bin' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# Local user binaries (Grok Build and the account commands live here).
export PATH="$HOME/.local/bin:$PATH"
EOF
  fi
  if ! grep -q 'config/grok/shell.bash' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# Grok Build accounts: grok1, grok2, ... are separate logins with one shared memory.
# Plain `grok` stays on account 1. Start grokN yourself to use another login.
[[ -r "$HOME/.config/grok/shell.bash" ]] && source "$HOME/.config/grok/shell.bash"
EOF
  fi
}

auth_line() {
  local auth="$1"
  if [[ ! -f "$auth" ]]; then
    printf 'not logged in\n'
    return
  fi
  local refresh email line
  refresh="$(json_string refresh_token "$auth")"
  if [[ -z "$refresh" ]]; then
    printf 'auth.json has no Grok login\n'
    return
  fi
  line="logged in"
  email="$(json_string email "$auth")"
  if [[ -n "$email" ]]; then
    line="${line}, ${email}"
  fi
  printf '%s\n' "$line"
}

memory_line() {
  local config="${SHARED}/config.toml"
  local section state
  for section in memory memory_v2; do
    state="$(awk -v s="[${section}]" '
      $0 ~ /^[[:space:]]*\[/ { gsub(/[[:space:]]|#.*/, ""); in_s = ($0 == s); next }
      in_s && /^[[:space:]]*enabled[[:space:]]*=/ { sub(/.*=[[:space:]]*/, ""); sub(/[[:space:]]*(#.*)?$/, ""); print; exit }
    ' "$config" 2>/dev/null)"
    printf '%s=%s ' "$section" "${state:-unset}"
  done
  printf '(in %s)\n' "$config"
}

print_status() {
  printf 'account 1 (grok / grok1): %s\n' "$(auth_line "${SHARED}/auth.json")"
  local n dir
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    dir="$(account_dir "$n")"
    printf 'account %s (grok%s): %s\n' "$n" "$n" "$(auth_line "${dir}/auth.json")"
  done
  printf 'shared store: %s\n' "$SHARED"
  printf 'memory: %s\n' "$(memory_line)"
  printf 'XAI_API_KEY is %s (grok uses it only when an account has no login)\n' \
    "$([[ -n "${XAI_API_KEY:-}" ]] && printf set || printf unset)"

  local name dst target
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    dir="$(account_dir "$n")"
    printf '\naccount %s config: %s\n' "$n" "$dir"
    for name in "${SHARED_DIRS[@]}" "${SHARED_FILES[@]}"; do
      dst="${dir}/${name}"
      if [[ ! -e "${SHARED}/${name}" && ! -L "$dst" ]]; then
        printf 'share %-20s skipped (not in the shared store yet)\n' "$name"
        continue
      fi
      if [[ -L "$dst" ]]; then
        target="$(readlink "$dst")"
        printf 'share %-20s -> %s\n' "$name" "$target"
      else
        printf 'share %-20s NOT LINKED\n' "$name"
      fi
    done
  done

  cat <<'EOF'

grok and grok1 always start account 1. grokN always starts account N.
Run another command yourself when you want another login.

Same directory, other login, same memory and transcript:
  grok2 -c
  grok3 --resume
EOF
}

print_login_help() {
  cat <<'EOF'

Sign each account in once. On a desktop this opens your browser. On a headless
server add --device-auth: the terminal prints a URL and a one-time code. Open
that URL on any other computer and finish the login there.

  grok login
EOF
  local n
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    printf '  grok%s login\n' "$n"
  done
  cat <<'EOF'

Check all logins with:
  grok-status
EOF
}

setup() {
  install_self
  install_grok_if_missing
  ensure_memory_config
  write_shell_snippet
  install_commands
  ensure_bashrc
  ensure
  printf 'Grok accounts are ready on this machine.\n'
  printf 'Commands: grok, grok1'
  local n
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    printf ', grok%s' "$n"
  done
  printf ', grok-status\n'
  printf 'Open a new shell, or run: source ~/.bashrc\n'
  print_status
  print_login_help
}

run_account() {
  local which="$1"
  shift
  local bin
  bin="$(grok_bin)"

  if [[ "$which" == 1 ]]; then
    exec env -u GROK_HOME "$bin" "$@"
  fi
  is_extra_account "$which" \
    || die "account must be 1 or one of: ${EXTRA_ACCOUNTS[*]}"
  ensure_account "$which"
  # Resolve symlinks: Grok's sandbox refuses a GROK_HOME reached through one.
  exec env GROK_HOME="$(readlink -f "$(account_dir "$which")")" "$bin" "$@"
}

usage() {
  cat <<EOF
Usage: grok-accounts <command>

  setup           install commands, shell hooks, shared memory config, and the shared account links
  ensure          create accounts ${EXTRA_ACCOUNTS[*]} and link them at the shared store
  status          show all logins, memory settings, and the shared links
  run N [args]    start Grok on account N (1 ${EXTRA_ACCOUNTS[*]}), passing args through

Run setup on each computer. Account 1 is ~/.grok. Account N is
~/.config/grok/accounts/N. Plain \`grok\` stays on account 1.

Copy this file to another machine and run it. The .sh name is fine:
  ./setup-grok-accounts.sh
EOF
}

is_setup_script() {
  case "$(basename "$1")" in
    setup-grok-accounts|setup-grok-accounts.sh) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  local cmd="${1:-}"

  case "$cmd" in
    setup|--setup|-setup)
      setup
      return
      ;;
  esac

  if [[ -z "$cmd" ]] && is_setup_script "$0"; then
    setup
    return
  fi

  case "$cmd" in
    ensure)
      ensure
      ;;
    status)
      ensure
      print_status
      ;;
    run)
      [[ $# -ge 2 ]] || die "run needs an account number"
      local which="$2"
      shift 2
      run_account "$which" "$@"
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      die "unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
