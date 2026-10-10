#!/bin/bash
# Test harness for the Antigravity security gate hooks. Mirrors
# claude-code/.claude/hooks/tests/run_tests.sh, adapted for Antigravity's
# hook envelope ({"allow_tool": ...} instead of Claude Code's
# hookSpecificOutput.permissionDecision) and its lack of a stdin JSON
# payload (Antigravity's hooks.json matcher already scopes the hook to
# `git push*`, so the script itself doesn't need to detect the command).
#
# Usage: ./run_tests.sh [path-to-agents-dir]

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MOCK_BIN="$SCRIPT_DIR/mocks"

PASS_COUNT=0
FAIL_COUNT=0

log_fail() { echo "  FAIL: $1"; }

setup_repo() {
  local dir
  dir=$(mktemp -d)
  (
    cd "$dir" || exit 1
    git init -q
    git config user.email "dev@example.com"
    git config user.name "Test Dev"
    git config core.autocrlf false
    echo "print('hello')" > README.txt
    echo -e "# Project Context\n\n## 4. Continuous Evolution: Auto-Evolved Conventions\n- Initial" > CONTEXT.md
    git add README.txt CONTEXT.md
    git commit -q -m "initial"
    echo "# a file that a scanner will flag" > vuln.py
    git add vuln.py
    git commit -q -m "add vuln.py"
  )
  echo "$dir"
}

run_hook() {
  local script="$1" repo="$2"
  local state_dir
  state_dir=$(mktemp -d)
  (
    cd "$repo" || exit 1
    # Antigravity's hook contract doesn't consume stdin for a JSON
    # payload (unlike Claude Code), so `read -p` prompts read real stdin.
    # Feed enough blank-line "just pressed Enter" answers to get through
    # the RED confirmation and/or the escalation menu without a real
    # tty; an unrecognized/empty escalation choice is expected to fail
    # closed (deny), which is exactly what these tests check for.
    PATH="$MOCK_BIN:$PATH" \
    MOCK_STATE_DIR="$state_dir" \
    MOCK_FILE="vuln.py" \
    SECURITY_GATE_STATE_DB="$repo/.codemender-test/state.db" \
    bash "$script" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  rm -rf "$state_dir"
}

decision() {
  jq -r '
    if .hookSpecificOutput.permissionDecision != null then
      .hookSpecificOutput.permissionDecision
    elif .allow_tool == true then
      "allow"
    elif .allow_tool == false then
      "deny"
    else
      "MISSING"
    end
  ' "$1/.hook_stdout" 2>/dev/null
}

reason() {
  jq -r '
    if .hookSpecificOutput.permissionDecisionReason != null then
      .hookSpecificOutput.permissionDecisionReason
    else
      .reason // ""
    end
  ' "$1/.hook_stdout" 2>/dev/null
}

log_events() {
  local repo="$1"
  [ -f "$repo/.security-gate/findings-log.ndjson" ] || { echo ""; return; }
  jq -r '.event' "$repo/.security-gate/findings-log.ndjson" 2>/dev/null | tr '\n' ','
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS_COUNT=$((PASS_COUNT+1))
  else
    FAIL_COUNT=$((FAIL_COUNT+1))
    log_fail "$desc (expected [$expected], got [$actual])"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT+1))
  else
    FAIL_COUNT=$((FAIL_COUNT+1))
    log_fail "$desc (expected to contain [$needle], got [$haystack])"
  fi
}

cleanup_repo() { rm -rf "$1"; }

# --- test cases (same coverage as the Claude Code harness) --------------

test_cm_pass_no_findings() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=clean run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: clean scan allows" "allow" "$(decision "$repo")"
  cleanup_repo "$repo"
}

test_cm_error_blocks_by_default() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=error run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: scan error blocks by default" "deny" "$(decision "$repo")"
  assert_contains "cm: error reason mentions scan failure" "$(reason "$repo")" "failed to run"
  assert_contains "cm: error logged as ERROR" "$(log_events "$repo")" "ERROR"
  cleanup_repo "$repo"
}

