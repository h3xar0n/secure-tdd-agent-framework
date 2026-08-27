#!/usr/bin/env python3
"""Automated synchronization script to propagate canonical skills, hooks,

and documentation from secure-tdd-agent-framework (Single Source of Truth)
to downstream Antigravity and Claude Code repositories.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

UPSTREAM_ROOT = Path(__file__).resolve().parent.parent


def get_git_sha(repo_dir: Path) -> str:
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        return res.stdout.strip()
    except Exception:
        return "latest"


def to_kebab_case(name: str) -> str:
    return name.replace("_", "-")


def copy_file_if_changed(src: Path, dst: Path) -> bool:
    if not src.exists():
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        if src.read_bytes() == dst.read_bytes():
            return False
    shutil.copy2(src, dst)
    return True


def copy_tree_sync(src_dir: Path, dst_dir: Path, exclude_patterns=None) -> int:
    if not src_dir.exists():
        return 0
    dst_dir.mkdir(parents=True, exist_ok=True)
    updated_count = 0

    for root, dirs, files in os.walk(src_dir):
        rel_path = Path(root).relative_to(src_dir)
        target_dir = dst_dir / rel_path
        target_dir.mkdir(parents=True, exist_ok=True)

        for file in files:
            src_file = Path(root) / file
            dst_file = target_dir / file
            if copy_file_if_changed(src_file, dst_file):
                updated_count += 1

    return updated_count


def sync_antigravity(target_repo: Path) -> int:
    print(f"\n[1/2] Syncing to Antigravity repository: {target_repo}")
    if not target_repo.exists():
        print(f"  Warning: Target directory '{target_repo}' does not exist. Skipping.")
        return 0

    changes = 0

    # 1. Clean obsolete separate hook files if present
    for obsolete in [
        target_repo / ".agents" / "security_gate_hook_semgrep.sh",
        target_repo / ".agents" / "hooks_semgrep.json",
    ]:
        if obsolete.exists():
            obsolete.unlink()
            changes += 1

    # 2. Sync .agents directory
    changes += copy_tree_sync(UPSTREAM_ROOT / ".agents", target_repo / ".agents")

    # 3. Sync shared docs & license
    for doc in ["AGENTS.md", "CONTEXT.md", "LICENSE"]:
        if copy_file_if_changed(UPSTREAM_ROOT / doc, target_repo / doc):
            changes += 1

    # 4. Generate dedicated Antigravity README.md
    antigravity_readme = """# Secure TDD for Antigravity

> **Secure Test-Driven Development (Secure TDD) agent skills, rules, and pre-push hooks for Antigravity AI coding agents.**

> [!CAUTION]
> **Use at Your Own Risk**: This repository is a demonstration of an approach and is not an officially supported product or framework. AI coding agents generate and execute code that may be unstable or perform unexpected actions. Run agentic workflows only in isolated development environments and never on systems with access to production credentials, sensitive customer data, or internal networks.

> [!IMPORTANT]
> **Responsible Use & Manual Verification**: AI models are non-deterministic and can generate incorrect patches or hallucinate findings. All automated code changes and findings must be manually reviewed and verified by a developer or security practitioner before deployment. Do not mass-file unverified, AI-generated reports to open-source maintainers. You are expected to inspect, adapt, and take full responsibility for using this code.

