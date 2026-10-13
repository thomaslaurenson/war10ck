# Set directly rather than by sourcing emsdk_env.sh. That script starts Python
# to work the values out and logs each one to stderr, and env.d is sourced by
# every interactive shell, so every new terminal would pay for both. emcc needs
# no environment of its own: emsdk activate wrote its tool paths, the bundled
# Node included, to $EMSDK/.emscripten, which emcc finds beside the SDK.
export EMSDK="$HOME/.local/share/emsdk"

# emsdk_env.sh also adds the bundled Node when no other node is on PATH. It is
# left off, so node, npm and npx stay whatever fnm or the system supplies.
#
# Prepended so the pinned SDK wins over a distribution emcc in /usr/bin, and
# guarded because a nested shell inherits a PATH that already holds both.
case ":${PATH}:" in
    *:"$EMSDK/upstream/emscripten":*)
        ;;
    *)
        export PATH="$EMSDK:$EMSDK/upstream/emscripten:$PATH"
        ;;
esac
