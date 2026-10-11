#!/usr/bin/env bash
# Rename nautical Helmsman paths and words in an already set-up repo.
# Idempotent. A second run leaves the tree unchanged.
# Run from the target repo root. The script may live outside that repo.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

in_git=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
fi

python3 - "$root" "$in_git" << 'PY'
import os, pathlib, re, shutil, subprocess, sys

root = pathlib.Path(sys.argv[1])
in_git = sys.argv[2] == "1"
harness = (root / "eval" / "flake.sh").is_file()

def run(args):
    subprocess.run(args, cwd=root, check=True)

def move(src, dest):
    src, dest = root / src, root / dest
    if not src.exists():
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        if in_git:
            tracked = subprocess.run(["git", "ls-files", "--", str(src.relative_to(root))], cwd=root, capture_output=True, text=True)
            if tracked.stdout.strip():
                flag = ["-r"] if src.is_dir() else []
                subprocess.run(["git", "rm", "-q", *flag, "--", str(src.relative_to(root))], cwd=root, check=False)
        if src.is_dir() and src.exists():
            shutil.rmtree(src)
        elif src.is_file():
            src.unlink()
        return True
    if in_git:
        tracked = subprocess.run(["git", "ls-files", "--", str(src.relative_to(root))], cwd=root, capture_output=True, text=True)
        if tracked.stdout.strip():
            run(["git", "mv", str(src.relative_to(root)), str(dest.relative_to(root))])
            return True
    shutil.move(src, dest)
    return True

pairs = []

def add_dir(old, new):
    pairs.append((old, new))

for old, new in [
    ("helmsmans-nightwatch.md", "helmsman-nightly.md"),
    ("helmsmans-lookout.md", "helmsman-upstream.md"),
    ("helmsmans-review.md", "helmsman-review.md"),
]:
    add_dir(f".cursor/automations/{old}", f".cursor/automations/{new}")

for old, new in [
    ("helmsmans-bearings.mdc", "helmsman-tests.mdc"),
    ("helmsmans-checklist.mdc", "helmsman-checklist.mdc"),
]:
    add_dir(f".cursor/rules/{old}", f".cursor/rules/{new}")

for old, new in [
    ("helmsmans-bail", "helmsman-fix"),
    ("helmsmans-bearings", "helmsman-tests"),
    ("helmsmans-bilge", "helmsman-maintain"),
    ("helmsmans-caulk", "helmsman-security"),
    ("helmsmans-gale", "helmsman-structure"),
    ("helmsmans-keel", "helmsman-readiness"),
    ("helmsmans-reef", "helmsman-shortcuts"),
    ("helmsmans-review", "helmsman-review"),
    ("helmsmans-rig", "helmsman-setup"),
    ("helmsmans-wake", "helmsman-delivery"),
]:
    add_dir(f".cursor/skills/{old}", f".cursor/skills/{new}")

add_dir(".cursor/skills/helmsman-maintain", ".cursor/skills/helmsman-slop")
add_dir(".cursor/skills/helmsman-fix", ".cursor/skills/helmsman-fix-forward")

for old, new in [
    ("crows-nest.sh", "e2e-smoke.sh"),
    ("sail.sh", "integration.sh"),
    ("rigging.sh", "setup-check.sh"),
]:
    add_dir(f".helmsman/tools/checks/{old}", f".helmsman/tools/checks/{new}")

add_dir(".helmsman/rigging.md", ".helmsman/setup.md")

if harness:
    add_dir("docs/self-keel.md", "docs/readiness.md")
    add_dir("eval/fixture/.helmsman/rigging.md", "eval/fixture/.helmsman/setup.md")
    add_dir("eval/scenarios/s6-missing-nest", "eval/scenarios/s6-missing-e2e")
    add_dir("eval/scenarios/s9-sail-mock", "eval/scenarios/s9-integration-mock")
    add_dir("eval/scenarios/s4-pure-function/fail-mast.diff", "eval/scenarios/s4-pure-function/fail-unit.diff")
    add_dir("eval/scenarios/s4-pure-function/fail-knot.diff", "eval/scenarios/s4-pure-function/fail-kept.diff")
    add_dir("eval/scenarios/s4-pure-function/fail-kept.diff", "eval/scenarios/s4-pure-function/fail-protected.diff")

moved = False
for old, new in pairs:
    if move(old, new):
        moved = True

