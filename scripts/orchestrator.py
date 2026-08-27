#!/usr/bin/env python3
"""
SharedTasks Agentic Pipeline Orchestrator
==========================================
Reads a GitHub issue and orchestrates Claude Code CLI sub-agents to:
1. Plan the implementation
2. Generate Flutter feature code
3. Write tests
4. Review code (up to 3 retries)
5. Commit and open a PR

All AI calls go through Claude Code CLI (claude "...") — covered by your
existing Claude Pro plan. No separate API key or billing needed.

Usage:
    python scripts/orchestrator.py --issue 15
    python scripts/orchestrator.py --issue https://github.com/madhusangita123/shared-tasks/issues/15

Requirements:
    pip install PyGithub python-dotenv

    Why each library:
    - PyGithub:       GitHub API client — reads issues, opens PRs, posts comments
    - python-dotenv:  Reads .env file — loads tokens without hardcoding them in code

    NOT needed (removed):
    - anthropic:      Was for direct API calls — replaced by Claude Code CLI

Environment variables (.env):
    GITHUB_TOKEN=your_token_here      ← get from github.com/settings/tokens (repo scope)
    GITHUB_REPO=madhusangita123/shared-tasks
"""

# Lets us write `int | None` type hints below even though this runs on
# Python 3.9 (that union syntax is 3.10+ without this import).
from __future__ import annotations

# ── Standard library imports (built into Python, no install needed) ────────────
import argparse    # parses command line arguments like --issue 15
import os          # reads environment variables like os.getenv("GITHUB_TOKEN")
import re          # regex — used to extract branch name and feature from the plan
import signal      # used to kill a whole process group when a command times out
import subprocess  # runs shell commands like flutter analyze, git commit, claude "..."
import sys         # exits the script with sys.exit() on errors
import json        # parses JSON responses from the Critic agent
from pathlib import Path  # handles file paths cleanly across Mac/Linux

# ── Third party imports (need: pip install PyGithub python-dotenv) ────────────
from dotenv import load_dotenv  # reads .env file into environment variables
from github import Github, Auth  # PyGithub — interacts with GitHub API

# ── Configuration ──────────────────────────────────────────────────────────────

# Load .env file first so all os.getenv() calls below can read the tokens
load_dotenv()

# Read tokens from .env — never hardcode these in the script
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_REPO = os.getenv("GITHUB_REPO", "madhusangita123/shared-tasks")

# How many times the Critic agent retries before asking for human help
MAX_CRITIC_RETRIES = 3

# Timeouts for claude CLI subprocess calls, in seconds.
# Without a timeout, a hung or runaway sub-agent (e.g. one that starts a
# long-running command like `flutter run`) blocks the pipeline forever.
CLAUDE_READONLY_TIMEOUT = 600    # 10 min — planning/review/text-only agents
CLAUDE_CODEGEN_TIMEOUT = 1800    # 30 min — agents that write files and run flutter/dart

# Tools allowed for agents that should only read files and return text
# (Planner, Critic, PR Writer). This is an ALLOWLIST, not a denylist —
# denying just Bash/Edit/Write wasn't enough in testing, because these
# agents also have Agent/Skill tools that can spawn their own full-
# permission subprocesses (that's how the Planner agent ended up running
# `flutter run` in the first place: not via Bash directly, but via a
# spawned sub-agent/skill invocation that Bash restrictions don't reach).
# An allowlist is closed by default, so nothing pulls off, including
# tools we haven't thought of.
READONLY_ALLOWED_TOOLS = "Read,Grep,Glob"

# Project root is one level up from scripts/ folder
# Path(__file__) = scripts/orchestrator.py
# .parent = scripts/
# .parent.parent = project root
PROJECT_ROOT = Path(__file__).parent.parent

# ── Terminal colours ───────────────────────────────────────────────────────────
# ANSI escape codes — make terminal output easier to read

GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
BLUE   = "\033[94m"
BOLD   = "\033[1m"
RESET  = "\033[0m"   # resets colour back to terminal default

def print_header(text: str):
    """Prints a bold blue section header — used for checkpoints and pipeline steps"""
    print(f"\n{BOLD}{BLUE}{'='*60}{RESET}")
    print(f"{BOLD}{BLUE}  {text}{RESET}")
    print(f"{BOLD}{BLUE}{'='*60}{RESET}\n")

def print_success(text: str):
    """Green tick — something completed successfully"""
    print(f"{GREEN}✓ {text}{RESET}")

