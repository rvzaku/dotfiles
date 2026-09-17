# Global vendor skills

The global Skills registry is authoritative for upstream skill sources. Bootstrap
seeds these sources with `skills add ... --global --all`; Home Manager links only
the writable Backpass user-scope source below. The remaining checked-in skill
files are retained as reviewable compatibility material and are not presented
as the source of global registry truth.

- Matt Pocock, Vision, agent-stuff, Impeccable, No Mistakes, AXI, and Firstmate
  sources are seeded from their upstream repositories by
  `home/bin/update-skills`.
  Treehouse is a binary release rather than a Skills package and remains
  owned by `update-agent-tools`.

Backpass may write only its authored local sources (`home/AGENTS.md` and
`home/.agents/skills/backpass/`) through its configured user-scope overflow
directory. Vendor updates are deliberate source refreshes, never runtime writes.
- `agent-network/` and `stow/` remain compatibility material for the pinned
  Remote Pi and Firstmate integrations; runtime package ownership stays with
  Pi and Firstmate respectively.
