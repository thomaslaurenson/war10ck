#!/bin/bash


# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Kill any existing rofi instances to prevent overlapping menus
killall -q rofi

# Launch Rofi in application launcher mode (drun) using our specific config
#rofi -show drun -theme "$DIR/config.rasi"
rofi -show combi -combi-modi "window,drun" -theme "$DIR/config.rasi"
