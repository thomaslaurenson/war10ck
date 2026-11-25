bats_require_minimum_version 1.7.0

load helpers/common

# Check which identity the git module's settings give each kind of repository.
# The includeIf patterns are case-sensitive globs where * stops at a slash, so a
# plausible looking pattern can silently miss the SSH form of a URL. Each URL
# below is a remote shape seen in practice.
#
# The files are laid out as install and config leave them: ~/.gitconfig holds
# an empty [user] section followed by the war10ck include block, and the
# settings and host identities live in ~/.war10ck/git.
#
# Environment:
#   REPO_ROOT     - absolute path to the repository root
#   GITHUB        - the email github.gitconfig sets
#   GITHUB_KEY    - the signing key github.gitconfig sets
#   BITBUCKET     - the email bitbucket.gitconfig sets
#   BITBUCKET_KEY - the signing key bitbucket.gitconfig sets
setup() {
  REPO_ROOT="$(_repo_root)"
  GITHUB=gh@example.com
  GITHUB_KEY=/keys/github.pub
  BITBUCKET=bb@example.com
  BITBUCKET_KEY=/keys/bitbucket.pub
  export HOME="$BATS_TEST_TMPDIR/home"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL

  local dir="$HOME/.war10ck/git" f
  mkdir -p "$dir"
  for f in gitconfig both-hosts.gitconfig no-identity.gitconfig; do
    cp "$REPO_ROOT/src/modules/git/files/$f" "$dir/$f"
  done
  _install_layout > "$HOME/.gitconfig"
  _identity "$dir/github.gitconfig" GitHub "$GITHUB" "$GITHUB_KEY"
  _identity "$dir/bitbucket.gitconfig" Bitbucket "$BITBUCKET" "$BITBUCKET_KEY"
}

# Print ~/.gitconfig as install leaves it on a machine that had none.
_install_layout() {
  printf '[user]\n'
  printf '\n# war10ck BEGIN git\n[include]\n\tpath = ~/.war10ck/git/gitconfig\n# war10ck END git\n'
}

# Write a host identity file as install does.
#
# Arguments:
#   $1 - file path
#   $2 - host label, used for the name
#   $3 - email
#   $4 - signing key
_identity() {
  git config -f "$1" user.email "$3"
  git config -f "$1" user.name "$2 User"
  git config -f "$1" user.signingkey "$4"
}

# Create a fresh repository with the given remotes, replacing any earlier one.
#
# Arguments:
#   $@ - remote URLs, none for a repository with no remote
# Outputs:
#   the repository path
_repo_with() {
  local repo="$BATS_TEST_TMPDIR/repo" i=0 url
  rm -rf "$repo"
  git init -q "$repo"
  for url in "$@"; do
    git -C "$repo" remote add "remote$i" "$url"
    i=$((i + 1))
  done
  printf '%s\n' "$repo"
}

# Print a config value in a fresh repository with the given remotes.
#
# Arguments:
#   $1  - config key
#   $2+ - remote URLs
_config_with() {
  local key=$1 repo
  shift
  repo=$(_repo_with "$@")
  git -C "$repo" config "$key"
}

# Attempt a commit in a fresh repository with the given remotes. Signing is
# off, so the result turns on identity alone; signing has tests of its own.
#
# Arguments:
#   $@ - remote URLs
_commit_with() {
  local repo
  repo=$(_repo_with "$@")
  git -C "$repo" -c commit.gpgsign=false commit -q --allow-empty -m test
}

@test "identity: GitHub uses the GitHub identity over SSH and HTTPS" {
  local url
  for url in \
    git@github.com:thomaslaurenson/war10ck.git \
    https://github.com/thomaslaurenson/war10ck \
    git@github.com:UoA-SRE/vault.git \
    https://github.com/UoA-SRE/vault.git; do
    run _config_with user.email "$url"
    [[ "$output" == "$GITHUB" ]] || { echo "$url -> $output"; return 1; }
  done
  run _config_with user.name git@github.com:thomaslaurenson/war10ck.git
  [ "$output" == "GitHub User" ]
}

@test "identity: Bitbucket uses the Bitbucket identity over SSH, the SSH alias and HTTPS" {
  local url
  for url in \
    git@bitbucket.org:uoa-sre/vault.git \
    git@ssh.bitbucket.org:uoa-sre/vault.git \
    https://bitbucket.org/uoa-sre/vault.git \
    https://tom@bitbucket.org/uoa-sre/vault.git; do
    run _config_with user.email "$url"
    [[ "$output" == "$BITBUCKET" ]] || { echo "$url -> $output"; return 1; }
  done
  run _config_with user.name git@bitbucket.org:uoa-sre/vault.git
  [ "$output" == "Bitbucket User" ]
}

