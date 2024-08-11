#!/bin/bash


# Fetch aliases file
if command -v curl &> /dev/null
then
    curl https://pub.thomaslaurenson.com/git/gitconfig -o $HOME/.gitconfig
else
    wget https://pub.thomaslaurenson.com/git/gitconfig -O "$HOME/.gitconfig"
fi
