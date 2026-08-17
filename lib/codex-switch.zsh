# Shared-workspace provider switcher for Codex CLI.
# Source this file from .zshrc; do not execute it directly.

[[ -n ${ZSH_VERSION-} ]] || {
  print -u2 'codex-switch: Zsh is required'
  return 1 2>/dev/null || exit 1
}

typeset -g CODEX_SWITCH_HOME="${CODEX_SWITCH_HOME:-$HOME/.config/codex-switch}"
typeset -g CODEX_SWITCH_WORKSPACES_ROOT="${CODEX_SWITCH_WORKSPACES_ROOT:-$HOME/.codex-switch/workspaces}"
typeset -g CODEX_SWITCH_ENV_FILE="${CODEX_SWITCH_ENV_FILE:-$CODEX_SWITCH_HOME/api.env}"
typeset -g CODEX_SWITCH_API_CONFIG="${CODEX_SWITCH_API_CONFIG:-$CODEX_SWITCH_HOME/api-base-url}"
typeset -g CODEX_SWITCH_BASE_CONFIG="${CODEX_SWITCH_BASE_CONFIG:-$HOME/.codex/config.toml}"
typeset -g CODEX_SWITCH_GPT_PROFILE='codex-switch-gpt'
typeset -g CODEX_SWITCH_API_PROFILE='codex-switch-api'
typeset -g CODEX_SWITCH_FALLBACK_MARKER='# Managed by codex-switch: fallback config'

if [[ -f "$CODEX_SWITCH_ENV_FILE" ]]; then
  source "$CODEX_SWITCH_ENV_FILE"
fi

_codex_switch_toml_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  print -r -- "\"$value\""
}