@test "signing key: each host signs with its own key" {
  run _config_with user.signingkey git@github.com:UoA-SRE/vault.git
  [ "$output" == "$GITHUB_KEY" ]
  run _config_with user.signingkey git@ssh.bitbucket.org:uoa-sre/vault.git
  [ "$output" == "$BITBUCKET_KEY" ]
}

@test "no identity: a repository with no remote cannot commit" {
  run _commit_with
  (( status != 0 ))
  [[ "$output" =~ "Author identity unknown" ]]
}

@test "no identity: a remote on another host cannot commit" {
  run _commit_with git@gitlab.com:someone/repo.git
  (( status != 0 ))
  [[ "$output" =~ "Author identity unknown" ]]
}

@test "no identity: a host without an identity file cannot commit" {
  rm "$HOME/.war10ck/git/bitbucket.gitconfig"
  run _commit_with git@bitbucket.org:uoa-sre/vault.git
  (( status != 0 ))
  [[ "$output" =~ "Author identity unknown" ]]
}

@test "both hosts: neither identity applies, whichever remote comes first" {
  local pair first second
  for pair in \
    "git@github.com:a/b.git git@bitbucket.org:a/b.git" \
    "git@bitbucket.org:a/b.git git@github.com:a/b.git" \
    "https://github.com/a/b https://tom@bitbucket.org/a/b.git" \
    "git@ssh.bitbucket.org:a/b.git https://github.com/a/b"; do
    read -r first second <<< "$pair"
    run _config_with user.email "$first" "$second"
    [[ -z "$output" ]] || { echo "$pair -> $output"; return 1; }
    run _commit_with "$first" "$second"
    (( status != 0 )) || { echo "$pair committed"; return 1; }
    [[ "$output" =~ "Author identity unknown" ]]
  done
}

@test "both hosts: the signing key is blanked too" {
  run _config_with user.signingkey git@github.com:a/b.git git@bitbucket.org:a/b.git
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "both hosts: an identity set in the repository is used" {
  local repo
  repo=$(_repo_with git@github.com:a/b.git git@bitbucket.org:a/b.git)
  git -C "$repo" config user.name Local
  git -C "$repo" config user.email local@example.com
  run git -C "$repo" -c commit.gpgsign=false commit -q --allow-empty -m test
  [ "$status" -eq 0 ]
  run git -C "$repo" log -1 --format='%an <%ae>'
  [ "$output" == "Local <local@example.com>" ]
}

@test "both hosts: signing fails until the repository sets its own key" {
  # Without this, a repository-level name and email would still be signed with
  # whichever host key was included last.
  local repo
  repo=$(_repo_with git@github.com:a/b.git git@bitbucket.org:a/b.git)
  git -C "$repo" config user.name Local
  git -C "$repo" config user.email local@example.com
  run git -C "$repo" commit -q --allow-empty -m test
  (( status != 0 ))
  [[ "${output,,}" =~ "user.signingkey needs to be set" ]]
}

@test "default identity: git config --global lands above the include" {
  # git's own error suggests --global. The empty [user] section install writes
  # is what keeps that key above the include, where host identities and the
  # both-hosts guard still override it.
  git config --global user.email default@example.com
  run _config_with user.email git@github.com:a/b.git
  [ "$output" == "$GITHUB" ]
  run _config_with user.email git@github.com:a/b.git git@bitbucket.org:a/b.git
  [[ -z "$output" ]]
  run _config_with user.email
  [ "$output" == "default@example.com" ]
}

@test "settings: the war10ck file supplies the shared defaults" {
  run _config_with init.defaultBranch git@github.com:thomaslaurenson/war10ck.git
  [ "$output" == "main" ]
  run _config_with commit.gpgsign git@github.com:thomaslaurenson/war10ck.git
  [ "$output" == "true" ]
}

@test "settings: git config --global writes to ~/.gitconfig and overrides a default" {
  git config --global push.default simple
  run _config_with push.default git@github.com:thomaslaurenson/war10ck.git
  [ "$output" == "simple" ]
  run git config -f "$HOME/.war10ck/git/gitconfig" push.default
  [ "$output" == "current" ]
}
