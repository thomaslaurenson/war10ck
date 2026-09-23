# Changelog

## 0.16.1 - 2026-09-23

### Changed

- Print the BY column in status without a leading v, so rows from older builds line up

## 0.16.0 - 2026-09-23

### Added

- Add a filen module installing the Rust Filen CLI, with fuse3 for mounting
- Restrict filen to environment-variable authentication, blocking its saved-credential and prompt fallbacks
- Add per to the pass-env module, a shorthand for pass env run with tab completion
- Add w_deploy_remote_dir, deploying every file the manifest names under a remote directory
- Add filenget to the gpipe registry

### Changed

- Drive the gpipe registry from the manifest, so a new tool file needs no edit to install.sh
- Drop -v from the ssh alias, so a normal connection is quiet again

## 0.15.0 - 2026-09-16

### Added

- Report unmerged branch counts in w_git_repository_properties, with --branches to name them
- Give w_git_repository_properties --help, --no-fetch and --debug modes

### Changed

- Hand wired interfaces to NetworkManager alongside wireless, leaving Docker bridges and veth pairs unmanaged
- Take ifupdown out of the boot path, stripping every non-loopback stanza from /etc/network/interfaces
- Move the GitHub shell helpers into the git module, renaming them to the w_git prefix
- Require a directory argument for w_git_repository_properties
- Print the git helpers' errors on stderr and mark their prompts as questions

### Fixed

- Stop the minute-long boot stall from DHCP on a wired port with no cable
- Correct ahead, behind, dirty and detached HEAD reporting in w_git_repository_properties
- Report every repository under a relative target, and skip a repository's own subdirectories
- Keep background fetches off the terminal, and name a missing origin apart from a failed fetch
- Point the chrome_proxy alias at a SOCKS5 proxy rather than an HTTP one

### Removed

- Drop w_git_bump_submodules, w_git_verbs_commit and w_gh_clone_user_repositories

## 0.14.0 - 2026-09-10

### Changed

- Print the version without a leading v in the version command and status table
- Use the standard output markers for debug messages and installer errors
- Draw the rofi cheatsheet and polybar indicators with ASCII characters only

## 0.13.0 - 2026-09-10

### Added

- Add a network module handing wireless to NetworkManager, with w_wifi for joining networks
- Give headless logins an ssh-agent so a key passphrase is entered once per session

## 0.12.0 - 2026-09-04

### Added

- Add a clap module for running claude against a separate configuration root per profile

## 0.11.0 - 2026-09-02

### Added

- Add a claude module installing the Claude Code CLI and putting ~/.local/bin on PATH
- Add an fnm module installing Node 22, 24 and 26, with 24 as the default
- Put the default Node on PATH directly, so it is there for non-interactive shells too
- Catalogue the nvm install for clean, including the lines it appended to ~/.bashrc

### Removed

- Remove the nvm module, replaced by fnm

## 0.10.2 - 2026-08-22

### Fixed

- Fix apply stopping after install when a module was last recorded by an older release

## 0.10.1 - 2026-08-21

### Added

- Show in status whether each applied module still matches the release in use

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
