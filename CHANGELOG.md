# Changelog

## 0.10.0 - 2026-08-21

### Added

- Add a status subcommand backed by a registry of modules war10ck has applied

### Fixed

- Lint every deployed shell file, not just module lifecycle scripts
- Quote shell expansions in the bash helper functions
- Return rather than exit the shell when the transmission VPN check fails

## 0.9.0 - 2026-08-21

### Added

- Add a clean subcommand that reports and removes artefacts left by older versions

### Changed

- Move module environment files to env.d, leaving bashrc.d entirely for your own scripts

### Fixed

- Stop war10ck subcommands shadowing commands like install in interactive shells
- Remove the ghidra environment file when uninstalling the module

## 0.8.3 - 2026-08-21

### Changed

- Install and update gpipe tools by applying the gpipe module
- Remove the installed tools as well as the registry when uninstalling gpipe

### Removed

- Remove the gpipe subcommand

## 0.8.2 - 2026-08-21

### Added

- Add smount to the gpipe registry and install sshfs with the ssh module

### Removed

- Remove the sshfs shell functions, now provided by smount

## 0.8.1 - 2026-08-21

### Added

- Install govulncheck as part of the golang module

### Fixed

- Clean up temporary downloads when a golang install fails partway

### Updated

- Bump Go to 1.27.0 and goreleaser to 2.17.1

## 0.8.0 - 2026-08-16

### Added

- Add a gpipe subcommand to show and update gpipe-installed tools
- Add gpipe, mdbook, mermaid, and pass-env modules
- Add a Claude session and weekly usage indicator to Polybar

## 0.7.1 - 2026-07-17

### Added

- Add a command launcher to rofi

## 0.7.0 - 2026-07-16

### Added

- Tests for war10ck library functionality using bats
