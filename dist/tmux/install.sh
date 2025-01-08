#!/bin/bash


# Fetch tmux.conf file
if command -v curl &> /dev/null
then
    curl https://pub.thomaslaurenson.com/tmux/tmux.conf -o $HOME/.tmux.conf
else
    wget https://pub.thomaslaurenson.com/tmux/tmux.conf -O "$HOME/.tmux.conf"
fi

# Source tmux.conf
tmux source ~/.tmux.conf
