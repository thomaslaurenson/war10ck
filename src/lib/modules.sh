# shellcheck shell=bash

_run_module_script() {
    local module=$1
    local script_type=$2 # e.g., 'install' or 'config'
    local manifest_key="modules/$module/${script_type}.sh"

    # Check if this script exists in the remote/local manifest.
    # If it doesn't, we gracefully skip it (e.g., a module might have 
    # a config.sh but no install.sh, which is perfectly fine).
    if ! grep -q "$manifest_key$" <<< "$WAR10CK_MANIFEST"; then
        return 0 
    fi

    echo "[*] Running $script_type phase for $module..."
    local _tmpfile
    _tmpfile=$(mktemp --suffix="-${module}-${script_type}.sh")
    
    $FETCH_CMD "$_tmpfile" "$BASE_URL/$manifest_key"
    _verify_from_manifest "$_tmpfile" "$manifest_key"
    
    # Execute the script. 
    # NOTE: Any required `sudo` logic must now be written INSIDE the module's 
    # script (e.g., inside modules/docker/install.sh), which is safer anyway.
    bash "$_tmpfile"
    
    rm -f "$_tmpfile"
}

_module_action() {
    local action=$1
    local target=$2
    
    if [ -z "$target" ]; then
        echo "[!] Please specify a module (e.g., war10ck $action <module>)"
        echo ""
        echo "[*] Modules with '$action' support:"
        local modules
        modules=$(grep -oE "modules/[^/]+" <<< "$WAR10CK_MANIFEST" | cut -d'/' -f2 | sort -u)
        for mod in $modules; do
            grep -q "modules/$mod/${action}.sh" <<< "$WAR10CK_MANIFEST" && echo "    $mod"
        done
        exit 1
    fi

    # Ensure the module actually exists anywhere in the manifest
    if ! grep -q "modules/$target/" <<< "$WAR10CK_MANIFEST"; then
        echo "[!] Error: Module '$target' does not exist."
        exit 1
    fi

    case "$action" in
        install|config|launch)
            _run_module_script "$target" "$action"
            ;;
        setup)
            echo "[*] Setting up module: $target"
            _run_module_script "$target" "install"
            _run_module_script "$target" "config"
            echo "[*] $target setup complete."
            ;;
    esac
}

# The actual functions called by main.sh
install() { _module_action "install" "$1"; }
config()  { _module_action "config" "$1";  }
setup()   { _module_action "setup" "$1";   }
launch()  { _module_action "launch" "$1";  }

list() {
    echo "[*] Available war10ck modules:"
    # Parse the manifest, extract the module names, and sort them uniquely
    local modules
    modules=$(grep -oE "modules/[^/]+" <<< "$WAR10CK_MANIFEST" | cut -d'/' -f2 | sort -u)
    
    for mod in $modules; do
        # We can dynamically check what capabilities a module has!
        local caps=""
        grep -q "modules/$mod/install.sh" <<< "$WAR10CK_MANIFEST" && caps+="[install] "
        grep -q "modules/$mod/config.sh" <<< "$WAR10CK_MANIFEST" && caps+="[config] "
        grep -q "modules/$mod/launch.sh" <<< "$WAR10CK_MANIFEST" && caps+="[launch] "

        printf "  - %-15s %s\n" "$mod" "$caps"
    done
}