def print_warning(text: str):
    """Yellow warning — something needs attention but is not fatal"""
    print(f"{YELLOW}⚠ {text}{RESET}")

def print_error(text: str):
    """Red cross — something failed"""
    print(f"{RED}✗ {text}{RESET}")

def print_info(text: str):
    """Blue arrow — informational status update"""
    print(f"{BLUE}→ {text}{RESET}")

# ── Checkpoint ─────────────────────────────────────────────────────────────────

def checkpoint(title: str, content: str, instructions: str = "Review the above and type 'y' to proceed, or describe changes needed:") -> str:
    """
    The heart of the human-in-the-loop design.

    Pauses the pipeline, shows the content to you, and waits for your decision:
    - Type 'y'         → approved, pipeline continues
    - Type 'q'         → quit, pipeline stops cleanly
    - Type anything else → treated as feedback, pipeline uses it to fix and retry

    Returns 'y' if approved, or your feedback string if changes needed.
    """
    print_header(f"CHECKPOINT: {title}")
    print(content)
    print(f"\n{YELLOW}{instructions}{RESET}")

    while True:
        response = input(f"\n{BOLD}> {RESET}").strip().lower()
        if response == 'y':
            print_success("Approved. Continuing...\n")
            return 'y'
        elif response == 'q':
            print_warning("Orchestrator stopped by user.")
            sys.exit(0)
        elif response:
            print_info(f"Feedback received: {response}")
            return response
        else:
            print_warning("Please type 'y' to approve, 'q' to quit, or describe changes needed.")

# ── File helpers ───────────────────────────────────────────────────────────────

def read_file(path: str) -> str:
    """
    Read a file relative to the project root.
    Used to load CLAUDE.md, PRD, ARCHITECTURE into agent prompts.
    Returns empty string if file doesn't exist (with a warning).
    """
    full_path = PROJECT_ROOT / path
    if not full_path.exists():
        print_warning(f"File not found: {path}")
        return ""
    return full_path.read_text(encoding="utf-8")

def list_feature_files(feature: str) -> list[str]:
    """
    List all Dart files in a feature folder.
    e.g. list_feature_files("auth") returns all .dart files in lib/features/auth/
    Used by Critic and PR Writer agents to know what to review.
    """
    feature_path = PROJECT_ROOT / "lib" / "features" / feature
    if not feature_path.exists():
        return []
    return [str(p.relative_to(PROJECT_ROOT)) for p in feature_path.rglob("*.dart")]

def list_test_files(feature: str) -> list[str]:
    """
    List all test files for a feature (both unit and widget tests).
    Used by Critic and PR Writer agents.
    """
    paths = []
    for test_type in ["unit", "widget"]:
        test_path = PROJECT_ROOT / "test" / test_type / "features" / feature
        if test_path.exists():
            paths.extend([str(p.relative_to(PROJECT_ROOT)) for p in test_path.rglob("*.dart")])
    return paths

# ── Shell commands ─────────────────────────────────────────────────────────────

