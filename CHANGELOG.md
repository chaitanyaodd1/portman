# Changelog

All notable changes to portman are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR** — breaking changes to commands or behavior
- **MINOR** — new commands or features, backwards compatible
- **PATCH** — bug fixes, small improvements

---

## [1.0.0] — 2026-04-17

Initial public release.

### Added
- `portman forward` — background port forwarding via `kubectl`, `ssh`, `socat`, or `local` tracking
- `portman kill` — terminate a forward by name, port number, or kill all
- `portman list` — full overview of managed forwards and system listening ports
- `portman status` — tabular view with live PID health check (running / dead)
- `portman info` — port reference manual with 60+ well-known ports, searchable by number or keyword
- `portman check` — instant check of whether a port is free or in use
- `portman log` — view the stdout/stderr log of any background forward
- `portman clean` — prune dead/crashed entries from state
- `portman completion` — install bash tab completion
- JSON state file at `~/.portman/forwards.json` for persistence across sessions
- Per-forward log files at `~/.portman/logs/<n>.log`
- `PORTMAN_HOME` environment variable to override the state directory
- Short aliases: `f`, `k`, `l`, `s`, `i`, `c` for all primary commands
- ANSI color output with automatic detection (disabled when piped)

---

## [Unreleased]

Tracking upcoming changes before the next release.

### Planned
- Interactive TUI with arrow-key navigation (Phase 2)
- `portman watch` — live-refreshing status view
- Switch a forward's port on the fly without kill + re-forward
- `portman restore` — re-establish all forwards after reboot
- Auto-restart on pod crash via watch loop
- Named forward profiles in a config file

---

[1.0.0]: https://github.com/chaitanyaodd1/portman/releases/tag/v1.0.0
[Unreleased]: https://github.com/chaitanyaodd1/portman/compare/v1.0.0...HEAD
