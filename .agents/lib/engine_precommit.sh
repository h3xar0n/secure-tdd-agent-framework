#!/bin/bash
# Pre-Commit Security Engine Module (Stage 0: Pre-Commit Secrets & Sensitive File Gate)
# Sourced by security_gate_hook.sh or called directly during PreToolUse on git commit
#
# Inspects files staged for commit (`git diff --cached`) for:
# (a) Sensitive files or state files that should be ignored (.env, .tfstate, *.pem, *.key, etc.)
# (b) Plaintext secrets, private keys, and high-entropy API tokens (AWS, GCP, GitHub, etc.)

is_precommit_command() {
  local cmd="${1:-${COMMAND_LINE:-}}"
  [ -z "$cmd" ] && return 1

  # Strip quoted string contents ("..." and '...') so arguments like
  # git log --grep="fix commit message" or git tag -a v1 -m "tag commit" never false-positive.
  local stripped
  stripped=$(printf '%s' "$cmd" | sed -E "s/\"[^\"]*\"/\"\"/g; s/'[^']*'/''/g")

  local re='(^|[;&|[:space:]]|&&|\|\|)(/[^[:space:]]*/)?git([[:space:]]+(-C|-c|--git-dir|--work-tree)[[:space:]]+[^[:space:]]+|[[:space:]]+--[a-z-]+(=[^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)'
  if [[ "$stripped" =~ $re ]]; then
    return 0
  fi
  return 1
}

