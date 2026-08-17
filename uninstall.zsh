#!/usr/bin/env zsh
set -euo pipefail

shell_rc="${ZDOTDIR:-$HOME}/.zshrc"
install_dir="${CODEX_SWITCH_HOME:-$HOME/.config/codex-switch}"
start_marker='# >>> codex-switch >>>'
end_marker='# <<< codex-switch <<<'

if [[ -f "$shell_rc" ]]; then
  target_rc="$(readlink -f -- "$shell_rc")" || {
    print -u2 "codex-switch: cannot resolve $shell_rc"
    exit 1
  }
  temporary_file="$(mktemp "${target_rc}.codex-switch.XXXXXX")"
  trap 'rm -f -- "$temporary_file"' EXIT
  sed "/$start_marker/,/$end_marker/d" "$target_rc" > "$temporary_file"
  cat "$temporary_file" > "$target_rc"
  rm -f -- "$temporary_file"
  trap - EXIT
fi

print "Shell hook removed from $shell_rc"
print "Configuration and workspaces were retained: $install_dir and ${CODEX_SWITCH_WORKSPACES_ROOT:-$HOME/.codex-switch/workspaces}"
print 'Remove them manually only if their sessions and memories are no longer needed.'
