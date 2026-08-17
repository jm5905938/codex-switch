#!/usr/bin/env zsh
set -euo pipefail

project_dir="${0:A:h}"
install_dir="${CODEX_SWITCH_HOME:-$HOME/.config/codex-switch}"
shell_rc="${ZDOTDIR:-$HOME}/.zshrc"
source_line="source \"$install_dir/codex-switch.zsh\""
start_marker='# >>> codex-switch >>>'
end_marker='# <<< codex-switch <<<'

mkdir -p -- "$install_dir"
install -m 600 "$project_dir/lib/codex-switch.zsh" "$install_dir/codex-switch.zsh"

touch "$shell_rc"
if ! grep -Fqx "$source_line" "$shell_rc"; then
  print >> "$shell_rc"
  print >> "$shell_rc" "$start_marker"
  print >> "$shell_rc" '# Shared Codex API/GPT workspace switcher.'
  print >> "$shell_rc" "$source_line"
  print >> "$shell_rc" "$end_marker"
fi

print "Installed codex-switch into $install_dir"
print "Run: source $shell_rc"
print 'Then run: codex-switch setup && codex-switch api-key && codex-gpt login'
