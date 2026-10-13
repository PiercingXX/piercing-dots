#!/usr/bin/env bash
# Portable setup for several Claude Code logins that share one context.
#
# Copy this file to another machine and run it. A .sh suffix is fine:
#   ./setup-claude-accounts.sh
#
# Account 1 is ~/.claude, which is also what plain `claude` uses.
# Accounts 2 through 6 live in ~/.config/claude/accounts/N. Start them with
# `claude2` through `claude6`. To add another, append its number to
# EXTRA_ACCOUNTS below and run setup again.
# You choose the account by which command you run. A usage limit does not
# move you to another account.
#
# On a headless machine, `claude auth login` and `claudeN auth login` print
# a URL and a code. Open that URL in a browser on any other computer.

set -euo pipefail

SHARED="${HOME}/.claude"
ROOT="${HOME}/.config/claude"
EXTRA_ACCOUNTS=(2 3 4 5 6)
RUNTIME="${ROOT}/claude-accounts"
SHELL_SNIPPET="${ROOT}/shell.bash"
BIN_DIR="${HOME}/.local/bin"
BASHRC="${HOME}/.bashrc"

SHARED_DIRS=(projects skills plugins file-history)
# Files are symlinked too, but Claude Code saves some of them with
# write-temp-then-rename, which turns an account's link into a private copy.
# ensure_account() (run before every claudeN start) folds such copies back
# into the shared store and restores the link. See heal_shared_file.
SHARED_FILES=(settings.json history.jsonl)

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
  printf 'claude-accounts: %s\n' "$*" >&2
  exit 1
}

claude_bin() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return
  fi
  if [[ -x "${BIN_DIR}/claude" ]]; then
    printf '%s\n' "${BIN_DIR}/claude"
    return
  fi
  die "claude is not installed. Run: bash ${RUNTIME} setup"
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

json_number() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] || return 0
  grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[0-9][0-9]*" "$file" 2>/dev/null \
    | head -1 \
    | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/' \
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
  elif [[ "$name" == *.jsonl ]]; then
    # Append-only log: keep every line from both, shared order first
    local tmp
    tmp="$(mktemp "${src}.XXXXXX")"
    awk 'NR == FNR { seen[$0] = 1; print; next } !($0 in seen) { print }' "$src" "$dst" > "$tmp"
    chmod --reference="$src" "$tmp" 2>/dev/null || true
    mv "$tmp" "$src"
    rm -f "$dst"
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

install_claude_if_missing() {
  export PATH="${BIN_DIR}:${PATH}"
  if command -v claude >/dev/null 2>&1 || [[ -x "${BIN_DIR}/claude" ]]; then
    return 0
  fi
  printf 'Claude Code is not installed. Installing the native build for this user...\n'
  # Download first, sanity-check, then run: a truncated or HTML error page
  # never reaches bash.
  local installer
  installer="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 https://claude.ai/install.sh -o "$installer" \
      || die "could not download the Claude installer"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --https-only -O "$installer" https://claude.ai/install.sh \
      || die "could not download the Claude installer"
  else
    die "install curl or wget, then run this script again"
  fi
  [[ -s "$installer" ]] || die "the Claude installer download was empty"
  head -n1 "$installer" | grep -q '^#!' || die "the Claude installer download does not look like a script"
  bash -n "$installer" || die "the Claude installer download failed a syntax check"
  local rc=0
  bash "$installer" || rc=$?
  rm -f "$installer"
  [[ $rc -eq 0 ]] || die "the Claude installer failed (exit ${rc})"
  export PATH="${BIN_DIR}:${PATH}"
  command -v claude >/dev/null 2>&1 || [[ -x "${BIN_DIR}/claude" ]] \
    || die "the Claude installer finished but claude is still not on PATH"
}

