#!/bin/bash


# Fetch aliases file
if command -v curl &> /dev/null
then
    curl https://pub.thomaslaurenson.com/aliases/aliases -o $HOME/.aliases
else
    wget https://pub.thomaslaurenson.com/aliases/aliases -O "$HOME/.aliases"
fi

# Add aliases file to ~/.bashrc
if ! grep "# CUSTOM ALIASES" ~/.bashrc > /dev/null; then
    {
        echo -e "\n# CUSTOM ALIASES"
        echo -e "if [ -f ~/.aliases ]; then"
        echo -e "    . ~/.aliases"
        echo -e "fi"
    }  >> ~/.bashrc
fi
