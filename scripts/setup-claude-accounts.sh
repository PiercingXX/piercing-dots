#!/usr/bin/env bash
# Portable setup for two Claude Code logins that share one context.
#
# Copy this file to another machine and run:
#   bash setup-claude-accounts
#
# Account 1 is ~/.claude, which is also what plain `claude` uses.
# Account 2 is ~/.config/claude/accounts/2. Start it with `claude2`.
# You choose the account by which command you run. A usage limit does not
# move you to the other account.
#
# On a headless machine, `claude auth login` and `claude2 auth login` print
# a URL and a code. Open that URL in a browser on any other computer.

set -euo pipefail

SHARED="${HOME}/.claude"
ROOT="${HOME}/.config/claude"
ACCOUNT2="${ROOT}/accounts/2"
RUNTIME="${ROOT}/claude-accounts"
SHELL_SNIPPET="${ROOT}/shell.bash"
BIN_DIR="${HOME}/.local/bin"
BASHRC="${HOME}/.bashrc"

SHARED_DIRS=(projects skills plugins file-history)
SHARED_FILES=(settings.json history.jsonl)

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

ensure() {
  mkdir -p "$ACCOUNT2"
  chmod 700 "$ACCOUNT2"

  local name src
  for name in "${SHARED_DIRS[@]}"; do
    src="${SHARED}/${name}"
    mkdir -p "$src"
    link_path "$src" "${ACCOUNT2}/${name}"
  done
  for name in "${SHARED_FILES[@]}"; do
    src="${SHARED}/${name}"
    if [[ ! -e "$src" ]]; then
      continue
    fi
    link_path "$src" "${ACCOUNT2}/${name}"
  done
}

install_claude_if_missing() {
  export PATH="${BIN_DIR}:${PATH}"
  if command -v claude >/dev/null 2>&1 || [[ -x "${BIN_DIR}/claude" ]]; then
    return 0
  fi
  printf 'Claude Code is not installed. Installing the native build for this user...\n'
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://claude.ai/install.sh | bash
  else
    die "install curl or wget, then run this script again"
  fi
  export PATH="${BIN_DIR}:${PATH}"
  command -v claude >/dev/null 2>&1 || [[ -x "${BIN_DIR}/claude" ]] \
    || die "the Claude installer finished but claude is still not on PATH"
}

write_shell_snippet() {
  cat > "$SHELL_SNIPPET" <<'EOF'
# Manual Claude Code accounts. Sourced from ~/.bashrc.
# claude and claude1 are account 1. claude2 is account 2.

claude1() {
  "${HOME}/.config/claude/claude-accounts" run 1 "$@"
}

claude2() {
  "${HOME}/.config/claude/claude-accounts" run 2 "$@"
}

claude-status() {
  "${HOME}/.config/claude/claude-accounts" status
}
EOF
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
  write_wrapper claude1 '#!/usr/bin/env bash
exec "${HOME}/.config/claude/claude-accounts" run 1 "$@"'
  write_wrapper claude2 '#!/usr/bin/env bash
exec "${HOME}/.config/claude/claude-accounts" run 2 "$@"'
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
  if ! grep -q '\.local/bin' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# Local user binaries (Claude Code and the account commands live here).
export PATH="$HOME/.local/bin:$PATH"
EOF
  fi
  if ! grep -q 'config/claude/shell.bash' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# Claude Code accounts: claude1 and claude2 are separate logins with one shared memory.
# Plain `claude` stays on account 1. Start claude2 yourself to use the other login.
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
  printf 'account 2 (claude2): %s\n' "$(auth_line "${ACCOUNT2}/.credentials.json" "${ACCOUNT2}/.claude.json")"
  printf 'shared store: %s\n' "$SHARED"
  printf 'account 2 config: %s\n' "$ACCOUNT2"

  local name dst target
  for name in "${SHARED_DIRS[@]}" "${SHARED_FILES[@]}"; do
    dst="${ACCOUNT2}/${name}"
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

  cat <<'EOF'

claude and claude1 always start account 1. claude2 always starts account 2.
Run the other command yourself when you want the other login.

Same directory, other login, same memory and transcript:
  claude2 -c
  claude2 --resume
EOF
}

print_login_help() {
  cat <<'EOF'

Sign each account in once. On a headless server the terminal prints a URL
and a one-time code because there is no local browser. Open that URL on any
other computer and finish the login there. This shell waits until you do.

  claude auth login
  claude2 auth login

Check both logins with:
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
  printf 'Commands: claude, claude1, claude2, claude-status\n'
  printf 'Open a new shell, or run: source ~/.bashrc\n'
  print_status
  print_login_help
}

run_account() {
  local which="$1"
  shift
  local bin
  bin="$(claude_bin)"

  case "$which" in
    1)
      exec env -u CLAUDE_CONFIG_DIR "$bin" "$@"
      ;;
    2)
      ensure
      exec env CLAUDE_CONFIG_DIR="$ACCOUNT2" "$bin" "$@"
      ;;
    *)
      die "account must be 1 or 2"
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: claude-accounts <command>

  setup           install commands, shell hooks, and the shared account links
  ensure          create account 2 and link it at the shared store
  status          show both logins and the shared links
  run 1|2 [args]  start Claude Code on that account, passing args through

Run setup on each computer. Account 1 is ~/.claude. Account 2 is
~/.config/claude/accounts/2. Plain `claude` stays on account 1.

Copy this file to another machine and run:
  bash setup-claude-accounts
EOF
}

main() {
  local cmd="${1:-}"
  local invoked
  invoked="$(basename "$0")"

  if [[ -z "$cmd" && "$invoked" == "setup-claude-accounts" ]]; then
    setup
    return
  fi

  case "$cmd" in
    setup)
      setup
      ;;
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
