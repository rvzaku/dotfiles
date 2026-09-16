# Global vendor skills

These directories are copied from pinned upstream revisions and are intentionally separate from the writable Backpass skill source.

- Root-level Matt Pocock skills: stable engineering, productivity, and misc skills from `mattpocock/skills` at `959a8e9f1edc3adbe2f7e3054bb6fbefa6696260`. In-progress and deprecated trees are intentionally excluded.
- `impeccable/`: provider-generated `.agents` skill from `pbakaus/impeccable` at `0a4e72a254f3b175c95b36b82e5f2e60fa63f116`.
- `no-mistakes/`: public `/no-mistakes` skill from `kunchenguid/no-mistakes` tag `v1.72.0`.

Backpass may write only `home/.agents/skills/backpass/` through its configured user-scope overflow directory. Vendor updates are deliberate source refreshes, never runtime writes.
- `agent-network/`: remote-pi `0.7.0` protocol skill; `/remote-pi` remains explicit-only through the adjacent `remote-pi` skill.
- `stow/`: Firstmate's public standalone skill at checkout `2da3c5e2`; internal `.agents/skills` remain scoped to a Firstmate home and are not copied globally.
