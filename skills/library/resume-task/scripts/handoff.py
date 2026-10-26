#!/usr/bin/env python3
"""Runtime-neutral checkpoint. No model calls, command execution from notes, or session store."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

SECTIONS = {"done": "Done", "next": "Next", "decisions": "Decisions",
            "open_questions": "Open questions", "verify": "Verify commands"}


def git(root, *args):
    return subprocess.check_output(["git", "-c", "core.fsmonitor=false", "-C", str(root), *args],
                                   env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"}, stderr=subprocess.PIPE)


def worktree(path):
    root = Path(path).resolve(strict=True)
    if Path(os.fsdecode(git(root, "rev-parse", "--show-toplevel")).strip()).resolve() != root:
        raise ValueError("--worktree must be the Git worktree root")
    return root


def snapshot(root):
    # Exclude this checkpoint to avoid a self-referential digest. Never retain diff contents.
    paths = ["--", ".", ":(exclude)HANDOFF.md"]
    status = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all", *paths)
    digest = hashlib.sha256()
    for args in [("diff", "--no-ext-diff", "--no-textconv", "--binary", "HEAD"),
                 ("diff", "--no-ext-diff", "--no-textconv", "--binary", "--cached")]:
        digest.update(git(root, *args, *paths))
    for name in sorted(git(root, "ls-files", "--others", "--exclude-standard", "-z", *paths).split(b"\0")):
        if not name:
            continue
        file = root / os.fsdecode(name)
        digest.update(name + b"\0")
        digest.update(os.fsencode(os.readlink(file)) if file.is_symlink() else file.read_bytes())
    return {"worktree": str(root), "head": git(root, "rev-parse", "HEAD").decode().strip(),
            "branch": git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip(),
            "status": os.fsdecode(status).split("\0")[:-1], "changes_sha256": digest.hexdigest()}


def validate_notes(notes):
    if not isinstance(notes, dict) or set(notes) != {"task", *SECTIONS}:
        raise ValueError("notes require exactly task, done, next, decisions, open_questions, verify")
    if not isinstance(notes["task"], str) or not notes["task"].strip() or "\n" in notes["task"]:
        raise ValueError("task must be a nonempty single line")
    for key in SECTIONS:
        values = notes[key]
        if not isinstance(values, list) or not values or any(
                not isinstance(v, str) or not v.strip() or "\n" in v for v in values):
            raise ValueError(f"{key} must contain nonempty single-line strings (use 'None' explicitly)")


def render(notes, state):
    validate_notes(notes)
    text = "# HANDOFF v1\n\nTask: " + notes["task"] + "\n\n"
    for key, title in SECTIONS.items():
        text += "## " + title + "\n" + "".join("- " + v + "\n" for v in notes[key]) + "\n"
    text += "## Git state\n```json\n" + json.dumps(state, indent=2, sort_keys=True) + "\n```\n"
    return text


def parse(text):
    # The small format is intentionally strict and human-readable. Commands are data, never evaluated.
    match = re.fullmatch(r"# HANDOFF v1\n\nTask: ([^\n]+)\n\n(.*)## Git state\n```json\n(.*)\n```\n", text, re.S)
    if not match:
        raise ValueError("invalid HANDOFF v1 header or Git state block")
    notes = {"task": match[1]}
    remaining = match[2]
    for key, title in SECTIONS.items():
        prefix = "## " + title + "\n"
        if not remaining.startswith(prefix):
            raise ValueError("missing or out-of-order section: " + title)
        body, separator, remaining = remaining[len(prefix):].partition("\n\n")
        if not separator or any(not line.startswith("- ") for line in body.splitlines()):
            raise ValueError("invalid list in " + title)
        notes[key] = [line[2:] for line in body.splitlines()]
    if remaining:
        raise ValueError("unexpected section")
    validate_notes(notes)
    return notes, json.loads(match[3])


def write(root, notes):
    target = root / "HANDOFF.md"
    if target.is_symlink() or (target.exists() and not target.is_file()):
        raise ValueError("refusing non-regular HANDOFF.md")
    text = render(notes, snapshot(root))
    fd, temp = tempfile.mkstemp(prefix=".handoff-", dir=root)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, target)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["write", "validate", "refresh"])
    parser.add_argument("--worktree", required=True, help="absolute Git worktree root")
    parser.add_argument("--notes", type=Path, help="JSON notes for write; never contains secrets")
    args = parser.parse_args()
    try:
        if not Path(args.worktree).is_absolute():
            raise ValueError("--worktree must be absolute")
        root = worktree(args.worktree)
        if args.action == "write":
            if not args.notes:
                raise ValueError("write requires --notes")
            write(root, json.loads(args.notes.read_text()))
        else:
            target = root / "HANDOFF.md"
            if target.is_symlink():
                raise ValueError("refusing symlink HANDOFF.md")
            notes, state = parse(target.read_text())
            if args.action == "refresh":
                write(root, notes)
            elif state != snapshot(root):
                raise ValueError("stale Git state; reconcile notes with the live diff, then refresh")
        print(f"HANDOFF v1 {args.action}: {root / 'HANDOFF.md'}")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
