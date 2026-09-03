# The installer puts the launcher in ~/.local/bin and, unlike most installers,
# writes nothing to a shell rc file of its own, so this fragment is the whole
# of what makes the claude command reachable.
#
# Guarded rather than prepended outright: env.d is sourced by every interactive
# shell, and other tools install into the same directory, so an unguarded
# prepend would add a duplicate entry per shell.
case ":${PATH}:" in
    *:"$HOME/.local/bin":*)
        ;;
    *)
        export PATH="$HOME/.local/bin:$PATH"
        ;;
esac
