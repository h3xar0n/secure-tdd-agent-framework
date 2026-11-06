#!/bin/bash
# Universal Modular Security Gate - Pre-Commit & Pre-Push Hook
# Executes the sequential Secure TDD pipeline:
# Stage 0 (optional module): Pre-Commit Secrets & Sensitive File Gate (engine_precommit.sh)
# Stage 1: Deterministic Scan & AST Autofix (Semgrep)
# Stage 2: Semantic Analysis & TDD Remediation (CodeMender)
#
# Configuration:
#   SECURITY_GATE_SCANNER        - 'auto' (default pipeline), 'codemender' (or 'cm'), or 'semgrep'
#   SECURITY_GATE_BLOCK_SEVERITY - 'HIGH' (default), 'CRITICAL', 'MEDIUM', 'LOW'
#   SECURITY_GATE_ALLOW_ON_ERROR - false (default) / true

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate_common.sh
source "$SCRIPT_DIR/lib/gate_common.sh"
if [ -f "$SCRIPT_DIR/lib/engine_precommit.sh" ]; then
  # shellcheck source=lib/engine_precommit.sh
  source "$SCRIPT_DIR/lib/engine_precommit.sh"
fi
# shellcheck source=lib/engine_semgrep.sh
source "$SCRIPT_DIR/lib/engine_semgrep.sh"
# shellcheck source=lib/engine_codemender.sh
source "$SCRIPT_DIR/lib/engine_codemender.sh"

# Ensure execution always runs from the repository root even when invoked from .agents/
cd "$(_gate_repo_root)" || exit 1

# Returns 0 if the command string contains an unquoted `git ... push` invocation
# (including global git flags like `git -C /repo push` or `git --no-pager push`
# and compound commands like `git status && git push`), while ignoring quoted
# string arguments such as `echo "git push"` or `git commit -m "fix before git push"`.
is_git_push_command() {
  local unquoted
  unquoted=$(printf '%s\n' "${1:-}" | sed -E "s/'[^']*'|\"([^\"]|\\\\.)*\"/__QUOTED__/g")
  printf '%s\n' "$unquoted" | grep -Eq '(^|[;&|(])[[:space:]]*(sudo[[:space:]]+|env[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*|([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+)?([^[:space:];&|(]*/)?git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|(--git-dir|--work-tree|--namespace|--exec-path)[[:space:]]+[^[:space:]]+|-[a-zA-Z0-9._=-]+))*[[:space:]]+push([[:space:]|;&)]|$)'
}

# Filter stdin JSON payload & environment variables: Antigravity and Claude Code pass tool input via stdin or env.
# Intercept 'git commit' (Stage 0 if engine_precommit.sh is present) and 'git push' (Stages 1 & 2);
# allow non-matching commands immediately.
STDIN_INPUT=""
if [ ! -t 0 ]; then
  # Read available stdin without hanging if empty
  STDIN_INPUT=$(cat 2>/dev/null || true)
fi

CMD_TO_CHECK=""
if [ -n "${STDIN_INPUT//[[:space:]]/}" ]; then
  if printf '%s\n' "$STDIN_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
    CMD_TO_CHECK=$(printf '%s\n' "$STDIN_INPUT" | jq -r '
      .toolCall?.args?.CommandLine? //
      .toolCall?.args?.command? //
      .tool_input?.command? //
      .tool_input?.CommandLine? //
      .CommandLine? //
      .command? //
      empty
    ' 2>/dev/null || true)
  fi
fi

if [ -z "$CMD_TO_CHECK" ]; then
  CMD_TO_CHECK="${COMMAND_LINE:-${TOOL_INPUT:-}}"
  case "$CMD_TO_CHECK" in
    \{*)
      CMD_TO_CHECK=$(printf '%s\n' "$CMD_TO_CHECK" | jq -r '
        .toolCall?.args?.CommandLine? //
        .toolCall?.args?.command? //
        .tool_input?.command? //
        .tool_input?.CommandLine? //
        .CommandLine? //
        .command? //
        empty
      ' 2>/dev/null || printf '%s' "$CMD_TO_CHECK")
      ;;
  esac
fi

if [ -n "$CMD_TO_CHECK" ]; then
  export COMMAND_LINE="$CMD_TO_CHECK"
fi

# Stage 0: Pre-Commit Secrets & Sensitive File Gate (when engine_precommit.sh is installed)
if declare -F is_precommit_command >/dev/null 2>&1 && is_precommit_command "$CMD_TO_CHECK"; then
  run_precommit_gate "$CMD_TO_CHECK"
  allow
fi

# Non-push command filter (e.g. ls, git status, pytest, git log): allow immediately
if [ -n "$CMD_TO_CHECK" ] || { [ -n "${STDIN_INPUT//[[:space:]]/}" ] && printf '%s\n' "$STDIN_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; }; then
  if ! is_git_push_command "$CMD_TO_CHECK"; then
    allow
  fi
fi

SCANNER="${SECURITY_GATE_SCANNER:-auto}"

case "$(printf '%s' "$SCANNER" | tr '[:upper:]' '[:lower:]')" in
  codemender|cm)
    run_codemender_gate false
    ;;
  semgrep)
    run_semgrep_gate false
    ;;
  auto|pipeline|"")
    # Sequential Pipeline Execution: each installed engine runs in sequence.
    # If an engine is not installed, the pipeline skips it and proceeds to the next.
    ran_any=false
    if command -v semgrep >/dev/null 2>&1; then
      run_semgrep_gate true
      ran_any=true
    fi
    if command -v cm >/dev/null 2>&1; then
      run_codemender_gate true
      ran_any=true
    fi
    if [ "$ran_any" = "false" ]; then
      echo "No security scanner CLI (semgrep or cm) found on PATH. Proceeding without local SAST verification." >&2
      allow
    fi
    allow
    ;;
  *)
    handle_scan_error "scanner" "Unknown SECURITY_GATE_SCANNER '$SCANNER'. Supported: 'auto', 'pipeline', 'codemender', 'semgrep'." false
    ;;
esac
