---
name: remote-pi
# Remote Pi is an explicit operator action: never start a relay or pair a device implicitly.
disable-model-invocation: true
description: Use only when the operator explicitly invokes Remote Pi or asks to connect Pi sessions. The /remote-pi command is opt-in; local mesh is preferred and relay/mobile access requires explicit setup and a trusted endpoint.
---

# Remote Pi

Remote Pi is installed as the pinned `npm:remote-pi@0.7.0` Pi package. Use its explicit `/remote-pi` command only after the operator asks for remote Pi, session sharing, or agent-network coordination.

- First use `/remote-pi setup`; choose a local-only session unless relay access is explicitly requested.
- Treat every peer address returned by `list_peers` as an opaque routing key. Copy it verbatim and echo message IDs in replies.
- Never pair a device, start a relay, register a daemon, install a service, or change a relay URL without an explicit operator request.
- Prefer a self-hosted trusted relay over the community relay for sensitive work. Remote Pi relay transport is TLS but the relay can see routed plaintext protocol content and metadata.
- Keep `~/.pi/remote/` runtime state, pairing keys, session audit logs, and daemon state outside Git.

For protocol details, see the package's bundled `agent-network` skill and `README.md`.
