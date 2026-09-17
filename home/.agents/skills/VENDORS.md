# Global vendor skills

The global Skills registry is authoritative for upstream skill sources. Bootstrap
seeds these sources with `skills add ... --global --all`; Home Manager links only
the writable Backpass user-scope source below. The remaining checked-in skill
files are retained as reviewable compatibility material and are not presented
as the source of global registry truth.

- Matt Pocock, Vision, agent-stuff, Impeccable, No Mistakes, AXI, lavish-axi,
  gnhf, remote-pi/agent-network, and Firstmate/stow sources are seeded from
  their upstream repositories by
  `home/bin/update-skills`.
  `home/bin/update-skills`. The `kunchenguid/firstmate` source supplies its
  Firstmate/stow skill; `jacobaraujo7/remote_pi` supplies agent-network (and
  other optional remote-pi skills).
  Treehouse is a binary release rather than a Skills package and remains
  owned by `update-agent-tools`.

Backpass may write only its authored local sources (`home/AGENTS.md` and
`home/.agents/skills/backpass/`) through its configured user-scope overflow
directory. Vendor updates are deliberate source refreshes, never runtime writes.
- `agent-network/` and `stow/` remain compatibility material for the pinned
  Remote Pi and Firstmate integrations; runtime package ownership stays with
  Pi and Firstmate respectively.