def run_command(command: str, capture: bool = True, timeout: int | None = None) -> tuple[int, str]:
    """
    Run any shell command in the project root directory.
    Returns (exit_code, output_string).
    exit_code == 0 means success, anything else is an error.
    Used to run flutter, git, dart, and claude commands.

    timeout: max seconds to wait. If exceeded, the ENTIRE process group is
    killed (not just the top-level shell) and this returns a non-zero exit
    code with a clear message instead of hanging the whole pipeline
    forever. This matters because `claude --print` can itself spawn
    children (e.g. it once ran a stuck `flutter run`, which never exits on
    its own) — killing only the shell would leave those orphaned and still
    running.
    """
    process = subprocess.Popen(
        command,
        shell=True,
        cwd=PROJECT_ROOT,           # always run from project root
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        text=True,
        start_new_session=True,     # own process group so we can kill the whole tree
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        output = (stdout or "") + (stderr or "")
        return process.returncode, output
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except ProcessLookupError:
            pass  # already exited between the timeout firing and us killing it
        stdout, stderr = process.communicate()  # reap the process, collect partial output
        output = (stdout or "") + (stderr or "")
        return 1, f"{output}\n[orchestrator] Command timed out after {timeout}s and was killed: {command}"

def call_claude_code(prompt: str, read_only: bool = False, timeout: int | None = None) -> str:
    """
    Call Claude Code CLI with a prompt and return the output.

    This is how ALL AI work happens in the orchestrator — by calling
    the Claude Code CLI (claude "...") as a subprocess. This means:
    - No separate API key needed
    - No extra billing — covered by your Claude Pro plan
    - Claude Code reads your project files automatically

    The prompt is passed as a command line argument to claude.
    Claude Code runs in the project root so it can access all files.

    read_only: set True for agents that should only read files and return
    text (Planner, Critic, PR Writer) — blocks Bash/Edit/Write/NotebookEdit
    so the sub-agent can't do things like run `flutter run`, which is a
    long-running interactive command that would otherwise hang forever.
    Leave False for agents that must write files or run build/test
    commands (Coder, Test Writer).

    timeout: max seconds to wait before giving up. Defaults to
    CLAUDE_READONLY_TIMEOUT for read_only calls, CLAUDE_CODEGEN_TIMEOUT
    otherwise.
    """
    print_info("Calling Claude Code CLI...")
    if timeout is None:
        timeout = CLAUDE_READONLY_TIMEOUT if read_only else CLAUDE_CODEGEN_TIMEOUT

    # NOTE: must use --allowedTools=<value> (equals form). The
    # space-separated form (--allowedTools "value") gets parsed as a
    # multi-value flag that keeps consuming argv — including the prompt
    # string that follows — leaving no prompt for claude to run on.
    tools_flag = f'--allowedTools="{READONLY_ALLOWED_TOOLS}"' if read_only else ""
    code, output = run_command(f'claude -p --dangerously-skip-permissions {tools_flag} "{prompt}"', timeout=timeout)
    if code != 0:
        print_warning(f"Claude Code returned non-zero exit code: {code}")
    return output

def run_flutter_analyze() -> tuple[bool, str]:
    """
    Run 'flutter analyze' to check for Dart errors and warnings.
    Returns (passed, output).
    Must pass clean before the orchestrator proceeds past Checkpoint 2.
    """
    print_info("Running flutter analyze...")
    code, output = run_command("flutter analyze")
    passed = code == 0
    if passed:
        print_success("flutter analyze passed clean")
    else:
        print_error("flutter analyze found issues")
    return passed, output

def run_flutter_test() -> tuple[bool, str]:
    """
    Run 'flutter test' to execute all tests.
    Returns (passed, output).
    Tests run against Firebase Emulator — make sure it's running first.
    """
    print_info("Running flutter test...")
    code, output = run_command("flutter test")
    passed = code == 0
    if passed:
        print_success("flutter test passed")
    else:
        print_error("flutter test failed")
    return passed, output

def git_checkout_branch(branch: str) -> bool:
    """
    Create a new git branch and switch to it.
    If branch already exists, just switch to it.
    Format: feat/us-XX-short-description
    """
    code, output = run_command(f"git checkout -b {branch}")
    if code != 0:
        # Branch might already exist — try switching to it instead
        code, output = run_command(f"git checkout {branch}")
    return code == 0

def git_commit(message: str) -> tuple[bool, str]:
    """
    Stage ALL changes (git add .) and commit with the given message.
    Only called after CHECKPOINT 6 — you explicitly approved the commit.
    Uses conventional commit format: feat(feature): description
    """
    run_command("git add .")
    code, output = run_command(f'git commit -m "{message}"')
    return code == 0, output

def git_push(branch: str) -> bool:
    """Push the feature branch to GitHub origin so a PR can be opened."""
    code, _ = run_command(f"git push origin {branch}")
    return code == 0

def get_last_commit_hash() -> str:
    """Get the short hash of the last commit (e.g. 'a3f2c1d')."""
    _, output = run_command("git rev-parse --short HEAD")
    return output.strip()

# ── GitHub helpers ─────────────────────────────────────────────────────────────

def parse_issue_number(issue_input: str) -> int:
    """
    Accepts an issue number in multiple formats:
    - Plain number:  15
    - String:        "15"
    - GitHub URL:    "https://github.com/owner/repo/issues/15"

    Always returns an integer issue number.
    """
    if isinstance(issue_input, int):
        return issue_input

    # URL format: https://github.com/owner/repo/issues/15
    url_match = re.search(r'/issues/(\d+)', str(issue_input))
    if url_match:
        return int(url_match.group(1))

    # Plain number as string
    if str(issue_input).isdigit():
        return int(issue_input)

    raise ValueError(f"Could not parse issue number from: {issue_input}")

def fetch_github_issue(issue_number: int) -> dict:
    """
    Fetch issue details from GitHub using PyGithub.
    Returns a dict with number, title, body, and labels.
    The body contains acceptance criteria and technical notes
    that the Planner and Coder agents use.
    """
    print_info(f"Fetching GitHub issue #{issue_number}...")
    g = Github(auth=Auth.Token(GITHUB_TOKEN))
    repo = g.get_repo(GITHUB_REPO)
    issue = repo.get_issue(issue_number)

    return {
        "number": issue.number,
        "title": issue.title,
        "body": issue.body or "",
        "labels": [label.name for label in issue.labels],
    }

def open_pull_request(branch: str, title: str, body: str, issue_number: int) -> str:
    """
    Open a PR on GitHub using PyGithub (no MCP needed).
    - Creates PR from feature branch → main
    - Posts a comment on the issue linking back to the PR
    Returns the PR URL.
    """
    print_info("Opening pull request on GitHub...")
    g = Github(auth=Auth.Token(GITHUB_TOKEN))
    repo = g.get_repo(GITHUB_REPO)

    pr = repo.create_pull(
        title=title,
        body=body,
        head=branch,    # feature branch
        base="main",    # merge target
    )

    # Post comment on the issue so it shows as linked in GitHub
    issue = repo.get_issue(issue_number)
    issue.create_comment(f"Pull request opened: {pr.html_url}")

    return pr.html_url

# ── Sub-agents ─────────────────────────────────────────────────────────────────
# Each function below is a sub-agent in the pipeline.
# They all work the same way: build a prompt → call Claude Code CLI → return output.
# Claude Code reads your project files automatically so we don't need to
# pass file contents in the prompt — just tell it what to read.

def run_planner_agent(issue: dict, feedback: str = "") -> str:
    """
    SUB-AGENT 1: Planner
    Creates a detailed implementation plan for the issue.
    Claude Code reads CLAUDE.md, PRD, ARCHITECTURE automatically.
    Returns a markdown plan string shown to you at Checkpoint 1.
    """
    print_info("Running Planner sub-agent...")

    feedback_section = f"\n\nIncorporate this feedback into the plan:\n{feedback}" if feedback else ""

    prompt = f"""Read CLAUDE.md, docs/PRD.md and docs/ARCHITECTURE.md.

Create a detailed implementation plan for GitHub Issue #{issue['number']}: {issue['title']}

Issue details:
{issue['body']}
{feedback_section}

Your plan must include:
1. Feature name and folder (lib/features/[feature]/)
2. Complete list of files to create with one-line description of each
3. Git branch name (format: feat/us-{issue['number']}-short-description)
4. Build order — which file to create first, second, etc.
5. Key patterns from ARCHITECTURE.md to use
6. Acceptance criteria from the issue mapped to specific files
7. Test files to create in test/unit/ and test/widget/

Be specific. Every file listed must have a clear purpose.
Format as clean markdown."""

    # read_only: this agent only reads docs and returns a text plan — it
    # must never be able to run commands like `flutter run`.
    return call_claude_code(prompt, read_only=True)

def run_coder_agent(issue: dict, plan: str, feedback: str = "") -> str:
    """
    SUB-AGENT 2: Coder
    Generates Flutter feature files based on the plan.
    Claude Code writes files directly to your project.
    Returns a summary of what was created.
    """
    print_info("Running Coder sub-agent...")

    feedback_section = f"\n\nAddress this feedback:\n{feedback}" if feedback else ""

    prompt = f"""Read CLAUDE.md, docs/PRD.md and docs/ARCHITECTURE.md first.

Implement GitHub Issue #{issue['number']}: {issue['title']}

Follow this plan exactly:
{plan}
{feedback_section}

Rules:
1. Follow feature-first folder structure — all files in lib/features/[feature]/
2. Build in the order from the plan
3. Use Result<T> sealed class for all repository return types — never throw
4. Use manual Riverpod providers — no @riverpod annotations
5. Domain entities: freezed, zero Flutter/Firebase imports
6. No hardcoded Firestore strings — use FirestoreConstants
7. No raw Future in widgets — use AsyncValue
8. No print() statements
9. Run: dart run build_runner build --delete-conflicting-outputs (after any freezed model)
10. Run: flutter analyze — fix ALL issues before finishing
11. Create empty test file stubs in test/ for every implementation file
12. Do NOT commit — the orchestrator handles commits at Checkpoint 6

When complete, list every file created with its path."""

    return call_claude_code(prompt)

def run_test_writer_agent(issue: dict, feature: str) -> str:
    """
    SUB-AGENT 3: Test Writer
    Writes comprehensive unit and widget tests for the generated code.
    Claude Code reads the feature files and writes matching test files.
    Returns a test summary with pass/fail counts.
    """
    print_info("Running Test Writer sub-agent...")

    feature_files = list_feature_files(feature)
    files_str = "\n".join(feature_files) if feature_files else "No files found yet"

    prompt = f"""Read CLAUDE.md and docs/ARCHITECTURE.md.

Write comprehensive tests for the feature built for Issue #{issue['number']}: {issue['title']}

Feature files to test:
{files_str}

Rules:
1. Unit tests → test/unit/features/{feature}/
2. Widget tests → test/widget/features/{feature}/
3. Use mocktail to mock all dependencies — never use real Firebase or Google Sign-In
4. Test every repository method — success AND failure cases
5. Verify Result<T> returns explicitly in every test
6. Widget tests must cover: loading state, error state, success state
7. Run: flutter test — fix any failures before finishing
8. Do NOT commit

Report at the end: X tests written, Y passing, Z failing."""

    return call_claude_code(prompt)

def run_critic_agent(issue: dict, feature: str, retry_count: int) -> dict:
    """
    SUB-AGENT 4: Critic
    Reviews the feature code and tests together.
    Asks Claude Code to respond in JSON so the orchestrator can
    parse the result and decide whether to retry or proceed.
    Returns a dict with status, issues list, and summary.
    """
    print_info(f"Running Critic sub-agent (attempt {retry_count + 1}/{MAX_CRITIC_RETRIES})...")

    feature_files = list_feature_files(feature)
    test_files = list_test_files(feature)
    all_files = "\n".join(feature_files + test_files)

    prompt = f"""Read CLAUDE.md and docs/ARCHITECTURE.md.

Review this feature implementation for Issue #{issue['number']}: {issue['title']}

Files to review:
{all_files}

Check every file against these rules:
- Domain entities have zero Flutter/Firebase imports
- Repository interfaces use abstract interface class
- All repository methods return Result<T> — no throwing
- Datasources contain ALL Firestore/Firebase calls — nothing leaks into other layers
- Providers are manual — no @riverpod annotations
- Screens never call Firestore directly
- No hardcoded Firestore strings — all use FirestoreConstants
- No raw Future in widgets — AsyncValue used
- No print() statements
- Tests cover success AND failure cases for every repository method
- No real Firebase or Google Sign-In used in tests

Respond ONLY with a JSON object in this exact format, no other text:
{{
  "status": "clean",
  "summary": "one sentence summary",
  "issues": [],
  "suggestions": []
}}

Or if issues found:
{{
  "status": "issues_found",
  "summary": "one sentence summary",
  "issues": [
    {{
      "severity": "critical",
      "file": "lib/features/auth/...",
      "description": "what is wrong",
      "fix": "how to fix it"
    }}
  ],
  "suggestions": ["non-blocking suggestions"]
}}

Only include critical and warning severity in issues array.
Suggestions are informational only and do not block the pipeline."""

    # read_only: this agent only reviews files and returns JSON — it
    # should never modify code or run commands itself.
    output = call_claude_code(prompt, read_only=True)

    # Parse JSON response — Claude Code should return only JSON
    try:
        # Strip any markdown code fences if present
        clean = re.sub(r'```json|```', '', output).strip()
        # Find the JSON object in the output
        json_match = re.search(r'\{.*\}', clean, re.DOTALL)
        if json_match:
            return json.loads(json_match.group(0))
        else:
            raise ValueError("No JSON found in response")
    except (json.JSONDecodeError, ValueError) as e:
        print_warning(f"Critic returned invalid JSON — treating as issues found. Error: {e}")
        return {
            "status": "issues_found",
            "summary": "Could not parse critic response — review manually",
            "issues": [{"severity": "warning", "description": output[:500], "fix": "Review manually"}],
            "suggestions": []
        }

def run_pr_writer_agent(issue: dict, feature: str, branch: str, review_summary: str) -> str:
    """
    SUB-AGENT 5: PR Writer
    Writes a rich, specific PR description.
    Claude Code reads the issue and files changed to write the description.
    Returns the PR body as markdown.
    """
    print_info("Running PR Writer sub-agent...")

    feature_files = list_feature_files(feature)
    test_files = list_test_files(feature)

    prompt = f"""Read docs/PRD.md.

Write a pull request description for Issue #{issue['number']}: {issue['title']}

Branch: {branch} → main
Code review summary: {review_summary}

Implementation files:
{chr(10).join(feature_files)}

Test files:
{chr(10).join(test_files)}

Issue body for reference:
{issue['body']}

Use this exact structure:

## Summary
[2-3 sentences: what this PR implements and why]

## Changes
[Bullet list: every file with one line explaining what it does]

## How to test
[Step by step — exact steps, not vague "run the app"]

## Acceptance criteria
[Copy from issue — mark every item as done with ✅]

## Notes
[Any deviations from original scope, known limitations, follow-up needed]

## Closes
Closes #{issue['number']}

Rules: be specific, keep under 400 words, no vague descriptions.
Respond with ONLY the PR markdown body."""

    # read_only: this agent only reads files and returns a markdown
    # description — it must never modify code or run commands.
    return call_claude_code(prompt, read_only=True)

# ── Main Orchestrator ──────────────────────────────────────────────────────────

def main():
    # Parse command line arguments
    # Usage: python scripts/orchestrator.py --issue 15
    parser = argparse.ArgumentParser(
        description="SharedTasks Agentic Pipeline Orchestrator",
        epilog="Example: python scripts/orchestrator.py --issue 15"
    )
    parser.add_argument(
        "--issue",
        required=True,
        help="GitHub issue number (15) or full URL"
    )
    args = parser.parse_args()

    print_header("SharedTasks Orchestrator")
    print_info(f"Issue: {args.issue}")
    print_info(f"Project: {PROJECT_ROOT}")
    print_info(f"Repo: {GITHUB_REPO}\n")

    # ── Validate environment ───────────────────────────────────────────────────
    # Make sure required tokens are set before doing anything
    if not GITHUB_TOKEN:
        print_error("GITHUB_TOKEN not set in .env file")
        print_info("Create .env in project root with: GITHUB_TOKEN=your_token")
        sys.exit(1)

    # Check Claude Code CLI is available
    code, _ = run_command("claude --version")
    if code != 0:
        print_error("Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code")
        sys.exit(1)

    print_success("Environment validated")

    # ── Step 1: Fetch the GitHub issue ─────────────────────────────────────────
    # Read the issue from GitHub so all agents have the full context
    issue_number = parse_issue_number(args.issue)
    issue = fetch_github_issue(issue_number)

    print_success(f"Issue #{issue['number']}: {issue['title']}")
    print_info(f"Labels: {', '.join(issue['labels'])}")

    # ── Step 2: Plan ───────────────────────────────────────────────────────────
    # Planner agent reads the issue + docs and creates an implementation plan
    plan = run_planner_agent(issue)

    # CHECKPOINT 1 — You review the plan before any code is written
    # If you reject, the planner reruns with your feedback
    feedback = checkpoint(
        "CHECKPOINT 1 — Implementation Plan",
        plan,
        "Review the plan carefully. Type 'y' to proceed, or describe changes needed:"
    )

    while feedback != 'y':
        print_info("Replanning with your feedback...")
        plan = run_planner_agent(issue, feedback)
        feedback = checkpoint("CHECKPOINT 1 — Updated Plan", plan)

    # Extract branch name and feature from the plan using regex
    # The planner always includes "feat/us-XX-..." in the plan
    branch_match = re.search(r'feat/[\w-]+', plan)
    branch = branch_match.group(0) if branch_match else f"feat/us-{issue_number}"

    # Extract feature folder name (auth, home, spaces, invite, tasks)
    feature_match = re.search(r'lib/features/(\w+)/', plan)
    feature = feature_match.group(1) if feature_match else "unknown"

    print_info(f"Branch: {branch}")
    print_info(f"Feature: {feature}")

    # ── Step 3: Create feature branch ─────────────────────────────────────────
    # Create a new git branch — all code changes go here, never on main
    print_info(f"Creating branch {branch}...")
    if not git_checkout_branch(branch):
        print_error(f"Failed to create branch {branch}")
        sys.exit(1)
    print_success(f"On branch {branch}")

    # ── Step 4: Generate feature code ─────────────────────────────────────────
    # Coder agent writes all the Flutter files based on the plan
    coder_output = run_coder_agent(issue, plan)

    # Always run flutter analyze after code generation
    analyze_passed, analyze_output = run_flutter_analyze()

    # Build summary for the checkpoint
    code_summary = f"Coder agent output:\n{coder_output}"
    if not analyze_passed:
        code_summary += f"\n\n⚠️  flutter analyze issues found:\n{analyze_output}"
    else:
        code_summary += "\n\n✓ flutter analyze passed clean"

    # CHECKPOINT 2 — You review the generated code in VS Code
    # Open VS Code and look at the files before approving
    feedback = checkpoint(
        "CHECKPOINT 2 — Review Generated Code",
        code_summary,
        "Open VS Code and review the generated files. Type 'y' when happy, or describe issues:"
    )

    while feedback != 'y':
        print_info("Regenerating code with your feedback...")
        coder_output = run_coder_agent(issue, plan, feedback)
        analyze_passed, analyze_output = run_flutter_analyze()
        code_summary = f"Updated output:\n{coder_output}"
        if not analyze_passed:
            code_summary += f"\n\n⚠️  flutter analyze issues:\n{analyze_output}"
        feedback = checkpoint("CHECKPOINT 2 — Review Updated Code", code_summary)

    # ── Step 5: Manual testing ─────────────────────────────────────────────────
    # You run the app yourself and verify the feature works before tests are written
    # This catches UX and runtime issues that static analysis can't find

    # CHECKPOINT 3 — You run the app and test manually
    feedback = checkpoint(
        "CHECKPOINT 3 — Manual Testing",
        f"Run the app and test the feature manually:\n\n"
        f"  flutter run\n\n"
        f"Feature: {issue['title']}\n\n"
        f"Acceptance criteria to verify:\n{issue['body'][:800]}",
        "Test manually on device/simulator. Type 'y' when satisfied, or describe issues:"
    )

    while feedback != 'y':
        print_info("Fixing issues from manual testing...")
        coder_output = run_coder_agent(issue, plan, feedback)
        feedback = checkpoint(
            "CHECKPOINT 3 — Manual Testing (retry)",
            f"Run the app again and verify the fix.\n\nflutter run",
        )

    # ── Step 6: Write tests ────────────────────────────────────────────────────
    # Test Writer agent writes unit + widget tests for all generated files
    test_output = run_test_writer_agent(issue, feature)
    test_passed, test_results = run_flutter_test()

    test_summary = f"Test results:\n{test_results}\n\nTest writer output:\n{test_output}"

    # CHECKPOINT 4 — You review the test files
    feedback = checkpoint(
        "CHECKPOINT 4 — Review Tests",
        test_summary,
        "Review test files in VS Code. Type 'y' to proceed, or describe issues:"
    )

    while feedback != 'y':
        print_info("Updating tests with your feedback...")
        test_output = run_test_writer_agent(issue, feature)
        test_passed, test_results = run_flutter_test()
        test_summary = f"Updated test results:\n{test_results}"
        feedback = checkpoint("CHECKPOINT 4 — Review Updated Tests", test_summary)

    # ── Step 7: Critic review loop ─────────────────────────────────────────────
    # Critic agent reviews code + tests together
    # If issues found, sends them back to Coder agent to fix
    # Retries up to MAX_CRITIC_RETRIES (3) times automatically
    retry_count = 0
    review = run_critic_agent(issue, feature, retry_count)

    while review["status"] == "issues_found" and retry_count < MAX_CRITIC_RETRIES:
        # Format issues for display and for the Coder agent
        issues_text = "\n".join([
            f"- [{i['severity'].upper()}] {i.get('file', 'unknown')}: {i['description']} → Fix: {i['fix']}"
            for i in review["issues"]
        ])
        print_warning(f"Critic found issues (attempt {retry_count + 1}/{MAX_CRITIC_RETRIES}):")
        print(issues_text)
        print_info("Sending issues to Coder agent to fix automatically...")

        # Coder agent fixes the issues — no checkpoint here, it's automatic
        coder_output = run_coder_agent(issue, plan, f"Fix these code review issues:\n{issues_text}")
        retry_count += 1
        review = run_critic_agent(issue, feature, retry_count)

    # Build critic summary for the checkpoint
    critic_summary = f"Status: {review['status'].upper()}\nSummary: {review['summary']}"

    if review.get("issues"):
        critic_summary += "\n\nRemaining issues:\n" + "\n".join([
            f"  - [{i['severity']}] {i['description']}" for i in review["issues"]
        ])

    if review.get("suggestions"):
        critic_summary += "\n\nSuggestions (non-blocking):\n" + "\n".join([
            f"  - {s}" for s in review["suggestions"]
        ])

    if retry_count >= MAX_CRITIC_RETRIES and review["status"] != "clean":
        critic_summary += (
            f"\n\n⚠️  Max retries ({MAX_CRITIC_RETRIES}) reached with issues remaining.\n"
            f"You may want to review and fix manually before proceeding."
        )

    # CHECKPOINT 5 — You see the full review results before committing
    feedback = checkpoint(
        "CHECKPOINT 5 — Code Review Results",
        critic_summary,
        "Review the critic output. Type 'y' to proceed to commit, or describe additional fixes:"
    )

    while feedback != 'y':
        print_info("Applying additional fixes from your feedback...")
        coder_output = run_coder_agent(issue, plan, feedback)
        review = run_critic_agent(issue, feature, retry_count)
        critic_summary = f"Status: {review['status'].upper()}\nSummary: {review['summary']}"
        feedback = checkpoint("CHECKPOINT 5 — Updated Review Results", critic_summary)

    # ── Step 8: Commit approval ────────────────────────────────────────────────
    # Build the commit message from the issue title
    # Uses conventional commits format: feat(feature): description
    feature_files = list_feature_files(feature)
    test_files = list_test_files(feature)

    # Clean up issue title for commit message
    clean_title = issue['title'].lower()
    clean_title = re.sub(r'^\[us-\d+\]\s*', '', clean_title)   # remove [US-XX] prefix
    clean_title = re.sub(r'^\[chore\]\s*', '', clean_title)     # remove [CHORE] prefix
    commit_message = f"feat({feature}): {clean_title}"

    commit_preview = (
            f"Branch: {branch}\n"
            f"Commit message: {commit_message}\n\n"
            f"Files to commit ({len(feature_files + test_files)} total):\n"
            + "\n".join([f"  {f}" for f in feature_files + test_files])
    )

    # CHECKPOINT 6 — You approve the exact commit before it happens
    # Nothing is committed until you type 'y'
    feedback = checkpoint(
        "CHECKPOINT 6 — Commit Approval",
        commit_preview,
        "Type 'y' to commit these files, or provide a different commit message:"
    )

    # If feedback starts with "feat" or "chore", treat it as a new commit message
    if feedback != 'y' and (feedback.startswith("feat") or feedback.startswith("chore")):
        commit_message = feedback
        feedback = checkpoint(
            "CHECKPOINT 6 — Confirm Commit Message",
            f"Commit message: {commit_message}"
        )

    commit_success, commit_output = git_commit(commit_message)
    if not commit_success:
        print_error(f"Commit failed: {commit_output}")
        sys.exit(1)

    commit_hash = get_last_commit_hash()
    print_success(f"Committed: {commit_hash}")

    # Push branch to GitHub so PR can be opened
    print_info("Pushing branch to GitHub...")
    if not git_push(branch):
        print_error("Push failed — check your GitHub token and network connection")
        sys.exit(1)
    print_success(f"Pushed {branch} to origin")

    # ── Step 9: Open PR ────────────────────────────────────────────────────────
    # PR Writer agent generates a rich description
    pr_body = run_pr_writer_agent(issue, feature, branch, review["summary"])
    pr_title = issue["title"]

    pr_preview = f"Title: {pr_title}\nBranch: {branch} → main\n\n{pr_body}"

    # CHECKPOINT 7 — You review and approve the PR description
    # PR is only opened after you type 'y'
    feedback = checkpoint(
        "CHECKPOINT 7 — PR Approval",
        pr_preview,
        "Review the PR description. Type 'y' to open the PR, or describe changes:"
    )

    while feedback != 'y':
        print_info("Updating PR description with your feedback...")
        pr_body = run_pr_writer_agent(
            {**issue, "body": issue["body"] + f"\n\nPR description feedback: {feedback}"},
            feature, branch, review["summary"]
        )
        pr_preview = f"Title: {pr_title}\n\n{pr_body}"
        feedback = checkpoint("CHECKPOINT 7 — Updated PR Description", pr_preview)

    # Open the PR using PyGithub
    pr_url = open_pull_request(branch, pr_title, pr_body, issue_number)
    print_success(f"PR opened: {pr_url}")

    # ── Done ───────────────────────────────────────────────────────────────────
    print_header("Pipeline Complete! 🎉")
    print_success(f"Issue:  #{issue_number} — {issue['title']}")
    print_success(f"Branch: {branch}")
    print_success(f"Commit: {commit_hash}")
    print_success(f"PR:     {pr_url}")
    print(f"\n{BOLD}Next: Review and merge the PR on GitHub, then close issue #{issue_number}.{RESET}\n")


if __name__ == "__main__":
    main()