# Longest literals first. Word replacements come after these exact strings.
literals = [
    ("helmsmans-nightwatch", "helmsman-nightly"),
    ("helmsmans-lookout", "helmsman-upstream"),
    ("helmsmans-bearings", "helmsman-tests"),
    ("helmsmans-checklist", "helmsman-checklist"),
    ("helmsmans-review", "helmsman-review"),
    ("helmsmans-caulk", "helmsman-security"),
    ("helmsmans-bilge", "helmsman-maintain"),
    ("helmsmans-keel", "helmsman-readiness"),
    ("helmsmans-bail", "helmsman-fix"),
    ("helmsmans-wake", "helmsman-delivery"),
    ("helmsmans-gale", "helmsman-structure"),
    ("helmsmans-reef", "helmsman-shortcuts"),
    ("helmsmans-rig", "helmsman-setup"),
    ("crows-nest.sh", "e2e-smoke.sh"),
    ("rigging.sh", "setup-check.sh"),
    ("sail.sh", "integration.sh"),
    (".helmsman/rigging.md", ".helmsman/setup.md"),
    ("!.helmsman/rigging.md", "!.helmsman/setup.md"),
    ("self-keel.md", "readiness.md"),
    ("self-keel", "readiness"),
    ("keel.md", "readiness.md"),
    ("water.md", "maintain.md"),
    ("leaks.md", "security.md"),
    ("1_helmsman-rigging", "1_helmsman-setup"),
    ("pnpm-task.sh sail", "pnpm-task.sh integration"),
    ("pnpm-task.sh rigging", "pnpm-task.sh setup"),
    ("pnpm test:sail", "pnpm test:integration"),
    ("pnpm rigging", "pnpm setup:check"),
    ("test:sail", "test:integration"),
    ("test-sail", "test-integration"),
    ("test (sail)", "test (integration)"),
    ("test-mast", "test-unit"),
    ("test (mast)", "test (unit)"),
    ("write_rigging", "write_setup"),
    ("rigging_task", "setup_task"),
    ("sail_task", "integration_task"),
    ("sail_unmocked", "integration_unmocked"),
    ("sailUnmocked", "integrationUnmocked"),
    ("isSail", "isIntegration"),
    ("missing_nest", "missing_e2e"),
    ("missingNest", "missingE2e"),
    ("ui_nest", "ui_e2e"),
    ("uiNest", "uiE2e"),
    ("mast_knot", "unit_test"),
    ("mastPin", "unitPin"),
    ("knot_law", "kept_test"),
    ("bilgeMode", "maintainMode"),
    ("fail-mast.diff", "fail-unit.diff"),
    ("fail-knot.diff", "fail-kept.diff"),
    ("catch-fail-mast.diff", "catch-fail-unit.diff"),
    ("catch-fail-knot.diff", "catch-fail-kept.diff"),
    ("s6-missing-nest", "s6-missing-e2e"),
    ("s9-sail-mock", "s9-integration-mock"),
    ("10 rigging \"\" no bare", "10 setup:check \"\" no bare"),
    ('"rigging":', '"setup:check":'),
    ("Crow's nest", "E2E smoke"),
    ("crow's nest", "e2e smoke"),
    ("Crows nest", "E2E smoke"),
    ("crows nest", "e2e smoke"),
    ("Crow nest", "E2E smoke"),
    ("crow nest", "e2e smoke"),
    ("crows-nest", "e2e-smoke"),
    ("Lookout PR", "Upstream PR"),
    ("lookout PR", "upstream PR"),
    ("Sail, sink, or beached", "pass, block, or revise"),
    ("Sail | sink | beached", "pass | block | revise"),
    ("sail, sink, and beached", "pass, block, and revise"),
    ("Sail, sink, and beached", "pass, block, and revise"),
    ("sink and beached", "block and revise"),
    ("**Answer:** Sail", "**Answer:** pass"),
    ("## Sail", "## pass"),
    ("**Sail:**", "**pass:**"),
    ("**Sail.**", "**pass.**"),
    ("**sink:**", "**block:**"),
    ("**sink.**", "**block.**"),
    ("## sink", "## block"),
    ("**beached:**", "**revise:**"),
    ("**beached.**", "**revise.**"),
    ("## beached", "## revise"),
    ("how to caulk", "how to fix"),
    ("caulk it", "fix it"),
    ("caulk them", "fix them"),
    ("knot law", "kept-test rule"),
    ("a new knot", "a new test"),
    ("old knot", "old test"),
    ("the knot", "the passing test"),
    ("no knot", "no test"),
    ("mast test", "unit test"),
    ("Bearings chooses", "Test choice selects"),
    ("## Bearings", "## Tests"),
    ("North star", "quality of what shipped"),
    ("north star", "quality of what shipped"),
    ("or Sail with fix-forward", "or pass with fix-forward"),
    ("Before calling a change Sail", "Before calling a change pass"),
    ("Never sink without", "Never block without"),
    ("Data loss stays sink", "Data loss stays block"),
    ("changes sink when", "changes block when"),
    ("Do not sink a change", "Do not block a change"),
    ("Explain a Sail leftover", "Explain a pass leftover"),
    ("a sink finding", "a block finding"),
    ("name it under sink", "name it under block"),
    ("goes under sink", "goes under block"),
    ("under sink", "under block"),
    ("calls sink goes under block", "calls block goes under block"),
    ("never sink", "never block"),
    ("Sink only when", "Block only when"),
    ("is not Sail while", "is not a pass while"),
    ("(sail, sink, revise)", "(pass, block, revise)"),
    ("(integration, sink, revise)", "(pass, block, revise)"),
    ("`Sail` when nothing", "`pass` when nothing"),
    ("still Sail", "still pass"),
    ("`sink` when a critical", "`block` when a critical"),
    ("the answer is sink", "the answer is block"),
    ("or `Ship.`", "or `Merge.`"),
    ("across sink, revise, and Sail", "across block, revise, and pass"),
    ("goes under Sail", "goes under pass"),
    ("Do not recommend `Sail`", "Do not recommend `pass`"),
    ("Do not recommend `Integration`", "Do not recommend `pass`"),
    ("cannot Sail", "cannot pass"),
    ("cannot Integration", "cannot pass"),
    ("also caulks", "also runs security"),
    ("what was reefed", "what was shortened"),
    ("Helmsmans ", "Helmsman "),
    ("helmsmans-", "helmsman-"),
    ("Checklist answer: pass, block, or revise.", "Verdict: Approve or Request changes."),
    ("owns the three answers: pass, block, or revise", "owns the verdict: Approve or Request changes"),
    ("The three answers: pass, block, or revise.", "The verdict is Approve or Request changes."),
    ("This file owns the three answers.", "This file owns the verdict and the finding labels."),
    ("The three answers live only in the checklist.", "The verdict and the finding labels live only in the checklist."),
    ("**Answer:** pass | block | revise", "**Verdict:** Approve | Request changes"),
    ("pass, block, or revise", "Approve or Request changes"),
    ("pass | block | revise", "Approve | Request changes"),
    ("pass, block, and revise", "Approve and Request changes"),
    ("(pass, block, revise)", "(Approve, Request changes)"),
    ("**Answer:** pass", "**Verdict:** Approve"),
    ("fix every block and revise finding", "fix every Blocker, unjustified Judo, High, and Medium finding"),
    ("what remains minor or deferred and why", "what remains Fix forward or Nit and why"),
    ("- **pass.**", "- **Approve.**"),
    ("- **block.**", "- **Blocker.**"),
    ("- **revise.**", "- **Judo.**"),
    ("**pass:**", "**Fix forward:**"),
    ("**block:**", "**Blocker:**"),
    ("**revise:**", "**Judo:**"),
    ("## block\n", "## Blocker\n"),
    ("## revise\n", "## Judo\n"),
    ("## pass\n\n| # |", "## Fix forward\n\n| # |"),
    ("or pass with fix-forward", "or Approve with Fix forward"),
    ("Before calling a change pass", "Before calling a change Approve"),
    ("Never block without", "Never use Blocker without"),
    ("Data loss stays block", "Data loss stays Blocker"),
    ("changes block when", "changes are a Blocker when"),
    ("Do not block a change", "Do not stop a change"),
    ("Explain a pass leftover", "Explain a Fix forward leftover"),
    ("a block finding", "a Blocker finding"),
    ("name it under block", "name it under Blocker"),
    ("goes under block", "goes under Blocker"),
    ("under block", "under Blocker"),
    ("calls block goes under Blocker", "calls Blocker goes under Blocker"),
    ("Block only when", "Use Blocker only when"),
    ("is not a pass while", "is not an Approve while"),
    ("`pass` when nothing", "`Approve` when nothing"),
    ("`block` when a critical", "`Blocker` when a critical"),
    ("the answer is block", "the verdict is Request changes"),
    ("across block, revise, and pass", "across Blocker, Judo, and Fix forward"),
    ("goes under pass", "goes under Fix forward"),
    ("Do not recommend `pass`", "Do not recommend `Approve`"),
    ("calls block goes under block", "calls Blocker goes under Blocker"),
    ("are **revise**", "are **Judo**"),
    ("helmsman-maintain", "helmsman-slop"),
    ("maintain.md", "slop.md"),
    ("maintainMode", "slopMode"),
    ("hasPriorWater", "hasPriorSlop"),
    ("kept_test", "protected_test"),
    ("fail-kept.diff", "fail-protected.diff"),
    ("Kept tests", "Protected tests"),
    ("kept tests", "protected tests"),
    ("Kept test", "protected test"),
    ("kept test", "protected test"),
    ("kept-test", "protected-test"),
]

