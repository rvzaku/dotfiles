# dotfiles

An Apple Silicon Mac engineering environment adapted from
[Kun Chen's upstream dotfiles](https://github.com/kunchenguid/dotfiles).
The upstream Nix/nix-darwin/Home Manager/Homebrew structure, editor, terminal,
Rosé Pine Moon aesthetic and **Homebrew `zap` policy** are retained.
Upstream walkthrough: https://youtu.be/5N-okeDdIuI

This fork is for `rvzaku`. It is a local adaptation, not a contribution to Kun's
personal setup; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Start here

| Want to… | Edit/run |
|---|---|
| Change username, hostname or architecture | `machine.nix` (the only machine identity file) |
| Add/remove a GUI app or Homebrew-only CLI | `configuration.nix`: `casks` / `brews` |
| Add/remove a Nix CLI or runtime | `home.nix`: `home.packages` |
| Change an exact release/AXI pin | `packages/default.nix` / `packages/axi/package.json` + lock |
| Change shell, Git/SSH safety or a config link | `home.nix` |
| Change terminal/editor/Pi preferences | authored files under `home/` |
| Build without applying | `./bootstrap.sh` (identity preflight + locked build) or `./rebuild.sh` |
| See what `zap` would remove | `./scripts/zap-report.sh /absolute/path/outside/checkout` |
| Prepare an update | `tg`, or `topgrade --config ./home/.config/topgrade.toml` after migration |
| Verify an approved activation | `./scripts/verify-mac.sh` in a fresh shell |
| Add/evaluate a skill | [skills/README.md](skills/README.md), one skill at a time |

**No repository script performs activation.** `bootstrap.sh` and `rebuild.sh`
build only; neither replaces `~/.dotfiles`, installs Nix, rewrites identity,
runs `sudo`, or switches a system. An attended approver applies a reviewed,
built candidate only after examining the actual cleanup diff.

See [Mac operations, ownership, migration and rollback](docs/mac-foundation.md)
for the precise commands, installed inventory, pin policy and known limits.

## Fresh supported Mac

1. Install Apple's Command Line Tools and a reviewed Determinate Nix installer
   from https://determinate.systems/nix/. The Nix daemon is owned by Determinate;
   nix-darwin deliberately has `nix.enable = false`.
2. Clone this fork into **`~/dotfiles`**, review `machine.nix`, and set its user,
   `scutil --get LocalHostName` value and supported CPU. Only arm64 release
   artifacts are packaged here; Intel needs new audited package hashes too.
3. Run `./bootstrap.sh`. It uses the **locked** nix-darwin rebuild tool, so it
   also works when `darwin-rebuild` has not yet been installed.
4. Capture installed Homebrew formulae, leaves, casks, taps and apps and run the
   zap report. Declare every item to retain. Review the migration and approval
   checklist before creating `~/.dotfiles -> ~/dotfiles` and activating.
5. Provision scoped credentials with `kc set NAME` in a real terminal. Verify
   with `kc run NAME=ENV -- COMMAND`; never paste a secret into a command line,
   Nix expression, skill, environment file or Git. No existing agent state or
   product code is imported by bootstrap.

**Homebrew cleanup warning:** `configuration.nix` intentionally sets
`homebrew.onActivation.cleanup = "zap"`. An approved switch removes undeclared
formulae/casks and may delete their associated application data. Review the exact
`brew bundle cleanup` preview before **every** switch. An old report or a successful
build is not approval. macOS-owned and unmanaged apps are listed separately;
Homebrew cleanup does not inventory arbitrary app data.

## Daily changes and updates

Make a declaration change, then `./bootstrap.sh`, run the repo tests, and capture
a fresh zap report. Removing an app means deleting its declaration and reading
that preview, including its zap/data implications; do not run an ad-hoc uninstall.
Nix removal affects the next generation; old store generations remain available
until a separately authorized garbage collection.

Topgrade has one custom step: clean-tree preflight, backup the prior lock/head,
update `flake.lock`, check, build, and report cleanup. It **does not activate**,
upgrade npm globals, self-update uv/Pi/agents, pull a skill collection or prune
old generations. It prepares a reviewable candidate rather than competing with
package ownership. See the operations guide for recovery after a failed update.

## Repo tour and ownership

- `flake.nix` / `flake.lock`: upstream input graph and immutable source revisions,
  including Homebrew core/cask and Kun's tap.
- `machine.nix`: local identity; upstream's logical flake host label remains `mac`.
- `configuration.nix`: system defaults, nix-homebrew, brew declarations.
- `home.nix`: Nix user packages, shell/Git/SSH defaults and selective authored links.
- `packages/`: hashed release binaries and a transitive integrity-locked AXI closure.
- `home/`: editable config files linked through `~/.dotfiles`, not runtime state.
- `scripts/`: small build/update/preview/verification/Keychain boundaries.
- `skills/`: opt-in portable local skill and reviewed source candidates, no bulk install.
- `tests/`: safety/negative-control, native-discovery and upstream Pi Calm tests.

Keep the real checkout at `~/dotfiles`, not a disposable worktree. Home Manager
uses `mkOutOfStoreSymlink` through `~/.dotfiles`: editing an authored file is an
immediate live config edit after activation. Package/system changes require a
reviewed rebuild. Colliding files are preserved with `.before-mac-foundation`;
activation fails safely if a backup already exists.

## Pi configuration

Homebrew's `kunchenguid/tap/pi-launcher` owns the signed app **and its one bundled
Pi engine**. It provides `pi-signed`; Nix provides a thin `pi` wrapper that executes
that launcher. Do not also install Pi with npm, a shell installer or another Nix
package. The signed app's version, hash and source are locked by the tap revision.

Home Manager links only `~/.pi/agent/themes`, `extensions`, `models.json` and
`settings.json`. Authentication, sessions, trust, caches and downloaded package
trees are not in Git or Home Manager. Use process-scoped provider variables from
`kc run` instead of `/login`/plaintext `auth.json`. No provider/model is selected
or authenticated by this repository.

The rose-pine-moon theme uses the public [Rosé Pine palette](https://rosepinetheme.com/palette).
The terminal-title extension shows session/directory status. `/reload` refreshes
local resources. The optional Calm extension is Adapted from Firstmate under its
bundled MIT license; it is standalone with no runtime dependency on that project.
It changes presentation, not prompts, tool execution, sessions or exports.

**Compatibility:** upstream Calm targets Pi **0.82.0**, while the locked launcher
bundles Pi **1.4.0**. It is explicitly excluded by `settings.json` on this Mac
rather than pretending those APIs are compatible. Its original behavioral/TUI
suite is run against disposable Pi 0.82.0 test dependencies. A one-line return-type
annotation fixes a strict TypeScript error without changing behavior or baselines.
The installed Pi 1.4.0 is separately tested to honor the exclusion. Porting Calm
is optional, not a prerequisite for productive Pi use.

The inherited third-party pins, `npm:pi-web-access@0.14.0` and
`npm:@ryan_nookpi/pi-extension-codex-fast-mode@0.2.6`, are **not enabled**:
`settings.json` has an empty `packages` array. Their Pi 1.4 behavior and transitive
supply chain have not been requalified here, so they must not execute silently
at first startup. Reintroduce an exact audited pin only if it fills a real need.
Pi owns downloaded package runtime trees, not Home Manager; no existing trees
are deleted. Never place third-party code in the local extensions tree.

## Verification

```sh
python3 tests/mac-foundation.test.py
python3 tests/skill-discovery.test.py  # installed runtimes only; no model calls
bash tests/axi-smoke.test.sh          # built AXI binaries + hostile TOON input
nix flake check
./bootstrap.sh
```

For the unchanged upstream Calm suite's **0.82** proof target, install disposable
local test dependencies, not another live/global Pi:

```sh
TEST_ROOT=$(mktemp -d)
npm install --prefix "$TEST_ROOT" --ignore-scripts --no-audit --no-fund \
  @earendil-works/pi-coding-agent@0.82.0 typescript@5.9.3
PATH="$TEST_ROOT/node_modules/.bin:$PATH" \
  PI_CALM_TEST_PACKAGE_DIR="$TEST_ROOT/node_modules/@earendil-works/pi-coding-agent" \
  bash tests/pi-calm.test.sh
```

Node 24 and tmux must be on PATH. Remove only that disposable directory afterward.
The operations guide distinguishes built, discovery-tested, post-activation and
unverified behavior. A passing mock test or `--version` is not proof of a usable
model, browser journey, daemon or complete delivery.

## License

MIT No Attribution; see [LICENSE](LICENSE). Bundled Calm attribution is preserved.
