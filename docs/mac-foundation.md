# Mac operations and ownership

## Boundaries and current evidence

The real checkout is `~/dotfiles`, with `~/.dotfiles` as a compatibility link.
`machine.nix` centralizes user, LocalHostName and architecture; `/Users/<user>`
and config paths are derived. The logical flake label `mac` is deliberately
unchanged for upstream mergeability.

The three normal entry points retain Kun's command contract:

| Command | Job |
|---|---|
| `./bootstrap.sh` | Fresh Mac: install Determinate Nix if missing, link `~/.dotfiles`, offer to personalize `machine.nix`, first switch via `nix run`, verify and show owner-only sign-ins |
| `./rebuild.sh` | Later changes: relink `~/.dotfiles`, preview/approve zap, `sudo darwin-rebuild switch --flake ~/.dotfiles#mac`, verify |
| `tg` / Topgrade | Coordinated update: clean-tree preflight, record head/lock/generation, update lock, check, build, gate/switch/verify through `rebuild.sh` |

**Bootstrap and rebuild activate the machine.** Do not run them from a disposable
worktree: they repoint the live config link. To validate without applying, use
`nix flake check` and `nix build .#darwinConfigurations.mac.system --no-link`.
These builds and stubbed contract tests are not proof of an activated, usable Mac.
Actual activation and real rollback remain separate operator acceptance checks;
model calls, browser journeys and supervised delivery require their own evidence.

The foundation was activated by firstmate on the Mac (per the skills task brief).
The subsequent portable-skills changes are **not activated by this worker**. A
worker must not switch. Firstmate owns integration, attended activation, the
shared no-mistakes daemon and native relaunch/delivery demos. No lifecycle commands
are run here.
A full `nix flake check`, locked nix-darwin build, actual binary smoke checks and
native runtime skill discovery are separate from the mocked safety tests. Post-activation
verification is `scripts/verify-mac.sh`; paid model tasks and browser interaction
remain unverified until the actual delivery exercise.

## One owner per item

| Item / purpose | Owner and declaration | Source / pin / update |
|---|---|---|
| Nix daemon | Determinate installation, not nix-darwin | Reviewed official installer; existing installed daemon preserved; Topgrade does not replace it |
| nix-darwin, Home Manager, nix-homebrew | `flake.nix` | Official upstreams, exact revisions + NAR hashes in `flake.lock` |
| Homebrew runtime and taps | nix-homebrew | Runtime from its locked input; core/cask/Kun tap sources locked, `mutableTaps = false` |
| Herdr (visible backend), Topgrade (maintenance), cloudflared (existing transport) | Homebrew `brews` in `configuration.nix` | Homebrew core, formula/bottle hashes in locked core revision; no service enabled |
| WezTerm, Claude Code, Codex, Brave | Homebrew `casks` | Locked official cask definitions/hashes; Brave serves personal browsing and AXI automation with an isolated temporary profile |
| Pi / pi-signed | Homebrew `kunchenguid/tap/pi-launcher` + thin Nix `pi` wrapper | Maintainer's signed/notarized app, pinned cask hash; launcher 1.2.18 bundles Pi 1.4.0; Team 9T2J7MNUP9 |
| Treehouse | `packages/default.nix`, Nix/Home Manager | Kun's public v3.1.6 arm64 release, SHA-256 verified against release asset metadata; no Go toolchain needed |
| no-mistakes | Same | Kun's public v1.84.0 arm64 release + SHA-256; installation only, no init/update/daemon mutation |
| gh | Same | Official cli/cli v2.103.2 arm64 release + SHA-256; nixpkgs gh 2.96 is below gh-axi's >=2.99 attachment floor |
| gh-axi, chrome-devtools-axi, lavish-axi, quota-axi, tasks-axi | Nix `tools.axi`, `packages/axi` | Kun's npm packages/repositories; exact direct pins, full transitive `package-lock.json` integrity, aggregate Nix npmDepsHash; install/rebuild scripts disabled |
| Node 24 LTS + npm, Python, uv | `home.nix` Nix packages | Official nixpkgs definitions at locked revision; project locks/dev shells own project dependencies; uv Python downloads disabled |
| Git, ripgrep, fd, jq, fzf, lazygit, Neovim, tmux, ShellCheck | `home.nix` | Locked nixpkgs; Git identity not guessed, no automatic tool self-updates |
| gitleaks, osv-scanner | `home.nix` | Locked nixpkgs; secret/dependency checks complement, not replace, review |
| Hack Nerd Font | `home.nix`, Home Manager font activation | Locked nixpkgs; other user/system fonts are not removed |
| kc | `scripts/kc.sh`, Nix wrapper, Home Manager entry-point link | Small repo-authored macOS security adapter; `kc.*` namespace and NAME=ENV syntax retained, no old secret/state copied |
| tg | Home Manager shell entry point | Calls brew-owned Topgrade with one declarative update-and-apply step, plus non-conflicting native steps |
| Shell/editor/terminal/agent authored config | `home.nix` selective links to `home/` | Git owns authored files; apps own caches/sessions; optional Pi compatibility exceptions in README |
| Skills | `skills/manifest.json` + `skills/home.nix` | One immutable canonical library, licensed pinned adaptations, per-skill Home Manager discovery links; [compatibility and limits](skills-compatibility.md) |
| Firstmate | Existing `~/firstmate`, separate upstream checkout | Not owned, replaced, configured or vendored by dotfiles; its internal skills stay internal |

