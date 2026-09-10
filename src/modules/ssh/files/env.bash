# Point the shell at the systemd user agent when the session has not supplied
# one of its own.
#
# A graphical login starts its own agent and exports SSH_AUTH_SOCK, and that is
# the agent actually holding the keys, so it is left alone. A headless SSH login
# gets no agent at all, which leaves the AddKeysToAgent in the war10ck ssh
# config with nowhere to put a key, and every connection re-authenticates.
#
# The test is -S rather than -z so a stale value is repaired as well as an
# absent one: a reattached tmux session carries the SSH_AUTH_SOCK of the login
# that created it, naming a socket that went away with that login.
if [[ ! -S "${SSH_AUTH_SOCK:-}" ]]; then
    _sock="${XDG_RUNTIME_DIR:-/run/user/${UID}}/openssh_agent"
    [[ -S "${_sock}" ]] && export SSH_AUTH_SOCK="${_sock}"
    unset _sock
fi
