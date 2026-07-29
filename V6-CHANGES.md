# v6 changes

- JetBrains Mono is the only configured WezTerm text family.
- Removed the previous external font cask.
- Removed the separately installed patched JetBrains font package.
- WezTerm uses its bundled JetBrains Mono, avoiding host font-cache and family
  name mismatches.
- `rebuild.sh` resolves the WezTerm CLI from PATH or the application bundle and
  verifies that `wezterm ls-fonts` reports JetBrains Mono.
- Recursive, manifest-backed project synchronization into
  `~/firstmate/projects` remains enabled on every rebuild.
- Added a release checklist for validation, secret scanning, commit, push, and
  friend installation.
