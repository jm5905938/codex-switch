#!/usr/bin/env zsh
set -euo pipefail

shell_rc="${ZDOTDIR:-$HOME}/.zshrc"
install_dir="${CODEX_SWITCH_HOME:-$HOME/.config/codex-switch}"
start_marker='# >>> codex-switch >>>'
end_marker='# <<< codex-switch <<<'

if [[ -f "$shell_rc" ]]; then
  temporary_file="$(mktemp)"
  sed "/$start_marker/,/$end_marker/d" "$shell_rc" > "$temporary_file"
  mv "$temporary_file" "$shell_rc"
fi

print "Shell hook removed from $shell_rc"
print "Configuration and workspaces were retained: $install_dir and ${CODEX_SWITCH_WORKSPACES_ROOT:-$HOME/.codex-switch/workspaces}"
print 'Remove them manually only if their sessions and memories are no longer needed.'
