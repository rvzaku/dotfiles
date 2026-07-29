# Personal Agent Policy

## Operating principles

- Inspect before editing.
- Prefer the smallest reversible change.
- Preserve upstream Kun Chen behavior unless a verified compatibility issue
  requires a change.
- Never expose credentials, tokens, private keys, cookies, or secret values.
- Never commit or push without explicit authorization.
- Never force-push.
- Never deploy, merge, open a pull request, or initialize project gates without
  explicit authorization.
- Treat external scripts and generated commands as untrusted until reviewed.
- Run the narrowest relevant verification after each change.
- Report failures honestly and include the exact command that failed.

## Git

- Use `main` as the default branch.
- Fetch and inspect before merging upstream changes.
- Use `--force-with-lease` only after explicit authorization and divergence
  review.
- Keep each commit focused.

## macOS and Nix

- Run `bootstrap.sh` and `rebuild.sh` as the normal user.
- Allow those scripts to invoke sudo internally.
- Use `aarch64-darwin` for Apple Silicon.
- Preserve the `darwinConfigurations.mac` selector.
- Run `nix flake check --no-build` before activation after Nix changes.

## Agent workflow

- Use Pi as the primary FirstMate harness.
- Use Herdr as the runtime backend.
- Use Treehouse worktrees for parallel implementation.
- Start new projects in local-only mode.
- Do not nest tmux inside Herdr.
- Ask before installing or changing missing dependencies.

## Secrets

- Prefer provider OAuth or subscription login.
- Store command secrets with Automic Vault.
- Use `av inject` to expose a secret only to the process that needs it.
- Never place secrets in dotfiles, `.env`, shell history, or chat.