test_cm_error_allow_on_error_true_tags_commit() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=codemender SECURITY_GATE_ALLOW_ON_ERROR=true MOCK_CM_REPORT_MODE=error \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: scan error allows when opted in" "allow" "$(decision "$repo")"
  assert_contains "cm: error still logged even when allowed through" "$(log_events "$repo")" "ERROR"
  local tag_found
  tag_found=$(cd "$repo" && git tag -l "unverified-scan*" | wc -l | tr -d ' ')
  assert_eq "cm: fail-open created unverified-scan git tag" "1" "$tag_found"
  cleanup_repo "$repo"
}

test_cm_advisory_low_severity_does_not_block() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=low run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: low-severity finding does not block" "allow" "$(decision "$repo")"
  assert_contains "cm: low-severity finding logged as ADVISORY" "$(log_events "$repo")" "ADVISORY"
  cleanup_repo "$repo"
}

test_cm_blocking_high_severity_denies_and_prompts_agent() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: high-severity finding blocks push and prompts agent" "deny" "$(decision "$repo")"
  assert_contains "cm: attempt 1 logged as DENIED_TO_AGENT" "$(log_events "$repo")" "DENIED_TO_AGENT"
  cleanup_repo "$repo"
}

test_cm_agent_resolves_finding_subsequent_push_allows() {
  local repo; repo=$(setup_repo)
  # Turn 1: Agent tries push with vulnerability -> blocked
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: turn 1 denies" "deny" "$(decision "$repo")"

  # Turn 2: Agent executes TDD fix -> rescan clean -> allowed
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=clean \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: turn 2 after TDD fix allows" "allow" "$(decision "$repo")"
  assert_contains "cm: resolved finding logged as FIXED" "$(log_events "$repo")" "FIXED"
  local context_content
  context_content=$(cd "$repo" && cat CONTEXT.md 2>/dev/null || echo "")
  assert_contains "cm: CONTEXT.md was evolved with rule" "$context_content" "Auto-Evolved Convention (F1)"
  cleanup_repo "$repo"
}

test_cm_blocking_retries_exhausted_cm_verify_clean_allows_with_advisory() {
  local repo; repo=$(setup_repo)
  # Turns 1, 2, 3: 3 failed attempts
  for _ in 1 2 3; do
    SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high \
      run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  done
  # Turn 4: Budget exhausted (> 3 attempts). cm verify clean (exit 1) -> allows with advisory
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high MOCK_CM_VERIFY_MODE=clean \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: unfixable finding + cm verify clean allows with advisory" "allow" "$(decision "$repo")"
  assert_contains "cm: advisory note logged in findings-log" "$(log_events "$repo")" "ADVISORY"
  cleanup_repo "$repo"
}

test_cm_blocking_retries_exhausted_cm_verify_exploitable_fails_closed() {
  local repo; repo=$(setup_repo)
  for _ in 1 2 3; do
    SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high \
      run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  done
  # Turn 4: cm verify confirms exploitable (exit 0) -> permanent deny
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high MOCK_CM_VERIFY_MODE=exploitable \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: unfixable finding + cm verify exploitable denies" "deny" "$(decision "$repo")"
  assert_contains "cm: unresolved finding logged as BLOCKED" "$(log_events "$repo")" "BLOCKED"
  cleanup_repo "$repo"
}

test_cm_blocking_retries_exhausted_cm_verify_crash_fails_closed() {
  local repo; repo=$(setup_repo)
  for _ in 1 2 3; do
    SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high \
      run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  done
  # Turn 4: cm verify crash (exit 2) -> denies
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=high MOCK_CM_VERIFY_MODE=error \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: cm verify crash denies" "deny" "$(decision "$repo")"
  assert_contains "cm: verify failure logged as BLOCKED" "$(log_events "$repo")" "BLOCKED"
  cleanup_repo "$repo"
}