write_shell_snippet() {
  local n
  {
    printf '# Manual Claude Code accounts. Sourced from ~/.bashrc.\n'
    printf '# claude and claude1 are account 1. claudeN is account N.\n'
    for n in 1 "${EXTRA_ACCOUNTS[@]}"; do
      printf '\nclaude%s() {\n  "${HOME}/.config/claude/claude-accounts" run %s "$@"\n}\n' "$n" "$n"
    done
    printf '\nclaude-status() {\n  "${HOME}/.config/claude/claude-accounts" status\n}\n'
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
    write_wrapper "claude${n}" '#!/usr/bin/env bash
exec "${HOME}/.config/claude/claude-accounts" run '"${n}"' "$@"'
  done
  write_wrapper claude-status '#!/usr/bin/env bash
exec "${HOME}/.config/claude/claude-accounts" status'
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
  ln -sfn claude-accounts "${ROOT}/setup-claude-accounts"
}

ensure_bashrc() {
  touch "$BASHRC"
  if ! grep -qE '^[^#]*PATH=.*\.local/bin' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# Local user binaries (Claude Code and the account commands live here).
export PATH="$HOME/.local/bin:$PATH"
EOF
  fi
  if ! grep -q 'config/claude/shell.bash' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# Claude Code accounts: claude1, claude2, ... are separate logins with one shared memory.
# Plain `claude` stays on account 1. Start claudeN yourself to use another login.
[[ -r "$HOME/.config/claude/shell.bash" ]] && source "$HOME/.config/claude/shell.bash"
EOF
  fi
}

auth_line() {
  local creds="$1"
  local profile="$2"
  if [[ ! -f "$creds" ]]; then
    printf 'not logged in\n'
    return
  fi
  local token plan access refresh now line email
  token="$(json_string accessToken "$creds")"
  if [[ -z "$token" ]]; then
    printf 'credentials file has no Claude login\n'
    return
  fi
  plan="$(json_string subscriptionType "$creds")"
  [[ -n "$plan" ]] || plan="unknown plan"
  access="$(json_number expiresAt "$creds")"
  refresh="$(json_number refreshTokenExpiresAt "$creds")"
  now="$(( $(date +%s) * 1000 ))"
  if [[ -n "$refresh" && "$now" -ge "$refresh" ]]; then
    line="logged out (refresh token expired)"
  elif [[ -n "$access" && "$now" -ge "$access" ]]; then
    line="logged in (access token refreshes on next launch)"
  else
    line="logged in"
  fi
  line="${line}, plan ${plan}"
  email="$(json_string emailAddress "$profile")"
  if [[ -n "$email" ]]; then
    line="${line}, ${email}"
  fi
  printf '%s\n' "$line"
}

print_status() {
  printf 'account 1 (claude / claude1): %s\n' "$(auth_line "${SHARED}/.credentials.json" "${HOME}/.claude.json")"
  local n dir
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    dir="$(account_dir "$n")"
    printf 'account %s (claude%s): %s\n' "$n" "$n" "$(auth_line "${dir}/.credentials.json" "${dir}/.claude.json")"
  done
  printf 'shared store: %s\n' "$SHARED"

  local name dst target
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    dir="$(account_dir "$n")"
    printf '\naccount %s config: %s\n' "$n" "$dir"
    for name in "${SHARED_DIRS[@]}" "${SHARED_FILES[@]}"; do
      dst="${dir}/${name}"
      if [[ ! -e "${SHARED}/${name}" && ! -L "$dst" ]]; then
        printf 'share %-16s skipped (not in the shared store yet)\n' "$name"
        continue
      fi
      if [[ -L "$dst" ]]; then
        target="$(readlink "$dst")"
        printf 'share %-16s -> %s\n' "$name" "$target"
      else
        printf 'share %-16s NOT LINKED\n' "$name"
      fi
    done
  done

  cat <<'EOF'

claude and claude1 always start account 1. claudeN always starts account N.
Run another command yourself when you want another login.

Same directory, other login, same memory and transcript:
  claude2 -c
  claude3 --resume
EOF
}

print_login_help() {
  cat <<'EOF'

Sign each account in once. On a headless server the terminal prints a URL
and a one-time code because there is no local browser. Open that URL on any
other computer and finish the login there. This shell waits until you do.

  claude auth login
EOF
  local n
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    printf '  claude%s auth login\n' "$n"
  done
  cat <<'EOF'

Check all logins with:
  claude-status
EOF
}

setup() {
  install_self
  install_claude_if_missing
  write_shell_snippet
  install_commands
  ensure_bashrc
  ensure
  printf 'Claude accounts are ready on this machine.\n'
  printf 'Commands: claude, claude1'
  local n
  for n in "${EXTRA_ACCOUNTS[@]}"; do
    printf ', claude%s' "$n"
  done
  printf ', claude-status\n'
  printf 'Open a new shell, or run: source ~/.bashrc\n'
  print_status
  print_login_help
}

run_account() {
  local which="$1"
  shift
  local bin
  bin="$(claude_bin)"

  if [[ "$which" == 1 ]]; then
    exec env -u CLAUDE_CONFIG_DIR "$bin" "$@"
  fi
  is_extra_account "$which" \
    || die "account must be 1 or one of: ${EXTRA_ACCOUNTS[*]}"
  ensure_account "$which"
  exec env CLAUDE_CONFIG_DIR="$(account_dir "$which")" "$bin" "$@"
}

usage() {
  cat <<EOF
Usage: claude-accounts <command>

  setup           install commands, shell hooks, and the shared account links
  ensure          create accounts ${EXTRA_ACCOUNTS[*]} and link them at the shared store
  status          show all logins and the shared links
  run N [args]    start Claude Code on account N (1 ${EXTRA_ACCOUNTS[*]}), passing args through

Run setup on each computer. Account 1 is ~/.claude. Account N is
~/.config/claude/accounts/N. Plain \`claude\` stays on account 1.

Copy this file to another machine and run it. The .sh name is fine:
  ./setup-claude-accounts.sh
EOF
}

is_setup_script() {
  case "$(basename "$1")" in
    setup-claude-accounts|setup-claude-accounts.sh) return 0 ;;
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
