#!/usr/bin/env bash
# i3 keybinding cheatsheet - displayed via rofi dmenu.
# Launch with: mod+Shift+/ (i.e. mod+?)

SHORTCUTS=$(cat << 'EOF'
━━━  CONTAINERS & LAYOUTS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mod+v                   Split into sub-container (next window below)
  mod+h                   Split into sub-container (next window right)
  mod+s                   Switch container to stacking layout
  mod+w                   Switch container to tabbed layout
  mod+e                   Toggle split layout
  mod+a                   Focus parent container
━━━  STACKING WORKFLOWS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mod+v → open window → mod+s        Stack a new window with current
  mod+v → mod+Shift+← → mod+s        Pull an existing window into stack
  mod+↑ / mod+↓                      Cycle through stacked windows
━━━  WINDOW FOCUS & MOVE  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mod+← / → / ↑ / ↓          Focus window in direction
  mod+Shift+← / → / ↑ / ↓    Move window (enters adjacent container if one)
  mod+Shift+space            Toggle floating
  mod+space                  Toggle focus: tiling ↔ floating
  mod+f                      Fullscreen toggle
  mod+r → arrow keys         Resize mode  (Esc or Enter to exit)
━━━  WORKSPACES  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mod+1-6                    Switch to workspace
  mod+Shift+1-6              Move focused window to workspace
━━━  i3 CONTROL  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mod+Shift+r                Restart i3
  mod+Shift+c                Reload config
  mod+Ctrl+l                 Lock screen
  mod+Shift+q                Kill focused window
  mod+Shift+e                Exit i3
EOF
)

echo "$SHORTCUTS" | rofi \
    -config "$HOME/.war10ck/rofi/config.rasi" \
    -dmenu \
    -p "i3" \
    -no-custom \
    -i \
    -theme-str 'entry { placeholder: "Search shortcuts..."; }' \
    -theme-str 'element { children: [ element-text ]; }' \
    -theme-str 'textbox-help { content: " Press Esc to close  │  Type to filter"; }'