words = [
    (re.compile(r"\b[Rr]igging\b"), "setup"),
    (re.compile(r"\bRigging\b"), "Setup"),
    (re.compile(r"\bNightwatch\b"), "Nightly"),
    (re.compile(r"\bnightwatch\b"), "nightly"),
    (re.compile(r"\bBeached\b"), "Revise"),
    (re.compile(r"\bbeached\b"), "revise"),
    (re.compile(r"\bBilge\b"), "Maintainability"),
    (re.compile(r"\bbilge\b"), "maintainability"),
    (re.compile(r"\bMaintainability\b"), "Slop"),
    (re.compile(r"\bmaintainability\b"), "slop"),
    (re.compile(r"\bCaulk\b"), "Security"),
    (re.compile(r"\bcaulking\b"), "security notes"),
    (re.compile(r"\bcaulk\b"), "security"),
    (re.compile(r"\bKeel\b"), "Readiness"),
    (re.compile(r"\bkeel\b"), "readiness"),
    (re.compile(r"\bBearings\b"), "Tests"),
    (re.compile(r"\bbearings\b"), "tests"),
    (re.compile(r"\bLookout\b"), "Upstream watch"),
    (re.compile(r"\blookout\b"), "upstream watch"),
    (re.compile(r"\bGale\b"), "Structure"),
    (re.compile(r"\bgale\b"), "structure"),
    (re.compile(r"\bReef\b"), "Shortcuts"),
    (re.compile(r"\breef\b"), "shortcuts"),
    (re.compile(r"\bWake\b"), "Delivery"),
    (re.compile(r"\bwake\b"), "delivery"),
    (re.compile(r"\bBails\b"), "Fixes"),
    (re.compile(r"\bbails\b"), "fixes"),
    (re.compile(r"\bBail\b"), "Fix"),
    (re.compile(r"\bbail\b"), "fix"),
    (re.compile(r"\bMast\b"), "Unit test"),
    (re.compile(r"\bmast\b"), "unit test"),
    (re.compile(r"\bSails\b"), "Integration tests"),
    (re.compile(r"\bsails\b"), "integration tests"),
    (re.compile(r"\bSail\b"), "Integration"),
    (re.compile(r"\bsail\b"), "integration"),
    (re.compile(r"\bKnots\b"), "Protected tests"),
    (re.compile(r"\bknots\b"), "protected tests"),
    (re.compile(r"\bKnot\b"), "Protected test"),
    (re.compile(r"\bknot\b"), "protected test"),
    (re.compile(r"helmsman-fix(?!-forward)"), "helmsman-fix-forward"),
    (re.compile(r"\b[Rr]ig\b"), "setup"),
    (re.compile(r"\bhelms\b"), "helm"),
]

