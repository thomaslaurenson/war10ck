uv() {
    UV_EXCLUDE_NEWER="$(date -u -d '3 days ago' '+%Y-%m-%dT%H:%M:%SZ')" command uv "$@"
}