_codex_switch_workspace_dir() {
  emulate -L zsh

  local common_dir identity_root project_name short_hash

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
    [[ "$common_dir" == /* ]] || common_dir="$PWD/$common_dir"
    common_dir="$(readlink -f -- "$common_dir" 2>/dev/null)" || return 1
    if [[ "${common_dir:t}" == '.git' ]]; then
      identity_root="${common_dir:h}"
    else
      identity_root="$common_dir"
    fi
  else
    identity_root="$PWD"
  fi

  identity_root="$(readlink -f -- "$identity_root" 2>/dev/null)" || return 1
  project_name="${identity_root:t}"
  [[ -n "$project_name" && "$project_name" != '/' ]] || project_name='repo'
  project_name="$(LC_ALL=C print -rn -- "$project_name" | tr -c 'A-Za-z0-9._-' '-')"
  [[ -n "$project_name" ]] || project_name='repo'
  short_hash="$(print -rn -- "$identity_root" | sha256sum | cut -c1-8)" || return 1
  print -r -- "$CODEX_SWITCH_WORKSPACES_ROOT/${project_name}-${short_hash}"
}

_codex_switch_write_base_config() {
  emulate -L zsh

  local workspace_dir="$1" config_path
  config_path="$workspace_dir/config.toml"
  mkdir -p -- "$workspace_dir" || return 1

  # A deleted global config leaves a broken symlink behind. Treat that as an
  # unavailable workspace config so it can be replaced with a fallback.
  if [[ -L "$config_path" && ! -e "$config_path" ]]; then
    rm -- "$config_path" || return 1
  fi

  if [[ -f "$CODEX_SWITCH_BASE_CONFIG" ]]; then
    if [[ -f "$config_path" && ! -L "$config_path" ]] && grep -Fqx "$CODEX_SWITCH_FALLBACK_MARKER" "$config_path"; then
      rm -- "$config_path" || return 1
    fi

    if [[ ! -e "$config_path" && ! -L "$config_path" ]]; then
      ln -s -- "$CODEX_SWITCH_BASE_CONFIG" "$config_path" || return 1
    fi
  elif [[ ! -e "$config_path" && ! -L "$config_path" ]]; then
    cat > "$config_path" <<EOF
$CODEX_SWITCH_FALLBACK_MARKER
[features]
memories = true

[memories]
use_memories = true
generate_memories = true
EOF
  fi

  _codex_switch_link_native_profiles "$workspace_dir"
}

_codex_switch_link_native_profiles() {
  emulate -L zsh

  local workspace_dir="$1" native_dir profile_file destination
  native_dir="${CODEX_SWITCH_BASE_CONFIG:h}"

  for profile_file in "$native_dir"/*.config.toml(N); do
    [[ "${profile_file:t}" == "${CODEX_SWITCH_GPT_PROFILE}.config.toml" ]] && continue
    [[ "${profile_file:t}" == "${CODEX_SWITCH_API_PROFILE}.config.toml" ]] && continue
    destination="$workspace_dir/${profile_file:t}"
    [[ -e "$destination" || -L "$destination" ]] || ln -s -- "$profile_file" "$destination" || return 1
  done
}

_codex_switch_write_gpt_profile() {
  emulate -L zsh

  local workspace_dir="$1" profile_path

  _codex_switch_write_base_config "$workspace_dir" || return 1

  profile_path="$workspace_dir/${CODEX_SWITCH_GPT_PROFILE}.config.toml"
  [[ ! -L "$profile_path" ]] || rm -- "$profile_path" || return 1
  cat > "$profile_path" <<'EOF'
# Official OpenAI provider. Authenticate with `codex-gpt login`.
model_provider = "openai"
EOF
}

_codex_switch_write_api_profile() {
  emulate -L zsh

  local base_url="$1" workspace_dir="$2" profile_path
  local quoted_url
  quoted_url="$(_codex_switch_toml_string "$base_url")"

  _codex_switch_write_base_config "$workspace_dir" || return 1

  profile_path="$workspace_dir/${CODEX_SWITCH_API_PROFILE}.config.toml"
  [[ ! -L "$profile_path" ]] || rm -- "$profile_path" || return 1
  cat > "$profile_path" <<EOF
# Third-party Responses API provider. The key comes from CODEX_SWITCH_API_KEY.
model_provider = "thirdparty"

[model_providers.thirdparty]
name = "Third-party"
base_url = $quoted_url
wire_api = "responses"
requires_openai_auth = false
env_key = "CODEX_SWITCH_API_KEY"
EOF
}

_codex_switch_prepare_workspace() {
  emulate -L zsh

  local profile="$1" workspace_dir base_url
  workspace_dir="$(_codex_switch_workspace_dir)" || return 1

  case "$profile" in
    "$CODEX_SWITCH_GPT_PROFILE")
      _codex_switch_write_gpt_profile "$workspace_dir" || return 1
      ;;
    "$CODEX_SWITCH_API_PROFILE")
      [[ -f "$CODEX_SWITCH_API_CONFIG" ]] || {
        print -u2 'codex-switch: API endpoint is not configured; run `codex-switch setup`.'
        return 1
      }
      [[ -n ${CODEX_SWITCH_API_KEY-} ]] || {
        print -u2 'codex-switch: API key is not configured; run `codex-switch api-key`.'
        return 1
      }
      base_url="$(<"$CODEX_SWITCH_API_CONFIG")"
      [[ -n "$base_url" ]] || {
        print -u2 'codex-switch: API endpoint is empty; run `codex-switch setup`.'
        return 1
      }
      _codex_switch_write_api_profile "$base_url" "$workspace_dir" || return 1
      ;;
    *)
      print -u2 "codex-switch: unknown provider profile: $profile"
      return 2
      ;;
  esac

  print -r -- "$workspace_dir"
}

# Run native Codex in a repository-local CODEX_HOME. It accepts ordinary Codex
# options, including a manually selected --profile.
cproj() {
  emulate -L zsh

  local workspace_dir
  workspace_dir="$(_codex_switch_workspace_dir)" || return 1
  _codex_switch_write_base_config "$workspace_dir" || return 1
  print -u2 "codex workspace: $workspace_dir"
  CODEX_HOME="$workspace_dir" command codex "$@"
}

_codex_switch_run() {
  emulate -L zsh

  local profile="$1"
  shift
  local workspace_dir
  workspace_dir="$(_codex_switch_prepare_workspace "$profile")" || return 1

  case "${1-}" in
    login|logout|doctor|update|completion|features|help)
      CODEX_HOME="$workspace_dir" command codex "$@"
      ;;
    resume)
      shift
      local arg add_all=true
      for arg in "$@"; do
        [[ "$arg" == '--all' || "$arg" == '--last' ]] && add_all=false
      done
      if [[ "$add_all" == true ]]; then
        CODEX_HOME="$workspace_dir" command codex --profile "$profile" resume --all "$@"
      else
        CODEX_HOME="$workspace_dir" command codex --profile "$profile" resume "$@"
      fi
      ;;
    *)
      CODEX_HOME="$workspace_dir" command codex --profile "$profile" "$@"
      ;;
  esac
}

cproj-api() {
  _codex_switch_run "$CODEX_SWITCH_API_PROFILE" "$@"
}

cproj-gpt() {
  _codex_switch_run "$CODEX_SWITCH_GPT_PROFILE" "$@"
}

codex() {
  cproj-api "$@"
}

codex-gpt() {
  cproj-gpt "$@"
}

codex-g() {
  command codex "$@"
}

codex-switch() {
  emulate -L zsh

  local command_name="${1:-status}"
  shift 2>/dev/null || true

  case "$command_name" in
    setup)
      local base_url="${CODEX_SWITCH_API_BASE_URL:-}"
      if [[ -z "$base_url" ]]; then
        read -r "base_url?Third-party Responses API base URL: " || return 1
      fi
      [[ -n "$base_url" ]] || {
        print -u2 'codex-switch: endpoint cannot be empty'
        return 1
      }
      mkdir -p -- "$CODEX_SWITCH_HOME" || return 1
      print -r -- "$base_url" >| "$CODEX_SWITCH_API_CONFIG" || return 1
      chmod 600 "$CODEX_SWITCH_API_CONFIG" || return 1
      print 'Third-party endpoint saved. Run `codex-switch api-key` to store its API key.'
      ;;
    api-key)
      local api_key
      read -r -s "api_key?Third-party API key: " || return 1
      print
      [[ -n "$api_key" ]] || {
        print -u2 'codex-switch: key cannot be empty'
        return 1
      }
      mkdir -p -- "$CODEX_SWITCH_HOME" || return 1
      print -r -- "export CODEX_SWITCH_API_KEY=${(q)api_key}" >| "$CODEX_SWITCH_ENV_FILE" || return 1
      chmod 600 "$CODEX_SWITCH_ENV_FILE" || return 1
      export CODEX_SWITCH_API_KEY="$api_key"
      unset api_key
      print 'Third-party API key saved.'
      ;;
    status)
      local workspace_dir
      workspace_dir="$(_codex_switch_workspace_dir)" || return 1
      print "workspace: $workspace_dir"
      if [[ -f "$CODEX_SWITCH_API_CONFIG" ]]; then
        print 'API endpoint: configured'
      else
        print 'API endpoint: missing'
      fi
      if [[ -n ${CODEX_SWITCH_API_KEY-} ]]; then
        print 'API key: configured'
      else
        print 'API key: missing'
      fi
      if [[ -f "$workspace_dir/auth.json" ]]; then
        print 'ChatGPT login: present in shared workspace'
      else
        print 'ChatGPT login: not present in shared workspace'
      fi
      ;;
    help|-h|--help)
      print 'Usage: codex-switch <setup|api-key|status>'
      ;;
    *)
      print -u2 "codex-switch: unknown command: $command_name"
      print -u2 'Usage: codex-switch <setup|api-key|status>'
      return 2
      ;;
  esac
}