# Rig is the old skill verb. "setup" twice is fine. Do not turn Helmsman into something else.
# The helms pattern is unused on purpose: Helmsman must stay. Drop it.
words = words[:-1]

skip_parts = {
    ".git", "node_modules", "upstream",
}
skip_files = {
    ".helmsman/tools/checks/migrate-names.sh",
    ".helmsman/tools/checks/migrate-names.bats",
    ".helmsman/tools/checks/plain-language.sh",
    ".helmsman/tools/checks/ci.bats",
    ".helmsman/tools/checks/install-review-ready.sh",
    "docs/renames.md",
}

def skip_path(rel):
    if rel in skip_files:
        return True
    parts = pathlib.PurePosixPath(rel).parts
    if "node_modules" in parts or ".git" in parts:
        return True
    if len(parts) >= 3 and parts[0] == ".helmsman" and parts[1] == "tools" and parts[2] == "upstream":
        return True
    if rel.endswith("pnpm-lock.yaml") or rel.endswith(".lock"):
        return True
    return False

def owned(rel):
    if rel in {"lefthook.yml", ".gitignore", "package.json", "AGENTS.md"}:
        return True
    if rel == ".github/PULL_REQUEST_TEMPLATE.md" or rel.startswith(".github/workflows/helmsman"):
        return True
    if rel.startswith(".cursor/skills/") or rel.startswith(".cursor/rules/") or rel.startswith(".cursor/automations/"):
        return True
    if rel.startswith(".helmsman/"):
        return True
    if rel == ".helmsman/tools/make/helmsman.mk" or rel.endswith("helmsman.mk"):
        return True
    if harness and (rel in {"README.md", "CONTEXT.md"} or rel.startswith("docs/") or rel.startswith("eval/")):
        return True
    return False