test_cm_mixed_severity_fixes_blocking_logs_advisory() {
  local repo; repo=$(setup_repo)
  # Turn 1: mixed findings -> low advisory, high denies
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=mixed \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: mixed severities denies on high" "deny" "$(decision "$repo")"

  # Turn 2: agent fixed high finding -> only low remains -> allows
  SECURITY_GATE_SCANNER=codemender MOCK_CM_REPORT_MODE=low \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "cm: after fix only advisory remains -> allows" "allow" "$(decision "$repo")"
  assert_contains "cm: fixed high finding logged as FIXED" "$(log_events "$repo")" "FIXED"
  assert_contains "cm: low finding logged as ADVISORY" "$(log_events "$repo")" "ADVISORY"
  cleanup_repo "$repo"
}

test_semgrep_pass_no_findings() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=semgrep MOCK_SEMGREP_MODE=clean run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "semgrep: clean scan allows" "allow" "$(decision "$repo")"
  cleanup_repo "$repo"
}

test_semgrep_error_blocks_by_default() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=semgrep MOCK_SEMGREP_MODE=error run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "semgrep: scan error blocks by default" "deny" "$(decision "$repo")"
  assert_contains "semgrep: error logged as ERROR" "$(log_events "$repo")" "ERROR"
  cleanup_repo "$repo"
}

test_semgrep_error_allow_on_error_true() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=semgrep SECURITY_GATE_ALLOW_ON_ERROR=true MOCK_SEMGREP_MODE=error \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "semgrep: scan error allows when opted in" "allow" "$(decision "$repo")"
  cleanup_repo "$repo"
}

test_semgrep_advisory_low_severity_does_not_block() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=semgrep MOCK_SEMGREP_MODE=low run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "semgrep: INFO severity does not block" "allow" "$(decision "$repo")"
  assert_contains "semgrep: INFO severity logged as ADVISORY" "$(log_events "$repo")" "ADVISORY"
  cleanup_repo "$repo"
}

test_semgrep_blocking_high_severity_denies_and_prompts_agent() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=semgrep MOCK_SEMGREP_MODE=high \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "semgrep: high severity blocks and prompts agent" "deny" "$(decision "$repo")"
  assert_contains "semgrep: logged as DENIED_TO_AGENT" "$(log_events "$repo")" "DENIED_TO_AGENT"
  cleanup_repo "$repo"
}

test_pipeline_semgrep_to_codemender_flow() {
  local repo; repo=$(setup_repo)
  # Pipeline mode: Semgrep finds high issue -> exported to Stage 2 -> Stage 2 denies and prompts agent
  SECURITY_GATE_SCANNER=auto MOCK_SEMGREP_MODE=high MOCK_CM_REPORT_MODE=clean \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "pipeline: Stage 1 finding exported to Stage 2 and prompts agent" "deny" "$(decision "$repo")"

  # Turn 2: Agent fixes issue -> clean on both stages -> allows
  SECURITY_GATE_SCANNER=auto MOCK_SEMGREP_MODE=clean MOCK_CM_REPORT_MODE=clean \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "pipeline: clean on both stages allows" "allow" "$(decision "$repo")"
  assert_contains "pipeline: logged as FIXED" "$(log_events "$repo")" "FIXED"
  cleanup_repo "$repo"
}

test_pipeline_deterministic_error_fail_open_proceeds_to_stage2() {
  local repo; repo=$(setup_repo)
  SECURITY_GATE_SCANNER=auto SECURITY_GATE_ALLOW_ON_ERROR=true MOCK_SEMGREP_MODE=error \
  MOCK_CM_REPORT_MODE=clean \
    run_hook "$AGENTS_DIR/security_gate_hook.sh" "$repo"
  assert_eq "pipeline: Stage 1 error with fail-open proceeds to Stage 2 and allows" "allow" "$(decision "$repo")"
  assert_contains "pipeline: Stage 1 error logged as ERROR" "$(log_events "$repo")" "ERROR"
  cleanup_repo "$repo"
}

