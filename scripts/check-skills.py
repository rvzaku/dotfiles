#!/usr/bin/env python3
"""Check declarative skill admission and portable metadata; no downloads or installation."""
import argparse
import json
from pathlib import Path
import re


def check(root):
    manifest = json.loads((root / "manifest.json").read_text())
    if manifest["schema"] != 1:
        raise ValueError("unsupported manifest schema")
    sources = {s["id"]: s for s in json.loads((root / "sources.json").read_text())["sources"]}
    cases = {c["skill"] for c in json.loads((root / "evals.json").read_text())["cases"]}
    names = set()
    enabled = []
    for skill in manifest["skills"]:
        name = skill["name"]
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) or len(name) > 64 or name in names:
            raise ValueError("invalid/duplicate skill name: " + name)
        names.add(name)
        if type(skill["enabled"]) is not bool:
            raise ValueError("enabled must be boolean: " + name)
        for key in ["license", "why", "permissions", "evaluation", "modelEvidence"]:
            if not skill.get(key):
                raise ValueError("missing admission evidence: " + name + ":" + key)
        if name not in cases:
            raise ValueError("missing eval case: " + name)
        directory = root / "library" / name
        if directory.is_symlink() or not directory.is_dir() or any(p.is_symlink() for p in directory.rglob("*")):
            raise ValueError("skill must be a canonical directory: " + name)
        text = (directory / "SKILL.md").read_text()
        parts = text.split("---\n", 2)
        if len(parts) != 3 or parts[0]:
            raise ValueError("missing frontmatter: " + name)
        meta = dict(line.split(": ", 1) for line in parts[1].splitlines() if ": " in line)
        if meta.get("name") != name or not 1 <= len(meta.get("description", "")) <= 1024:
            raise ValueError("invalid name/description: " + name)
        if meta.get("license") != skill["license"] or re.search(r"^allowed-tools\s*:", parts[1], re.M):
            raise ValueError("license mismatch or implicit tool grant: " + name)
        if not (directory / "NOTICE.md").is_file() or not list(directory.glob("LICENSE*")):
            raise ValueError("missing attribution/license: " + name)
        for link in re.findall(r"`((?:references|scripts)/[^`]+)`", text):
            asset = directory / link
            if not asset.is_file() or not asset.resolve().is_relative_to(directory.resolve()):
                raise ValueError("missing/escaping progressive asset: " + link)
        for source in skill["sources"]:
            record = sources[source]
            if not re.fullmatch(r"[0-9a-f]{40}", record["rev"]) or not record.get("license"):
                raise ValueError("unpinned/unlicensed source: " + source)
        if skill["enabled"]:
            enabled.append(name)
    if names != {p.name for p in (root / "library").iterdir() if p.is_dir()}:
        raise ValueError("unreviewed or missing canonical library directory")
    return enabled


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "skills")
    args = parser.parse_args()
    try:
        print(json.dumps({"enabled": check(args.root)}, indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, str(error) + "\n")