def apply_text(text, code=False):
    for old, new in literals:
        text = text.replace(old, new)
    # Restore the pnpm script key if a blanket quote replace overshot a value.
    text = text.replace("pnpm-task.sh setup:check", "pnpm-task.sh setup")
    for pattern, new in words:
        def repl(match, new=new, code=code):
            word = match.group(0)
            out = new
            if word[:1].isupper() and out[:1].islower():
                out = out[:1].upper() + out[1:]
            if code and " " in out:
                parts = out.split()
                out = parts[0] + "".join(part[:1].upper() + part[1:] for part in parts[1:])
                if word[:1].islower():
                    out = out[:1].lower() + out[1:]
            return out
        text = pattern.sub(repl, text)
    text = text.replace("a integration", "an integration")
    text = text.replace("A integration", "An integration")
    text = text.replace("a e2e", "an e2e")
    text = text.replace("A e2e", "An e2e")
    return text

changed = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [name for name in dirnames if name not in skip_parts]
    for name in filenames:
        path = pathlib.Path(dirpath, name)
        rel = path.relative_to(root).as_posix()
        if skip_path(rel) or not owned(rel):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if "\0" in text:
            continue
        code = path.suffix in {".mjs", ".js", ".cjs", ".sh", ".bash", ".bats", ".py", ".rs", ".ts", ".tsx"}
        updated = apply_text(text, code)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed.append(rel)

pkg = root / "package.json"
if pkg.is_file():
    import json
    data = json.loads(pkg.read_text())
    scripts = data.get("scripts")
    if isinstance(scripts, dict):
        renamed = {}
        for key, value in scripts.items():
            if isinstance(value, str):
                value = apply_text(value)
            if key == "test:sail":
                key = "test:integration"
            elif key == "rigging":
                key = "setup:check"
            elif key == "setup" and isinstance(value, str) and "pnpm-task.sh setup" in value:
                key = "setup:check"
            renamed[key] = value
        data["scripts"] = renamed
        rendered = json.dumps(data, indent=2) + "\n"
        if rendered != pkg.read_text():
            pkg.write_text(rendered)
            if "package.json" not in changed:
                changed.append("package.json")

setup = root / ".helmsman" / "setup.md"
if setup.is_file():
    text = setup.read_text(encoding="utf-8")
    extra = ""
    lowered = text.lower()
    if "correct pr:" not in lowered:
        extra += "Correct PR: no\n"
    if "review model:" not in lowered:
        extra += "Review model: none\n"
    if "nightly fix:" not in lowered:
        extra += "Nightly fix: no\n"
    if "nightly max prs:" not in lowered:
        extra += "Nightly max PRs: 3\n"
    if "nightly max tokens:" not in lowered:
        extra += "Nightly max tokens: 200000\n"
    if "nightly max minutes:" not in lowered:
        extra += "Nightly max minutes: 30\n"
    if extra:
        if not text.endswith("\n"):
            text += "\n"
        setup.write_text(text + extra, encoding="utf-8")
        if ".helmsman/setup.md" not in changed:
            changed.append(".helmsman/setup.md")

if in_git and changed:
    run(["git", "add", "-A", "--", *changed])

print(f"helmsman: name migration done. files rewritten: {len(changed)}")
PY
