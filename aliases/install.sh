#!/bin/bash


# Set colors
RED="\033[0;31m"
NC="\033[0m"

# Add aliases file ~/.bashrc
echo -e "${RED}[+] Loading aliases into ~/.bashrc file...${NC}"

curl https://pub.thomaslaurenson.com/aliases/aliases \
-o $HOME/.aliases

if ! grep "# CUSTOM ALIASES" ~/.bashrc > /dev/null; then
    {
        echo -e "\n# CUSTOM ALIASES"
        echo -e "if [ -f ~/.aliases ]; then"
        echo -e "    . ~/.aliases"
        echo -e "fi"
    }  >> ~/.bashrc
fi