AXI provenance was checked against npm metadata and each `kunchenguid/<tool>`
repository, not inferred from the package name. The audit found
[GHSA-p95v-992w-h6c3](https://github.com/advisories/GHSA-p95v-992w-h6c3) in
quota-axi's exact TOON 2.1.0 dependency. A **scoped override to 2.3.1** is locked;
the resulting npm audit reports no known advisories at review time. Binary help
and TOON encode/prototype-pollution controls pass; the same control fails against
an unpatched built package. OSV independently scanned 118 lockfile packages with
no findings, and gitleaks rejected a synthetic credential while accepting the repo. An audit is not a
zero-vulnerability guarantee; refresh it for deliberate updates.

**Purpose-driven deferrals:** Go/Rust/Bun are not installed: the selected binaries
need no source toolchain, and there is no current project requiring those runtimes.
GitLab uses system OpenSSH and Git, not another authenticated CLI without a task.
OpenAPI generators, mobile simulators, containers, deployment SDKs and profilers
are project-scoped choices after the product's actual stack is known. Browser
readiness here is Brave + AXI, not proof of mobile/device/browser journeys.
No extra harness is installed simply to fill a compatibility matrix.

## Inventory and intended removal impact

Read-only inspection on 2026-10-26 found:

- Formula leaves/all installed formulae: `cloudflared`, `herdr`, `topgrade`.
- Casks: `claude-code`, `codex`, `pi-launcher`, `wezterm`; tap `kunchenguid/tap`.
- `/Applications`: WezTerm, Pi Launcher, Safari. User Applications: Claude Code URL
  Handler (agent-generated helper). Safari is OS-owned, the helper is agent-owned.
- No MAS receipts in the inspected application roots. Existing fonts are the Home
  Manager Hack Nerd Font tree and an OS-owned Arial Unicode symlink; both retain
  their owners. No user cargo/go bins, Bun/Deno/Rust/Go/uv install or Gemini/OpenCode binary.
- npm globals: the five AXI tools above. They become Nix-owned, not retained as a
  second updater. Existing npm trees are **not automatically deleted**.
- Python/pip packages belong to Apple's Command Line Tools location; no user site
  exists. System Ruby/gems and the Java system launcher are OS/CLT territory, not
  packages to uninstall. No macOS-owned runtime or data is replaced.
- `~/.local/bin`: kc/tg Home Manager links, an unmanaged Treehouse binary and a
  no-mistakes link to its existing install. New managed entry points preserve
  collisions as `.before-mac-foundation`; underlying no-mistakes state is untouched.

The **unmodified upstream** cleanup preview would remove formulae `cloudflared`,
`topgrade`, casks `codex`, `pi-launcher`, and untap `kunchenguid/tap`.
The final evaluated Brewfile preview has **zero formula/cask/tap removals**.
Pi Launcher owns `/Applications/Pi Launcher.app`, so it too survives. Brave was
subsequently declared for browsing and automation. This is a dated snapshot:
rerun the preview immediately before applying; keep the actual output outside Git.
The dry run reports cask/package ownership, not every possible zap-associated path.

### Precise migration decisions for Firstmate (do not silently delete)

1. Integrate changes into the stable `~/dotfiles` checkout before activation;
   retain/review any local edits rather than resetting them. Local Claude hooks
   and Neovim plugin pins are preserved in the authored files. Touch ID sudo,
   installed brew inventory, the kc namespace and stale-parent PATH repair are
   retained. No prior product launcher/code is imported.
2. Back up any existing `.before-mac-foundation` collision before activation; do
   not use `force` to overwrite it. Home Manager must be allowed to report conflicts.
3. Once the new Nix AXI paths pass verification, remove **only** the five obsolete
   npm global package declarations (`npm uninstall --global --ignore-scripts
   gh-axi chrome-devtools-axi lavish-axi quota-axi tasks-axi`) if desired. Review
   `npm list -g --depth=0` first. This removes package code, not tool runtime state.
4. The old no-mistakes installation/daemon is shared. Firstmate decides when an
   upgrade/migration is safe; do not restart it as a side effect of verification.
5. The new kc intentionally does not offer old `gen`/`ls` convenience commands;
   old `gen` passed the secret in argv. Existing service names and run syntax are
   compatible. Verify any caller before retiring the old helper. Never delete
   Keychain items or replay old product credentials as part of a clean setup.

## Normal add/remove/customize flow

1. Pick the owner from the table, then edit **that** declaration only. Example:
   add `"firefox"` to `configuration.nix` casks, or add `wget` to `home.packages`.
   Never install the same CLI from both Nix and brew/npm. Git diff is the change UI.
2. Optional non-activating validation: `python3 tests/entrypoint-contract.test.py`,
   `python3 tests/mac-foundation.test.py`, `nix flake check`, then
   `nix build .#darwinConfigurations.mac.system --no-link`.
3. `./rebuild.sh` from the stable checkout. It links `~/.dotfiles` then runs
   `scripts/zap-report.sh` via the shared approval gate. The report saves brew
   leaves, all formulae/casks, apps, the **evaluated** Brewfile and cleanup output
   outside Git. Exit 0 means no removals; 1 means recognized removals; 2 means a
   failed/unknown preview. Any removals are displayed and require terminal `y`/`Y`
   (default N), or explicit `REBUILD_ALLOW_ZAP=1` for a reviewed noninteractive run.
   Preview errors cannot be overridden. For removal, read the cask's `zap` stanza
   and back up valuable data before approving. `brew uses --installed NAME`
   explains current formula dependents. For a preview alone, run
   `./scripts/zap-report.sh /absolute/outside/repo/report`.
4. After approval, rebuild switches and runs `scripts/verify-mac.sh`. A failed
   switch or verification is a failing command, not success. If PATH/account
   state needs refreshing, open a fresh login shell and rerun verification.
5. Add a new app config via an individual `home.file` link. Do not link entire
   credential/state directories. A skill is a separate reviewed SKILL.md directory;
   the enabled manifest controls individual discovery links. Run the admission and
   real runtime matrix tests before approving activation; see `skills/README.md`.

Git/GitHub/GitLab identity safety: `user.useConfigOnly` prevents inferred author
identities. Set identity per project (or a private Git includeIf), not in public
Nix. SSH uses `IdentitiesOnly` and host-key prompts for the forges. Keep private
account aliases/key paths in `~/.ssh/config.local`; use explicit forge aliases in
remotes to separate accounts. Check `ssh -G github.com` / `ssh -G gitlab.com` before
connecting. No SSH private keys, known-host contents, tokens or forge logins are
created/copied by this configuration. Secret injection remains through kc.

## Topgrade: adoption, validation and recovery

`tg` (or `topgrade --config ~/.dotfiles/home/.config/topgrade.toml`) is the
coordinated update entry point. Its custom `scripts/update-managed.sh` step:

1. Refuses a dirty checkout before touching package managers. Commit or stash first.
2. Saves the previous Git head, lock and specific system generation under a printed
   temporary evidence directory outside Git. Keep that directory until accepted.
3. Runs `nix flake update`, full `nix flake check`, and a system build without a result link.
4. Calls `rebuild.sh`: fresh zap preview/approval, switch, then verification.
5. Leaves a successful updated lock for review/commit. On **any** failure (including
   rejected removals, switch failure or post-switch verification), restores only the
   previous `flake.lock` automatically and prints exact recorded-generation rollback
   commands. It does not pretend restoring a lock reverses an applied system.

The Topgrade config uses a targeted disable list, not an only-custom allowlist.
Brew formula/cask, Nix/helper/Home Manager, npm globals (`node`), uv, Claude/Codex/Pi
self-updaters and Topgrade's self-update are disabled because versions belong to
Nix/Brew declarations. Git repo pulls, Vim plugin and skills updates are disabled
because authored config/plugin pins/skills require Git review. Non-conflicting
built-in steps (for example OS/App Store updates and separately owned extensions)
remain Topgrade's normal job; review its dry-run for your installed tools. Adding
another declarative owner may require extending the targeted disable list.

Keep upstream fetch/review/adoption explicit with Git; no automatic merge/rebase.
Topgrade's `--yes` is not zap approval: unattended removals still require
`REBUILD_ALLOW_ZAP=1` after reviewing the exact candidate report.

AXI or release package changes are explicit version/hash/lock edits followed by
`nix flake check` and binary/behavior checks. Regenerate the npm lock with
`npm install --package-lock-only --ignore-scripts` in `packages/axi`, audit it,
then use the locked nixpkgs `prefetch-npm-deps` to update `npmDepsHash`.
Do not run `no-mistakes update`, `treehouse update`, `pi update`, `npm update -g`,
`uv self update`, direct brew upgrades or Topgrade's disabled ownership-bypassing
steps. `nix flake update` changes input revisions, not hardcoded release/AXI pins.

## Fresh Mac and owner-only sign-ins

Clone your fork into the stable `~/dotfiles`, review package declarations and the
zap warning, then run `./bootstrap.sh`. It installs Determinate Nix if missing,
links `~/.dotfiles`, and interactively offers to set user, `scutil --get LocalHostName`
and CPU system in `machine.nix`. Refusing that change stops before switching.
On Intel, the custom release packages also need audited Intel assets/hashes.
Existing Homebrew gets the same zap gate as rebuild; on a bare Mac nix-homebrew
installs Homebrew during the first switch. The first rebuild tool is obtained
with upstream's `nix run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild`;
the system inputs remain locked by this repo. Verification follows the switch.

Only the account owner can complete sign-ins: `kc set NAME` prompts in a real
terminal; `kc run NAME=ENV -- COMMAND` injects credentials into one child process.
Use `gh auth login` (or `gh-axi auth login`) and the installed Claude/Codex/Pi
account login flows as needed. Never paste secrets into Git, a skill, environment
file or chat. Set `KC_GITHUB_SERVICE` / `KC_MODEL_SERVICE` to existing service
**names**, not values, to opt into credential verification. Unset names are
reported as skipped, not verified. Bootstrap does not copy old account state.

## Attended activation and rollback gate

The operator performs these steps in the approved stable checkout:

1. Save the current Git head, `readlink ~/.dotfiles`, `readlink /nix/var/nix/profiles/system`,
   `nix-env --profile /nix/var/nix/profiles/system --list-generations`, and the resolved
   previous system store path outside Git. **Do not garbage-collect it.**
2. Verify the old path exists, its `activate` is executable, run `bash -n OLD/activate`
   and `nix-store --verify-path OLD`. A prior generation-5 preflight succeeded;
   that historical result is not proof of today's generation or a real rollback.
3. Resolve checkout/backup conflicts above. Inspect the existing `~/.dotfiles`
   target, then run `./rebuild.sh` from stable `~/dotfiles`. It relinks, gates zap,
   switches and verifies; do not bypass the gate with a direct rebuild command.
4. If verification fails, inspect the actual errors (including PATH, signatures,
   apps or account readiness). Retry `~/dotfiles/scripts/verify-mac.sh` in a fresh
   login shell after fixing them; do not silently label an applied system healthy.
5. If broken, first restore the prior source checkout/config-link target and any
   Home Manager collision backups as appropriate. Switch the system profile to
   the **recorded generation**, e.g. `sudo nix-env --profile /nix/var/nix/profiles/system
   --switch-generation 5`, then `sudo /nix/var/nix/profiles/system/activate`.
   Do not blindly use `--rollback` after repeated attempts: it may select the wrong
   generation. Topgrade prints your recorded generation's exact commands on failure
   and restores the old lock automatically. The mocked failure tests prove lock
   restoration/order, not real system reactivation. Rebuild/bootstrap do not
   automatically undo source edits; keep the Git head/closure recorded above.

**Rollback limits:** Nix generations do not restore edited out-of-store config,
Homebrew-zapped data, Keychain state, cask downgrades or application databases.
Homebrew upgrades can have irreversible data migrations. Preserve app-specific
backups and the old Git revision; a previous Nix generation alone is not a full
machine backup. This is why the zero-unintended-removal gate cannot be skipped.

`verify-mac.sh` fails on missing tools, unmanaged PATH shadowing, absent apps/fonts,
wrong machine/link, signing identity mismatch, cleanup removals, failed native
skill discovery or explicitly configured missing/unreadable kc services. When a
GitHub service name is configured, it makes a read-only authenticated GitHub
request, not a model call. Browser journeys, provider usefulness and a full
Firstmate delivery are separate acceptance evidence after activation.