run_precommit_gate() {
  local cmd="${1:-${COMMAND_LINE:-}}"

  # Support git -C <path> if specified on the command line
  local git_cmd=(git)
  local git_dir=""
  local re_c_dq='git[[:space:]]+-C[[:space:]]+"([^"]+)"'
  local re_c_sq="git[[:space:]]+-C[[:space:]]+'([^']+)'"
  local re_c_bare='git[[:space:]]+-C[[:space:]]+([^[:space:]]+)'
  if [[ "$cmd" =~ $re_c_dq ]]; then
    git_dir="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ $re_c_sq ]]; then
    git_dir="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ $re_c_bare ]]; then
    git_dir="${BASH_REMATCH[1]}"
  fi
  if [ -n "$git_dir" ] && [ -d "$git_dir" ]; then
    git_cmd=(git -C "$git_dir")
  fi

  # Detect whether -a / -am / -ma / --all is passed to git commit (inspect both staged and unstaged tracked changes)
  local stripped
  stripped=$(printf '%s' "$cmd" | sed -E "s/\"[^\"]*\"/\"\"/g; s/'[^']*'/''/g")
  local after_commit
  after_commit=$(printf '%s' "$stripped" | sed -E 's/^.*git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]+|$)//')

  local include_unstaged=false
  local re_all_flag='(^|[[:space:]])(-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)'
  if [[ "$after_commit" =~ $re_all_flag ]]; then
    include_unstaged=true
  fi

  # 1. Discover files to be committed (excluding deleted files via --diff-filter=d)
  local STAGED_FILES=""
  local STAGED_DIFF=""
  if [ "$include_unstaged" = "true" ]; then
    if "${git_cmd[@]}" rev-parse --verify HEAD >/dev/null 2>&1; then
      STAGED_FILES=$("${git_cmd[@]}" diff HEAD --name-only --diff-filter=d 2>/dev/null || true)
      STAGED_DIFF=$("${git_cmd[@]}" diff HEAD -U0 --diff-filter=d 2>/dev/null || true)
    else
      STAGED_FILES=$( { "${git_cmd[@]}" diff --cached --name-only --diff-filter=d 2>/dev/null; "${git_cmd[@]}" diff --name-only --diff-filter=d 2>/dev/null; } | sort -u || true )
      STAGED_DIFF=$( { "${git_cmd[@]}" diff --cached -U0 --diff-filter=d 2>/dev/null; "${git_cmd[@]}" diff -U0 --diff-filter=d 2>/dev/null; } || true )
    fi
  else
    STAGED_FILES=$("${git_cmd[@]}" diff --cached --name-only --diff-filter=d 2>/dev/null || true)
    STAGED_DIFF=$("${git_cmd[@]}" diff --cached -U0 --diff-filter=d 2>/dev/null || true)
  fi

  if [ -z "$STAGED_FILES" ]; then
    return 0
  fi

  local STAGED_FILES_ARR
  read_lines_into_array STAGED_FILES_ARR "$STAGED_FILES"

  # 2. Check for sensitive filenames/extensions that belong in .gitignore
  local BLOCKED_FILES=()
  for file in "${STAGED_FILES_ARR[@]}"; do
    local base base_lower
    base=$(basename "$file")
    base_lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')

    # Exempt safe documentation template/example files first
    case "$base_lower" in
      *.example|*.sample|*.template|*.dist)
        continue
        ;;
    esac

    case "$base_lower" in
      *.tfstate|*.tfstate.*|*.tfvars|*.tfvars.json)
        BLOCKED_FILES+=("$file (Terraform state/vars file)")
        ;;
      .env|.env.*|*.env|.envrc)
        BLOCKED_FILES+=("$file (Environment file)")
        ;;
      *.pem)
        BLOCKED_FILES+=("$file (PEM certificate/key)")
        ;;
      *.key|*.p12|*.pfx|*.jks)
        BLOCKED_FILES+=("$file (Private key / keystore file)")
        ;;
      id_rsa|id_ed25519|id_ecdsa|id_dsa)
        BLOCKED_FILES+=("$file (SSH private key file)")
        ;;
      *credentials*.json|*service-account*.json|*service_account*.json)
        BLOCKED_FILES+=("$file (Credentials JSON file)")
        ;;
    esac
  done

  if [ ${#BLOCKED_FILES[@]} -gt 0 ]; then
    local file_list
    file_list=$(printf '  - %s\n' "${BLOCKED_FILES[@]}")
    local reason
    reason="Pre-commit security gate blocked commit: sensitive file(s) staged for commit.
These files should be kept in .gitignore and never committed to version control:
$file_list

Remediation:
  1. Unstage the sensitive file(s): git reset HEAD <file>
  2. Add the file pattern to .gitignore: echo '<pattern>' >> .gitignore
  3. Re-run your git commit."

    log_event "BLOCKED" "precommit" "$(jq -n --arg r "$reason" '{reason:$r, check:"sensitive_files"}')"
    notify "BLOCKED" "$reason" "{}"
    deny "$reason"
  fi

  # 3. Check staged content diff for high-entropy secrets and plaintext API keys
  # Only inspect added lines in staged diff (excluding +++ diff headers)
  if [ -z "$STAGED_DIFF" ]; then
    return 0
  fi

  local ADDED_LINES
  ADDED_LINES=$(printf '%s\n' "$STAGED_DIFF" | grep -aE '^\+' | grep -avE '^\+\+\+ ' || true)
  if [ -z "$ADDED_LINES" ]; then
    return 0
  fi

  local SECRET_FINDINGS=()

  # AWS Access Key (AKIA... or ASIA...)
  if printf '%s\n' "$ADDED_LINES" | grep -aqE -- '(AKIA|ASIA)[0-9A-Z]{16}'; then
    SECRET_FINDINGS+=("AWS Access Key (AKIA/ASIA...) detected in staged diff")
  fi

  # Google Cloud API Key (AIza...)
  if printf '%s\n' "$ADDED_LINES" | grep -aqE -- 'AIza[0-9A-Za-z_-]{34,35}'; then
    SECRET_FINDINGS+=("Google API Key (AIza...) detected in staged diff")
  fi

  # GitHub Token (ghp_/gho_/ghu_/ghs_/ghr_ or github_pat_)
  if printf '%s\n' "$ADDED_LINES" | grep -aqE -- '(gh[pousr]_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{22,82})'; then
    SECRET_FINDINGS+=("GitHub Personal Access Token (ghp_/github_pat_) detected in staged diff")
  fi

  # Private Key header (RSA / OPENSSH / EC / DSA / ENCRYPTED / PGP / PRIVATE KEY)
  if printf '%s\n' "$ADDED_LINES" | grep -aqE -- '-----BEGIN ((RSA|EC|DSA|OPENSSH|ENCRYPTED) )?PRIVATE KEY-----|-----BEGIN PGP PRIVATE KEY( BLOCK)?-----'; then
    SECRET_FINDINGS+=("Private Key (BEGIN ... PRIVATE KEY) detected in staged diff")
  fi

  # Generic High-Entropy API Key / Secret Assignment
  if printf '%s\n' "$ADDED_LINES" | grep -aqiE -- '(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*["'\'']?[0-9a-zA-Z_-]{32,}["'\'']?'; then
    SECRET_FINDINGS+=("Generic High-Entropy API Key assignment detected in staged diff")
  fi

  if [ ${#SECRET_FINDINGS[@]} -gt 0 ]; then
    local secret_list
    secret_list=$(printf '  - %s\n' "${SECRET_FINDINGS[@]}")
    local reason
    reason="Pre-commit security gate blocked commit: plaintext secret(s) or private key(s) detected in staged diff.
Detected secret patterns:
$secret_list

Remediation:
  1. Remove hardcoded credentials from source files.
  2. Use environment variables (os.environ, process.env) or Secret Manager.
  3. Re-stage clean files: git add -u
  4. Re-run your git commit."

    log_event "BLOCKED" "precommit" "$(jq -n --arg r "$reason" '{reason:$r, check:"secrets"}')"
    notify "BLOCKED" "$reason" "{}"
    deny "$reason"
  fi

  return 0
}