test_pipeline_tools_missing_passes_smoothly() {
  local repo; repo=$(setup_repo)
  local no_tools_bin; no_tools_bin=$(mktemp -d)
  ln -s "$(command -v jq)" "$no_tools_bin/jq"
  ln -s "$(command -v git)" "$no_tools_bin/git"
  (
    cd "$repo" || exit 1
    PATH="$no_tools_bin:/usr/bin:/bin" \
    SECURITY_GATE_SCANNER=auto \
    bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
  )
  assert_eq "pipeline: missing scanner tools allows push gracefully" "allow" "$(decision "$repo")"
  rm -rf "$no_tools_bin"
  cleanup_repo "$repo"
}

test_skills_frontmatter_valid() {
  local skills_dir="$AGENTS_DIR/skills"
  [ -d "$skills_dir" ] || return 0
  local bad=0
  for skill_md in "$skills_dir"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    local folder_name
    folder_name=$(basename "$(dirname "$skill_md")")
    local fm_block
    fm_block=$(awk '/^---$/{c++; if (c==2) exit; next} c==1{print}' "$skill_md")
    local fm_name
    fm_name=$(printf '%s
' "$fm_block" | awk '/^name:/{sub(/^name:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit}')
    local fm_desc_raw
    fm_desc_raw=$(printf '%s
' "$fm_block" | awk '/^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}')
    if [[ ! "$fm_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      bad=1
      log_fail "skill frontmatter name [$fm_name] in $skill_md must be kebab-case"
    fi
    if [ "$fm_name" != "$folder_name" ]; then
      bad=1
      log_fail "skill frontmatter name [$fm_name] does not match directory [$folder_name]"
    fi
    if [ -z "$fm_desc_raw" ]; then
      bad=1
      log_fail "skill frontmatter description missing in $skill_md"
    fi
    if [[ "$fm_desc_raw" == *": "* ]] || [[ "$fm_desc_raw" == *"("* ]] || [[ "$fm_desc_raw" == *")"* ]]; then
      bad=1
      log_fail "skill frontmatter description in $skill_md contains forbidden characters (colons or parentheses)"
    fi
  done
  assert_eq "skills: all SKILL.md files have valid YAML frontmatter and kebab-case names" "0" "$bad"
}

# --- Pre-Commit Gate Tests ---

test_precommit_sensitive_files_blocked() {
  local repo; repo=$(setup_repo)
  (
    cd "$repo" || exit 1
    # 1. Test .env blocking
    echo "SECRET=123" > .env
    git add .env
    COMMAND_LINE="git commit -m 'add env'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging .env is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions sensitive file or .env" "$(reason "$repo")" ".env"
  assert_contains "precommit: audit log records BLOCKED event" "$(log_events "$repo")" "BLOCKED"

  (
    cd "$repo" || exit 1
    git reset -q HEAD .env && rm -f .env
    # 2. Test .env.local blocking (.env.*)
    echo "SECRET=123" > .env.local
    git add .env.local
    COMMAND_LINE="git commit -m 'add env.local'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging .env.local is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions .env.local" "$(reason "$repo")" ".env.local"

  (
    cd "$repo" || exit 1
    git reset -q HEAD .env.local && rm -f .env.local
    # 3. Test terraform state blocking (*.tfstate and *.tfstate.*)
    echo '{"version": 4}' > terraform.tfstate
    git add terraform.tfstate
    COMMAND_LINE="git commit -m 'add tfstate'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging .tfstate is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions terraform.tfstate" "$(reason "$repo")" "terraform.tfstate"

  (
    cd "$repo" || exit 1
    git reset -q HEAD terraform.tfstate && rm -f terraform.tfstate
    echo '{"version": 4}' > terraform.tfstate.backup
    git add terraform.tfstate.backup
    COMMAND_LINE="git commit -m 'add tfstate backup'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging terraform.tfstate.backup is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions terraform.tfstate.backup" "$(reason "$repo")" "terraform.tfstate.backup"

  (
    cd "$repo" || exit 1
    git reset -q HEAD terraform.tfstate.backup && rm -f terraform.tfstate.backup
    # 4. Test *.tfvars in subdirectory
    mkdir -p infra
    echo 'db_password = "secret"' > infra/prod.tfvars
    git add infra/prod.tfvars
    COMMAND_LINE="git commit -m 'add tfvars'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging infra/prod.tfvars is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions prod.tfvars" "$(reason "$repo")" "prod.tfvars"

  (
    cd "$repo" || exit 1
    git reset -q HEAD infra/prod.tfvars && rm -rf infra
    # 5. Test private key & certificate blocking (*.key, *.pem, id_rsa, *credentials*.json)
    echo "dummy key" > server.key
    git add server.key
    COMMAND_LINE="git commit -m 'add key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging server.key is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions server.key" "$(reason "$repo")" "server.key"

  (
    cd "$repo" || exit 1
    git reset -q HEAD server.key && rm -f server.key
    echo "dummy cert" > cert.pem
    git add cert.pem
    COMMAND_LINE="git commit -m 'add pem'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging cert.pem is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions cert.pem" "$(reason "$repo")" "cert.pem"

  (
    cd "$repo" || exit 1
    git reset -q HEAD cert.pem && rm -f cert.pem
    echo '{"type": "service_account"}' > gcp-credentials.json
    git add gcp-credentials.json
    COMMAND_LINE="git commit -m 'add credentials json'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging gcp-credentials.json is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions gcp-credentials.json" "$(reason "$repo")" "gcp-credentials.json"

  (
    cd "$repo" || exit 1
    git reset -q HEAD gcp-credentials.json && rm -f gcp-credentials.json
    echo "ssh private key" > id_rsa
    git add id_rsa
    COMMAND_LINE="git commit -m 'add id_rsa'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging id_rsa is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions id_rsa" "$(reason "$repo")" "id_rsa"

  cleanup_repo "$repo"
}

test_precommit_api_keys_blocked() {
  local repo; repo=$(setup_repo)
  (
    cd "$repo" || exit 1
    # 1. Test AWS API key in code (constructed via printf so static scanners do not flag test file)
    printf 'AWS_KEY = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" > config.py
    git add config.py
    COMMAND_LINE="git commit -m 'add aws key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging AWS AKIA key is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions AWS Access Key or secret" "$(reason "$repo")" "AWS Access Key"
  assert_contains "precommit: secret block logged to findings-log.ndjson" "$(log_events "$repo")" "BLOCKED"

  (
    cd "$repo" || exit 1
    git reset -q HEAD config.py && rm -f config.py
    # 2. Test GCP API key in code
    printf 'AIZA_KEY = "%s%s"\n' "AIzaSyD-" "1234567890abcdefghijklmnopqrst" > config.py
    git add config.py
    COMMAND_LINE="git commit -m 'add gcp key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging GCP AIza key is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions Google API Key or secret" "$(reason "$repo")" "Google API Key"

  (
    cd "$repo" || exit 1
    git reset -q HEAD config.py && rm -f config.py
    # 3. Test GitHub classic PAT (ghp_) and fine-grained PAT (github_pat_)
    printf 'GITHUB_TOKEN = "%s%s"\n' "ghp_" "1234567890abcdefghijklmnopqrstuvwxyz" > config.py
    git add config.py
    COMMAND_LINE="git commit -m 'add github token'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging GitHub ghp_ token is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions GitHub Personal Access Token" "$(reason "$repo")" "GitHub Personal Access Token"

  (
    cd "$repo" || exit 1
    git reset -q HEAD config.py && rm -f config.py
    printf 'GH_FINE_PAT = "%s%s"\n' "github_pat_" "11AA22BB33CC44DD55EE66_0123456789abcdef" > config.py
    git add config.py
    COMMAND_LINE="git commit -m 'add fine-grained github pat'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging GitHub github_pat_ token is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions GitHub Personal Access Token" "$(reason "$repo")" "GitHub Personal Access Token"

  (
    cd "$repo" || exit 1
    git reset -q HEAD config.py && rm -f config.py
    # 4. Test RSA, OPENSSH, and PGP Private Keys in code
    printf -- '-----BEGIN %s PRIVATE KEY-----\nMIIEowIBAAKCAQEA0Y1\n-----END %s PRIVATE KEY-----\n' "RSA" "RSA" > secret.txt
    git add secret.txt
    COMMAND_LINE="git commit -m 'add rsa private key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging RSA private key is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions Private Key" "$(reason "$repo")" "Private Key"

  (
    cd "$repo" || exit 1
    git reset -q HEAD secret.txt && rm -f secret.txt
    printf -- '-----BEGIN %s PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5vbmU=\n-----END %s PRIVATE KEY-----\n' "OPENSSH" "OPENSSH" > openssh.txt
    git add openssh.txt
    COMMAND_LINE="git commit -m 'add openssh private key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging OPENSSH private key is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions Private Key" "$(reason "$repo")" "Private Key"

  (
    cd "$repo" || exit 1
    git reset -q HEAD openssh.txt && rm -f openssh.txt
    printf -- '-----BEGIN %s PRIVATE KEY BLOCK-----\nlQOYBGXyAAAA\n-----END %s PRIVATE KEY BLOCK-----\n' "PGP" "PGP" > pgp.txt
    git add pgp.txt
    COMMAND_LINE="git commit -m 'add pgp private key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging PGP private key block is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions Private Key" "$(reason "$repo")" "Private Key"

  (
    cd "$repo" || exit 1
    git reset -q HEAD pgp.txt && rm -f pgp.txt
    # 5. Test Generic High-Entropy API Key assignment
    printf 'api_key = "%s%s"\n' "mock_high_entropy_token_" "0123456789abcdef0123456789abcdef" > config.py
    git add config.py
    COMMAND_LINE="git commit -m 'add generic high-entropy api_key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: staging generic high-entropy api_key is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: reason mentions Generic High-Entropy API Key" "$(reason "$repo")" "Generic High-Entropy API Key"

  cleanup_repo "$repo"
}

test_precommit_clean_allowed() {
  local repo; repo=$(setup_repo)
  (
    cd "$repo" || exit 1
    # Unstaged/untracked .env in working tree must NOT block a clean staged commit
    echo "UNSTAGED_SECRET=123" > .env
    echo "def safe_function(): pass" > safe.py
    git add safe.py
    COMMAND_LINE="git commit -m 'clean safe code'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: clean staged commit is allowed even with untracked .env" "allow" "$(decision "$repo")"

  (
    cd "$repo" || exit 1
    rm -f .env
    # Safe template exemptions (.env.example, .env.template) must be allowed
    echo "API_KEY=your_key_here" > .env.example
    echo "DB_URL=postgres://localhost/db" > .env.template
    git add .env.example .env.template
    COMMAND_LINE="git commit -m 'add env templates'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: .env.example and .env.template are allowed" "allow" "$(decision "$repo")"

  cleanup_repo "$repo"
}

test_precommit_edge_cases_and_claude_stdin() {
  local repo; repo=$(setup_repo)
  (
    cd "$repo" || exit 1
    # 1. Deleting a tracked .env file (git rm --cached .env) is allowed (--diff-filter=d)
    echo "OLD_SECRET=1" > .env
    git add .env
    git commit -q -m "committed env earlier"
    git rm -q --cached .env
    COMMAND_LINE="git commit -m 'remove tracked .env'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: deleting tracked .env via git rm --cached is allowed" "allow" "$(decision "$repo")"

  (
    cd "$repo" || exit 1
    git commit -q -m "complete removal of .env" || true
    rm -f .env
    # 2. Removing a secret line from a tracked file is allowed (only added lines are flagged)
    printf 'AWS_KEY = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" > app.py
    git add app.py
    git commit -q -m "legacy secret commit"
    echo 'AWS_KEY = os.environ.get("AWS_KEY")' > app.py
    git add app.py
    COMMAND_LINE="git commit -m 'remove hardcoded aws key'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: removing hardcoded secret line is allowed" "allow" "$(decision "$repo")"

  (
    cd "$repo" || exit 1
    git commit -q -m "clean app.py"
    # 3. git commit -am with unstaged secret in tracked file is blocked
    printf 'AWS_KEY = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" >> app.py
    COMMAND_LINE="git commit -am 'bypass attempt with -am'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: git commit -am with modified tracked secret is denied" "deny" "$(decision "$repo")"
  assert_contains "precommit: -am denial mentions AWS Access Key" "$(reason "$repo")" "AWS Access Key"

  (
    cd "$repo" || exit 1
    git checkout -q -- app.py
    # 4. Claude Code stdin JSON payload (AGENT_PLATFORM=claude_code, COMMAND_LINE unset) blocks staged .env
    echo "SECRET=1" > .env
    git add .env
    unset COMMAND_LINE
    AGENT_PLATFORM="claude_code" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" \
      <<< '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"test claude stdin\""}}'
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: Claude Code stdin JSON blocks staged .env" "deny" "$(decision "$repo")"
  assert_contains "precommit: Claude Code JSON envelope mentions .env" "$(reason "$repo")" ".env"

  (
    cd "$repo" || exit 1
    # 5. Non-commit git command containing the word 'commit' in quotes is allowed even with staged .env (stdin & COMMAND_LINE)
    unset COMMAND_LINE
    AGENT_PLATFORM="claude_code" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" \
      <<< '{"tool_name":"Bash","tool_input":{"command":"git log --grep=\"fix commit message\" -n 5"}}'
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: git log --grep='fix commit message' (stdin) does not false-positive trigger precommit gate" "allow" "$(decision "$repo")"

  (
    cd "$repo" || exit 1
    COMMAND_LINE='git log --grep="fix commit message" -n 5' \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: git log --grep='fix commit message' (COMMAND_LINE) is allowed" "allow" "$(decision "$repo")"

  (
    cd "$repo" || exit 1
    # 6. Chained / git -C command detection blocks staged .env
    COMMAND_LINE="git -C \"$repo\" commit -m 'commit via -C'" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" < <(printf '\n\n\n\n\n')
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: git -C <repo> commit blocks staged .env" "deny" "$(decision "$repo")"

  (
    cd "$repo" || exit 1
    git reset -q HEAD .env && rm -f .env
    echo "x = 1" > clean.py
    git add clean.py
    unset COMMAND_LINE
    AGENT_PLATFORM="claude_code" \
      bash "$AGENTS_DIR/security_gate_hook.sh" > "$repo/.hook_stdout" 2> "$repo/.hook_stderr" \
      <<< '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"clean claude commit\""}}'
    echo $? > "$repo/.hook_exit"
  )
  assert_eq "precommit: Claude Code stdin JSON allows clean staged commit" "allow" "$(decision "$repo")"

  cleanup_repo "$repo"
}

# --- run -----------------------------------------------------------------

for t in \
  test_cm_pass_no_findings \
  test_cm_error_blocks_by_default \
  test_cm_error_allow_on_error_true_tags_commit \
  test_cm_advisory_low_severity_does_not_block \
  test_cm_blocking_high_severity_denies_and_prompts_agent \
  test_cm_agent_resolves_finding_subsequent_push_allows \
  test_cm_blocking_retries_exhausted_cm_verify_clean_allows_with_advisory \
  test_cm_blocking_retries_exhausted_cm_verify_exploitable_fails_closed \
  test_cm_blocking_retries_exhausted_cm_verify_crash_fails_closed \
  test_cm_mixed_severity_fixes_blocking_logs_advisory \
  test_semgrep_pass_no_findings \
  test_semgrep_error_blocks_by_default \
  test_semgrep_error_allow_on_error_true \
  test_semgrep_advisory_low_severity_does_not_block \
  test_semgrep_blocking_high_severity_denies_and_prompts_agent \
  test_pipeline_semgrep_to_codemender_flow \
  test_pipeline_deterministic_error_fail_open_proceeds_to_stage2 \
  test_pipeline_tools_missing_passes_smoothly \
  test_skills_frontmatter_valid \
  test_precommit_sensitive_files_blocked \
  test_precommit_api_keys_blocked \
  test_precommit_clean_allowed \
  test_precommit_edge_cases_and_claude_stdin \
; do
  echo "-- $t"
  "$t"
done

echo ""
echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