This repository is the dedicated Antigravity distribution of the **[Secure TDD Agent Framework](https://github.com/h3xar0n/secure-tdd-agent-framework)**.

## What's Included

- `.agents/rules/secure_tdd_workflow.md`: Always-on 4-phase workflow rule (`PLAN` -> `RED` -> `GREEN` -> `REFACTOR`).
- `.agents/skills/`: Specialized agent skills for threat modeling, security test writing, defensive coding, local refactor scanning, and skill evolution.
- `.agents/hooks.json` & `.agents/security_gate_hook.sh`: Local pre-push hook enforcing test-first verification before code reaches remote repositories.
- `CONTEXT.md`: Living repository context, trust boundaries, and approved helpers.
- `AGENTS.md`: Universal agent reference guide.

## Getting Started

1. Open this repository or copy `.agents/`, `AGENTS.md`, and `CONTEXT.md` into your Antigravity project root.
2. The agent automatically discovers the workflow rules and skills.
3. Test the local pre-push hook:
   ```bash
   bash .agents/tests/run_tests.sh
   ```

## Optional Scanner Engines & Installation

The pre-push security gate hook supports modular scanning engines. Both scanners are **optional**:
- The hook checks which tools are available on your system `PATH`.
- If `semgrep` is not installed, the pipeline skips Stage 1 and proceeds directly to Stage 2 (`cm`).
- If neither scanner is installed, the hook logs an informational notice and allows the push to proceed normally.
- The hook engine is designed to be extended with additional scanners (such as Wiz Code for Stage 1) down the road.

### 1. Semgrep (Stage 1: Open-Source Deterministic AST Scanner)
```bash
# Via Homebrew:
brew install semgrep

# Or via pip:
pip install semgrep
```

### 2. CodeMender CLI (`cm` - Stage 2: Semantic Analysis & Remediation)
```bash
# Authenticate with Google Cloud:
gcloud auth application-default login

# Download and install binary (macOS ARM64 example):
gcloud artifacts generic download \
    --project=cmoc-prod \
    --location=us \
    --repository=codemender-cli-production \
    --package=cm \
    --version=stable \
    --name=cm-darwin-arm64.zip \
    --destination=./

unzip cm-*.zip && chmod +x cm && sudo mv cm /usr/local/bin/cm
cm init && cm init --verify
```

## Upstream Canonical Framework

All skills, rules, and threat models are maintained in the canonical upstream repository:  
🔗 **[h3xar0n/secure-tdd-agent-framework](https://github.com/h3xar0n/secure-tdd-agent-framework)**

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
"""
    ag_readme_path = target_repo / "README.md"
    if not ag_readme_path.exists() or ag_readme_path.read_text(encoding="utf-8") != antigravity_readme:
        ag_readme_path.write_text(antigravity_readme, encoding="utf-8")
        changes += 1

    print(f"  -> Antigravity sync complete ({changes} files updated).")
    return changes


def sync_claude_code(target_repo: Path) -> int:
    print(f"\n[2/2] Syncing to Claude Code repository: {target_repo}")
    if not target_repo.exists():
        print(f"  Warning: Target directory '{target_repo}' does not exist. Skipping.")
        return 0

    changes = 0

    # 1. Clean obsolete separate settings/hook files
    for obsolete in [
        target_repo / ".claude" / "settings.semgrep.json",
        target_repo / ".claude" / "hooks" / "security_gate_hook_semgrep.sh",
    ]:
        if obsolete.exists():
            obsolete.unlink()
            changes += 1

    # 2. Sync shared docs & license
    for doc in ["CLAUDE.md", "CONTEXT.md", "LICENSE"]:
        if copy_file_if_changed(UPSTREAM_ROOT / doc, target_repo / doc):
            changes += 1

    # 3. Generate dedicated Claude Code README.md
    claude_readme = """# Secure TDD for Claude Code

> **Secure Test-Driven Development (Secure TDD) workflow instructions, skills, and pre-tool hooks for Claude Code CLI agents.**

> [!CAUTION]
> **Use at Your Own Risk**: This repository is a demonstration of an approach and is not an officially supported product or framework. AI coding agents generate and execute code that may be unstable or perform unexpected actions. Run agentic workflows only in isolated development environments and never on systems with access to production credentials, sensitive customer data, or internal networks.

> [!IMPORTANT]
> **Responsible Use & Manual Verification**: AI models are non-deterministic and can generate incorrect patches or hallucinate findings. All automated code changes and findings must be manually reviewed and verified by a developer or security practitioner before deployment. Do not mass-file unverified, AI-generated reports to open-source maintainers. You are expected to inspect, adapt, and take full responsibility for using this code.

This repository is the dedicated Claude Code distribution of the **[Secure TDD Agent Framework](https://github.com/h3xar0n/secure-tdd-agent-framework)**.

## What's Included

- `CLAUDE.md`: System prompt instructions loaded on Claude Code session start to enforce the 4-phase inner loop (`PLAN` -> `RED` -> `GREEN` -> `REFACTOR`).
- `.claude/skills/`: Specialized kebab-case agent skills for threat modeling, security test writing, defensive coding, and refactor scanning.
- `.claude/settings.json` & `.claude/hooks/security_gate_hook.sh`: PreToolUse bash hook enforcing test-first verification before `git push` runs.
- `CONTEXT.md`: Living repository context, trust boundaries, and approved helpers.

## Getting Started

1. Open this repository in your terminal and launch Claude Code:
   ```bash
   claude
   ```
2. Claude Code automatically ingests `CLAUDE.md` and discovers skills in `.claude/skills/`.
3. Test the local pre-tool hook:
   ```bash
   bash .claude/hooks/tests/run_tests.sh
   ```

## Optional Scanner Engines & Installation

The pre-push security gate hook supports modular scanning engines. Both scanners are **optional**:
- The hook checks which tools are available on your system `PATH`.
- If `semgrep` is not installed, the pipeline skips Stage 1 and proceeds directly to Stage 2 (`cm`).
- If neither scanner is installed, the hook logs an informational notice and allows the push to proceed normally.
- The hook engine is designed to be extended with additional scanners (such as Wiz Code for Stage 1) down the road.

### 1. Semgrep (Stage 1: Open-Source Deterministic AST Scanner)
```bash
# Via Homebrew:
brew install semgrep

# Or via pip:
pip install semgrep
```

### 2. CodeMender CLI (`cm` - Stage 2: Semantic Analysis & Remediation)
```bash
# Authenticate with Google Cloud:
gcloud auth application-default login

# Download and install binary (macOS ARM64 example):
gcloud artifacts generic download \
    --project=cmoc-prod \
    --location=us \
    --repository=codemender-cli-production \
    --package=cm \
    --version=stable \
    --name=cm-darwin-arm64.zip \
    --destination=./

unzip cm-*.zip && chmod +x cm && sudo mv cm /usr/local/bin/cm
cm init && cm init --verify
```

## Upstream Canonical Framework

All skills, rules, and threat models are maintained in the canonical upstream repository:  
🔗 **[h3xar0n/secure-tdd-agent-framework](https://github.com/h3xar0n/secure-tdd-agent-framework)**

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
"""
    cl_readme_path = target_repo / "README.md"
    if not cl_readme_path.exists() or cl_readme_path.read_text(encoding="utf-8") != claude_readme:
        cl_readme_path.write_text(claude_readme, encoding="utf-8")
        changes += 1

    # 4. Sync modular hook & libraries
    claude_hooks_dst = target_repo / ".claude" / "hooks"
    if copy_file_if_changed(UPSTREAM_ROOT / ".agents" / "security_gate_hook.sh", claude_hooks_dst / "security_gate_hook.sh"):
        changes += 1

    changes += copy_tree_sync(UPSTREAM_ROOT / ".agents" / "lib", claude_hooks_dst / "lib")
    changes += copy_tree_sync(UPSTREAM_ROOT / ".agents" / "tests", claude_hooks_dst / "tests")

    # 4. Sync Claude Code settings.json
    import json
    settings_json = target_repo / ".claude" / "settings.json"
    settings_content = json.dumps(
        {
            "permissions": {
                "allow": ["Bash(cm:*)", "Bash(semgrep:*)"]
            },
            "hooks": {
                "PreToolUse": [
                    {
                        "matcher": "Bash",
                        "hooks": [
                            {
                                "type": "command",
                                "if": "Bash(git push*)",
                                "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/security_gate_hook.sh",
                                "timeout": 120,
                            }
                        ],
                    }
                ]
            },
        },
        indent=2,
    ) + "\n"
    if not settings_json.exists() or settings_json.read_text(encoding="utf-8") != settings_content:
        settings_json.parent.mkdir(parents=True, exist_ok=True)
        settings_json.write_text(settings_content, encoding="utf-8")
        changes += 1

    # 5. Sync skills (transforming to kebab-case)
    upstream_skills = UPSTREAM_ROOT / ".agents" / "skills"
    claude_skills_dst = target_repo / ".claude" / "skills"

    if upstream_skills.exists():
        for skill_folder in upstream_skills.iterdir():
            if not skill_folder.is_dir():
                continue
            kebab_name = to_kebab_case(skill_folder.name)
            target_skill_dir = claude_skills_dst / kebab_name
            target_skill_dir.mkdir(parents=True, exist_ok=True)

            # Copy skill contents
            for root, dirs, files in os.walk(skill_folder):
                rel = Path(root).relative_to(skill_folder)
                dest_sub = target_skill_dir / rel
                dest_sub.mkdir(parents=True, exist_ok=True)
                for f in files:
                    s_file = Path(root) / f
                    d_file = dest_sub / f
                    if f == "SKILL.md":
                        # Adjust frontmatter name to kebab-case
                        content = s_file.read_text(encoding="utf-8")
                        content = re.sub(r"^name:\s*[\w-]+", f"name: {kebab_name}", content, flags=re.MULTILINE)
                        if not d_file.exists() or d_file.read_text(encoding="utf-8") != content:
                            d_file.write_text(content, encoding="utf-8")
                            changes += 1
                    else:
                        if copy_file_if_changed(s_file, d_file):
                            changes += 1

    print(f"  -> Claude Code sync complete ({changes} files updated).")
    return changes


def git_commit_and_push(repo_dir: Path, upstream_sha: str, auto_commit: bool, auto_push: bool):
    if not (repo_dir / ".git").exists():
        return

    status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
    )
    if not status.stdout.strip():
        print(f"  [git] No changes to commit in {repo_dir.name}.")
        return

    print(f"  [git] Detected changes in {repo_dir.name}:")
    for line in status.stdout.strip().splitlines()[:5]:
        print(f"    {line}")

    if auto_commit:
        subprocess.run(["git", "add", "-A"], cwd=repo_dir, check=True)
        commit_msg = f"sync: Update skills and hooks from upstream ({upstream_sha})"
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=repo_dir, check=True)
        print(f"  [git] Created commit in {repo_dir.name}: '{commit_msg}'")

        if auto_push:
            print(f"  [git] Pushing {repo_dir.name} to remote...")
            subprocess.run(["git", "push"], cwd=repo_dir, check=True)


def main():
    parser = argparse.ArgumentParser(description="Synchronize skills and hooks to downstream repos.")
    parser.add_argument(
        "--antigravity-dir",
        type=Path,
        default=Path(os.getenv("ANTIGRAVITY_REPO_DIR", UPSTREAM_ROOT.parent / "secure-tdd-antigravity")),
        help="Path to the Antigravity downstream repository.",
    )
    parser.add_argument(
        "--claude-dir",
        type=Path,
        default=Path(os.getenv("CLAUDE_CODE_REPO_DIR", UPSTREAM_ROOT.parent / "secure-tdd-claude-code")),
        help="Path to the Claude Code downstream repository.",
    )
    parser.add_argument(
        "--commit",
        action="store_true",
        help="Automatically commit changes in downstream repositories.",
    )
    parser.add_argument(
        "--push",
        action="store_true",
        help="Automatically push downstream repository commits to remote.",
    )

    args = parser.parse_args()
    upstream_sha = get_git_sha(UPSTREAM_ROOT)

    print("=========================================================")
    print(f" Secure TDD Downstream Sync (Upstream SHA: {upstream_sha})")
    print("=========================================================")

    ag_changes = sync_antigravity(args.antigravity_dir)
    cl_changes = sync_claude_code(args.claude_dir)

    if args.commit:
        if ag_changes > 0 or (args.antigravity_dir / ".git").exists():
            git_commit_and_push(args.antigravity_dir, upstream_sha, args.commit, args.push)
        if cl_changes > 0 or (args.claude_dir / ".git").exists():
            git_commit_and_push(args.claude_dir, upstream_sha, args.commit, args.push)

    print("\nAll downstream repositories are up to date!")


if __name__ == "__main__":
    main()
